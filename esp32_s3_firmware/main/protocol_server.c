#include "protocol_server.h"

#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "esp_check.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "hid_control.h"

#define MAX_COMMAND_BODY 2048
#define RECENT_COMMAND_COUNT 64
#define HTTP_STATUS_CONFLICT "409 Conflict"

static const char *TAG = "openclaw_http";
static httpd_handle_t s_server;
static SemaphoreHandle_t s_state_lock;
static uint64_t s_recent_ids[RECENT_COMMAND_COUNT];
static size_t s_recent_count;
static size_t s_recent_cursor;
static bool s_stopped;

static esp_err_t send_json(httpd_req_t *request, const char *status, cJSON *object)
{
    char *body = cJSON_PrintUnformatted(object);
    if (body == NULL) {
        return ESP_ERR_NO_MEM;
    }
    httpd_resp_set_status(request, status);
    httpd_resp_set_type(request, "application/json; charset=utf-8");
    const esp_err_t result = httpd_resp_sendstr(request, body);
    free(body);
    return result;
}

static esp_err_t send_error(httpd_req_t *request, const char *status, const char *message)
{
    cJSON *object = cJSON_CreateObject();
    cJSON_AddStringToObject(object, "error", message);
    const esp_err_t result = send_json(request, status, object);
    cJSON_Delete(object);
    return result;
}

static esp_err_t send_ack(
    httpd_req_t *request,
    const char *http_status,
    uint64_t command_id,
    const char *status,
    const char *message
)
{
    cJSON *object = cJSON_CreateObject();
    cJSON_AddNumberToObject(object, "id", (double)command_id);
    cJSON_AddStringToObject(object, "status", status);
    cJSON_AddStringToObject(object, "message", message);
    const esp_err_t result = send_json(request, http_status, object);
    cJSON_Delete(object);
    return result;
}

static bool get_command_id(cJSON *root, uint64_t *command_id)
{
    cJSON *item = cJSON_GetObjectItemCaseSensitive(root, "id");
    if (!cJSON_IsNumber(item) || !isfinite(item->valuedouble) ||
        item->valuedouble < 0 || item->valuedouble > 9007199254740991.0 ||
        floor(item->valuedouble) != item->valuedouble) {
        return false;
    }
    *command_id = (uint64_t)item->valuedouble;
    return true;
}

static bool get_optional_int(cJSON *root, const char *name, int *value, bool *present)
{
    cJSON *item = cJSON_GetObjectItemCaseSensitive(root, name);
    if (item == NULL) {
        *present = false;
        return true;
    }
    if (!cJSON_IsNumber(item) || !isfinite(item->valuedouble) ||
        floor(item->valuedouble) != item->valuedouble ||
        item->valuedouble < INT32_MIN || item->valuedouble > INT32_MAX) {
        return false;
    }
    *value = (int)item->valuedouble;
    *present = true;
    return true;
}

static bool mark_command_seen(uint64_t command_id)
{
    bool duplicate = false;
    xSemaphoreTake(s_state_lock, portMAX_DELAY);
    for (size_t i = 0; i < s_recent_count; ++i) {
        if (s_recent_ids[i] == command_id) {
            duplicate = true;
            break;
        }
    }
    if (!duplicate) {
        s_recent_ids[s_recent_cursor] = command_id;
        s_recent_cursor = (s_recent_cursor + 1) % RECENT_COMMAND_COUNT;
        if (s_recent_count < RECENT_COMMAND_COUNT) {
            ++s_recent_count;
        }
    }
    xSemaphoreGive(s_state_lock);
    return duplicate;
}

static bool is_stopped(void)
{
    xSemaphoreTake(s_state_lock, portMAX_DELAY);
    const bool stopped = s_stopped;
    xSemaphoreGive(s_state_lock);
    return stopped;
}

static void latch_stop(void)
{
    xSemaphoreTake(s_state_lock, portMAX_DELAY);
    s_stopped = true;
    xSemaphoreGive(s_state_lock);
}

static bool is_ascii_text(const char *text)
{
    if (text == NULL || text[0] == '\0') {
        return false;
    }
    for (const unsigned char *cursor = (const unsigned char *)text; *cursor; ++cursor) {
        if (*cursor >= 0x80) {
            return false;
        }
    }
    return true;
}

static esp_err_t health_handler(httpd_req_t *request)
{
    cJSON *object = cJSON_CreateObject();
    cJSON_AddStringToObject(object, "status", "ok");
    cJSON_AddStringToObject(object, "device", "OpenClaw ESP32-S3");
    cJSON_AddNumberToObject(object, "protocolVersion", 1);
    cJSON_AddBoolToObject(object, "bleConnected", hid_control_is_connected());
    cJSON_AddBoolToObject(object, "stopped", is_stopped());
    const esp_err_t result = send_json(request, HTTPD_200, object);
    cJSON_Delete(object);
    return result;
}

static esp_err_t execute_command(
    httpd_req_t *request,
    cJSON *root,
    uint64_t command_id,
    const char *action
)
{
    if (strcmp(action, "PING") == 0) {
        return send_ack(request, HTTPD_200, command_id, "EXECUTED", "pong");
    }

    if (strcmp(action, "STOP") == 0) {
        latch_stop();
        hid_control_release_all();
        return send_ack(request, HTTPD_200, command_id, "EXECUTED",
                        "emergency stop latched; reboot required to resume");
    }

    if (is_stopped()) {
        return send_ack(request, HTTP_STATUS_CONFLICT, command_id, "REJECTED",
                        "device is stopped; reboot required");
    }

    if (!hid_control_is_connected()) {
        return send_ack(request, HTTP_STATUS_CONFLICT, command_id, "REJECTED",
                        "iPhone BLE HID is not connected");
    }

    esp_err_t result = ESP_ERR_NOT_SUPPORTED;
    if (strcmp(action, "MOVE") == 0) {
        int dx = 0;
        int dy = 0;
        bool has_dx;
        bool has_dy;
        int unused;
        bool has_x;
        bool has_y;
        if (!get_optional_int(root, "deltaX", &dx, &has_dx) ||
            !get_optional_int(root, "deltaY", &dy, &has_dy) ||
            !get_optional_int(root, "x", &unused, &has_x) ||
            !get_optional_int(root, "y", &unused, &has_y)) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "MOVE contains a non-integer coordinate");
        }
        if (has_x || has_y) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "absolute coordinates require iPhone pointer calibration");
        }
        if (!has_dx && !has_dy) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "MOVE requires deltaX or deltaY");
        }
        result = hid_control_move(dx, dy);
    } else if (strcmp(action, "CLICK") == 0) {
        int unused;
        bool has_x;
        bool has_y;
        if (!get_optional_int(root, "x", &unused, &has_x) ||
            !get_optional_int(root, "y", &unused, &has_y)) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "CLICK contains a non-integer coordinate");
        }
        if (has_x || has_y) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "coordinate CLICK requires pointer calibration; move first");
        }
        result = hid_control_click();
    } else if (strcmp(action, "PRESS") == 0) {
        result = hid_control_press();
    } else if (strcmp(action, "RELEASE") == 0) {
        result = hid_control_release();
    } else if (strcmp(action, "SCROLL") == 0) {
        int delta = 0;
        bool present;
        if (!get_optional_int(root, "deltaY", &delta, &present) || !present) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "SCROLL requires integer deltaY");
        }
        result = hid_control_scroll(delta);
    } else if (strcmp(action, "TYPE") == 0) {
        cJSON *text = cJSON_GetObjectItemCaseSensitive(root, "text");
        if (!cJSON_IsString(text) || !is_ascii_text(text->valuestring)) {
            return send_ack(request, HTTPD_400, command_id, "REJECTED",
                            "TYPE currently accepts non-empty ASCII only; UTF-8 was not sent");
        }
        result = hid_control_type_ascii(text->valuestring, strlen(text->valuestring));
    } else {
        return send_ack(request, HTTPD_400, command_id, "REJECTED",
                        "unsupported action");
    }

    if (result == ESP_OK) {
        return send_ack(request, HTTPD_200, command_id, "EXECUTED",
                        "BLE HID report sent");
    }
    ESP_LOGE(TAG, "Action %s failed: %s", action, esp_err_to_name(result));
    return send_ack(request, HTTPD_500, command_id, "FAILED",
                    esp_err_to_name(result));
}

static esp_err_t command_handler(httpd_req_t *request)
{
    if (request->content_len <= 0 || request->content_len > MAX_COMMAND_BODY) {
        return send_error(request, HTTPD_400, "invalid Content-Length");
    }

    char *buffer = calloc(1, request->content_len + 1);
    if (buffer == NULL) {
        return send_error(request, HTTPD_500, "out of memory");
    }
    size_t received = 0;
    while (received < request->content_len) {
        const int count = httpd_req_recv(
            request,
            buffer + received,
            request->content_len - received
        );
        if (count <= 0) {
            free(buffer);
            return ESP_FAIL;
        }
        received += (size_t)count;
    }

    cJSON *root = cJSON_ParseWithLength(buffer, received);
    free(buffer);
    if (!cJSON_IsObject(root)) {
        cJSON_Delete(root);
        return send_error(request, HTTPD_400, "invalid JSON object");
    }

    uint64_t command_id;
    if (!get_command_id(root, &command_id)) {
        cJSON_Delete(root);
        return send_ack(request, HTTPD_400, 0, "REJECTED",
                        "id must be an integer from 0 through 2^53-1");
    }
    if (mark_command_seen(command_id)) {
        cJSON_Delete(root);
        return send_ack(request, HTTPD_200, command_id, "DUPLICATE",
                        "command id was already processed");
    }

    cJSON *action = cJSON_GetObjectItemCaseSensitive(root, "action");
    if (!cJSON_IsString(action)) {
        cJSON_Delete(root);
        return send_ack(request, HTTPD_400, command_id, "REJECTED",
                        "action must be a string");
    }
    const esp_err_t result = execute_command(
        request,
        root,
        command_id,
        action->valuestring
    );
    cJSON_Delete(root);
    return result;
}

esp_err_t protocol_server_start(void)
{
    s_state_lock = xSemaphoreCreateMutex();
    if (s_state_lock == NULL) {
        return ESP_ERR_NO_MEM;
    }

    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = CONFIG_OPENCLAW_HTTP_PORT;
    config.lru_purge_enable = true;
    ESP_RETURN_ON_ERROR(httpd_start(&s_server, &config), TAG, "HTTP server start failed");

    const httpd_uri_t health_uri = {
        .uri = "/v1/health",
        .method = HTTP_GET,
        .handler = health_handler,
        .user_ctx = NULL
    };
    const httpd_uri_t command_uri = {
        .uri = "/v1/command",
        .method = HTTP_POST,
        .handler = command_handler,
        .user_ctx = NULL
    };
    ESP_RETURN_ON_ERROR(httpd_register_uri_handler(s_server, &health_uri),
                        TAG, "health route registration failed");
    ESP_RETURN_ON_ERROR(httpd_register_uri_handler(s_server, &command_uri),
                        TAG, "command route registration failed");
    ESP_LOGI(TAG, "Control server listening on port %d", CONFIG_OPENCLAW_HTTP_PORT);
    return ESP_OK;
}
