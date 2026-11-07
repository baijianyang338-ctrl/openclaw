#include "hid_control.h"

#include <stdlib.h>
#include <string.h>

#include "esp_check.h"
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_hid_common.h"
#include "esp_hid_gap.h"
#include "esp_hidd.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define MOUSE_REPORT_ID 1
#define KEYBOARD_REPORT_ID 2
#define KEYBOARD_LEFT_SHIFT 0x02

static const char *TAG = "openclaw_hid";
static esp_hidd_dev_t *s_hid_device;
static volatile bool s_connected;
static uint8_t s_mouse_buttons;

/* Required by Espressif's shared GAP helper after BLE authentication. */
void ble_hid_task_start_up(void)
{
    /* OpenClaw is event-driven; there is no demo input task to start. */
}

/* One BLE HID report map with mouse and keyboard top-level collections. */
static const uint8_t s_report_map[] = {
    0x05, 0x01,       /* Usage Page (Generic Desktop) */
    0x09, 0x02,       /* Usage (Mouse) */
    0xA1, 0x01,       /* Collection (Application) */
    0x85, MOUSE_REPORT_ID,
    0x09, 0x01,       /* Pointer */
    0xA1, 0x00,       /* Collection (Physical) */
    0x05, 0x09,       /* Buttons */
    0x19, 0x01,
    0x29, 0x03,
    0x15, 0x00,
    0x25, 0x01,
    0x95, 0x03,
    0x75, 0x01,
    0x81, 0x02,
    0x95, 0x01,
    0x75, 0x05,
    0x81, 0x03,
    0x05, 0x01,
    0x09, 0x30,       /* X */
    0x09, 0x31,       /* Y */
    0x09, 0x38,       /* Wheel */
    0x15, 0x81,
    0x25, 0x7F,
    0x75, 0x08,
    0x95, 0x03,
    0x81, 0x06,
    0xC0,
    0xC0,

    0x05, 0x01,       /* Usage Page (Generic Desktop) */
    0x09, 0x06,       /* Usage (Keyboard) */
    0xA1, 0x01,
    0x85, KEYBOARD_REPORT_ID,
    0x05, 0x07,
    0x19, 0xE0,
    0x29, 0xE7,
    0x15, 0x00,
    0x25, 0x01,
    0x75, 0x01,
    0x95, 0x08,
    0x81, 0x02,
    0x95, 0x01,
    0x75, 0x08,
    0x81, 0x03,
    0x95, 0x05,
    0x75, 0x01,
    0x05, 0x08,
    0x19, 0x01,
    0x29, 0x05,
    0x91, 0x02,
    0x95, 0x01,
    0x75, 0x03,
    0x91, 0x03,
    0x95, 0x06,
    0x75, 0x08,
    0x15, 0x00,
    0x25, 0x65,
    0x05, 0x07,
    0x19, 0x00,
    0x29, 0x65,
    0x81, 0x00,
    0xC0
};

static esp_hid_raw_report_map_t s_report_maps[] = {
    {.data = s_report_map, .len = sizeof(s_report_map)}
};

static esp_hid_device_config_t s_hid_config = {
    .vendor_id = 0x303A,
    .product_id = 0x4001,
    .version = 0x0100,
    .device_name = "OpenClaw Controller",
    .manufacturer_name = "OpenClaw",
    .serial_number = "ESP32S3",
    .report_maps = s_report_maps,
    .report_maps_len = 1
};

static void hid_event_callback(
    void *handler_args,
    esp_event_base_t base,
    int32_t id,
    void *event_data
)
{
    const esp_hidd_event_t event = (esp_hidd_event_t)id;
    switch (event) {
    case ESP_HIDD_START_EVENT:
        ESP_LOGI(TAG, "BLE HID started; advertising");
        esp_hid_ble_gap_adv_start();
        break;
    case ESP_HIDD_CONNECT_EVENT:
        s_connected = true;
        ESP_LOGI(TAG, "iPhone BLE HID connected");
        break;
    case ESP_HIDD_DISCONNECT_EVENT:
        s_connected = false;
        s_mouse_buttons = 0;
        ESP_LOGW(TAG, "BLE HID disconnected; advertising again");
        esp_hid_ble_gap_adv_start();
        break;
    case ESP_HIDD_STOP_EVENT:
        s_connected = false;
        ESP_LOGI(TAG, "BLE HID stopped");
        break;
    default:
        break;
    }
}

esp_err_t hid_control_init(void)
{
    ESP_RETURN_ON_ERROR(esp_hid_gap_init(HIDD_BLE_MODE), TAG, "BLE GAP init failed");
    ESP_RETURN_ON_ERROR(
        esp_hid_ble_gap_adv_init(ESP_HID_APPEARANCE_GENERIC, s_hid_config.device_name),
        TAG,
        "BLE advertising init failed"
    );
    ESP_RETURN_ON_ERROR(
        esp_ble_gatts_register_callback(esp_hidd_gatts_event_handler),
        TAG,
        "GATTS callback registration failed"
    );
    ESP_RETURN_ON_ERROR(
        esp_hidd_dev_init(
            &s_hid_config,
            ESP_HID_TRANSPORT_BLE,
            hid_event_callback,
            &s_hid_device
        ),
        TAG,
        "BLE HID device init failed"
    );
    return esp_hidd_dev_battery_set(s_hid_device, 100);
}

bool hid_control_is_connected(void)
{
    return s_connected && s_hid_device != NULL && esp_hidd_dev_connected(s_hid_device);
}

esp_err_t hid_control_mouse(uint8_t buttons, int8_t dx, int8_t dy, int8_t wheel)
{
    if (!hid_control_is_connected()) {
        return ESP_ERR_INVALID_STATE;
    }
    uint8_t report[4] = {buttons, (uint8_t)dx, (uint8_t)dy, (uint8_t)wheel};
    return esp_hidd_dev_input_set(
        s_hid_device,
        0,
        MOUSE_REPORT_ID,
        report,
        sizeof(report)
    );
}

esp_err_t hid_control_click(void)
{
    esp_err_t result = hid_control_mouse(1, 0, 0, 0);
    if (result != ESP_OK) {
        return result;
    }
    vTaskDelay(pdMS_TO_TICKS(35));
    return hid_control_mouse(0, 0, 0, 0);
}

esp_err_t hid_control_press(void)
{
    s_mouse_buttons = 1;
    return hid_control_mouse(s_mouse_buttons, 0, 0, 0);
}

esp_err_t hid_control_release(void)
{
    s_mouse_buttons = 0;
    return hid_control_mouse(0, 0, 0, 0);
}

static int8_t next_chunk(int *remaining)
{
    if (*remaining > 127) {
        *remaining -= 127;
        return 127;
    }
    if (*remaining < -127) {
        *remaining += 127;
        return -127;
    }
    const int8_t value = (int8_t)*remaining;
    *remaining = 0;
    return value;
}

esp_err_t hid_control_move(int dx, int dy)
{
    do {
        const int8_t chunk_x = next_chunk(&dx);
        const int8_t chunk_y = next_chunk(&dy);
        const esp_err_t result = hid_control_mouse(s_mouse_buttons, chunk_x, chunk_y, 0);
        if (result != ESP_OK) {
            return result;
        }
        vTaskDelay(pdMS_TO_TICKS(8));
    } while (dx != 0 || dy != 0);
    return ESP_OK;
}

esp_err_t hid_control_scroll(int delta)
{
    do {
        const int8_t chunk = next_chunk(&delta);
        const esp_err_t result = hid_control_mouse(s_mouse_buttons, 0, 0, chunk);
        if (result != ESP_OK) {
            return result;
        }
        vTaskDelay(pdMS_TO_TICKS(8));
    } while (delta != 0);
    return ESP_OK;
}

static bool ascii_to_hid(char character, uint8_t *modifier, uint8_t *keycode)
{
    *modifier = 0;
    if (character >= 'a' && character <= 'z') {
        *keycode = (uint8_t)(0x04 + character - 'a');
        return true;
    }
    if (character >= 'A' && character <= 'Z') {
        *modifier = KEYBOARD_LEFT_SHIFT;
        *keycode = (uint8_t)(0x04 + character - 'A');
        return true;
    }
    if (character >= '1' && character <= '9') {
        *keycode = (uint8_t)(0x1E + character - '1');
        return true;
    }
    if (character == '0') {
        *keycode = 0x27;
        return true;
    }

    struct key_mapping { char character; uint8_t modifier; uint8_t keycode; };
    static const struct key_mapping mappings[] = {
        {' ', 0, 0x2C}, {'\n', 0, 0x28}, {'\t', 0, 0x2B},
        {'-', 0, 0x2D}, {'_', KEYBOARD_LEFT_SHIFT, 0x2D},
        {'=', 0, 0x2E}, {'+', KEYBOARD_LEFT_SHIFT, 0x2E},
        {'[', 0, 0x2F}, {'{', KEYBOARD_LEFT_SHIFT, 0x2F},
        {']', 0, 0x30}, {'}', KEYBOARD_LEFT_SHIFT, 0x30},
        {'\\', 0, 0x31}, {'|', KEYBOARD_LEFT_SHIFT, 0x31},
        {';', 0, 0x33}, {':', KEYBOARD_LEFT_SHIFT, 0x33},
        {'\'', 0, 0x34}, {'"', KEYBOARD_LEFT_SHIFT, 0x34},
        {'`', 0, 0x35}, {'~', KEYBOARD_LEFT_SHIFT, 0x35},
        {',', 0, 0x36}, {'<', KEYBOARD_LEFT_SHIFT, 0x36},
        {'.', 0, 0x37}, {'>', KEYBOARD_LEFT_SHIFT, 0x37},
        {'/', 0, 0x38}, {'?', KEYBOARD_LEFT_SHIFT, 0x38},
        {'!', KEYBOARD_LEFT_SHIFT, 0x1E}, {'@', KEYBOARD_LEFT_SHIFT, 0x1F},
        {'#', KEYBOARD_LEFT_SHIFT, 0x20}, {'$', KEYBOARD_LEFT_SHIFT, 0x21},
        {'%', KEYBOARD_LEFT_SHIFT, 0x22}, {'^', KEYBOARD_LEFT_SHIFT, 0x23},
        {'&', KEYBOARD_LEFT_SHIFT, 0x24}, {'*', KEYBOARD_LEFT_SHIFT, 0x25},
        {'(', KEYBOARD_LEFT_SHIFT, 0x26}, {')', KEYBOARD_LEFT_SHIFT, 0x27}
    };
    for (size_t i = 0; i < sizeof(mappings) / sizeof(mappings[0]); ++i) {
        if (mappings[i].character == character) {
            *modifier = mappings[i].modifier;
            *keycode = mappings[i].keycode;
            return true;
        }
    }
    return false;
}

esp_err_t hid_control_type_ascii(const char *text, size_t length)
{
    if (!hid_control_is_connected()) {
        return ESP_ERR_INVALID_STATE;
    }
    for (size_t i = 0; i < length; ++i) {
        uint8_t modifier;
        uint8_t keycode;
        if (((uint8_t)text[i] & 0x80) != 0 ||
            !ascii_to_hid(text[i], &modifier, &keycode)) {
            return ESP_ERR_NOT_SUPPORTED;
        }
        uint8_t pressed[8] = {modifier, 0, keycode, 0, 0, 0, 0, 0};
        uint8_t released[8] = {0};
        ESP_RETURN_ON_ERROR(
            esp_hidd_dev_input_set(s_hid_device, 0, KEYBOARD_REPORT_ID,
                                   pressed, sizeof(pressed)),
            TAG,
            "Key press failed"
        );
        vTaskDelay(pdMS_TO_TICKS(25));
        ESP_RETURN_ON_ERROR(
            esp_hidd_dev_input_set(s_hid_device, 0, KEYBOARD_REPORT_ID,
                                   released, sizeof(released)),
            TAG,
            "Key release failed"
        );
        vTaskDelay(pdMS_TO_TICKS(15));
    }
    return ESP_OK;
}

esp_err_t hid_control_release_all(void)
{
    s_mouse_buttons = 0;
    if (!hid_control_is_connected()) {
        return ESP_OK;
    }
    uint8_t keyboard_release[8] = {0};
    esp_err_t result = hid_control_mouse(0, 0, 0, 0);
    const esp_err_t keyboard_result = esp_hidd_dev_input_set(
        s_hid_device,
        0,
        KEYBOARD_REPORT_ID,
        keyboard_release,
        sizeof(keyboard_release)
    );
    return result == ESP_OK ? keyboard_result : result;
}
