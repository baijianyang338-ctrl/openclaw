#include "device_safety.h"

#include "driver/temperature_sensor.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "hid_control.h"

static const char *TAG = "openclaw_safety";
static temperature_sensor_handle_t s_sensor;
static SemaphoreHandle_t s_lock;
static float s_temperature;
static bool s_valid;
static bool s_overheated;

static void sample_temperature(void)
{
    float measured = 0;
    const esp_err_t result = temperature_sensor_get_celsius(s_sensor, &measured);
    bool release = false;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (result != ESP_OK) {
        s_valid = false;
        release = true;
    } else {
        s_temperature = measured;
        s_valid = true;
        if (measured >= CONFIG_OPENCLAW_OVERHEAT_CELSIUS) {
            if (!s_overheated) {
                ESP_LOGE(TAG, "Chip temperature %.1f C reached safety threshold", measured);
            }
            s_overheated = true;
            release = true;
        } else if (measured <= CONFIG_OPENCLAW_OVERHEAT_CELSIUS - 5) {
            s_overheated = false;
        }
    }
    xSemaphoreGive(s_lock);
    if (release) {
        hid_control_release_all();
    }
}

static void temperature_task(void *argument)
{
    while (true) {
        sample_temperature();
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

esp_err_t device_safety_start(void)
{
    s_lock = xSemaphoreCreateMutex();
    if (s_lock == NULL) {
        return ESP_ERR_NO_MEM;
    }
    const temperature_sensor_config_t configuration =
        TEMPERATURE_SENSOR_CONFIG_DEFAULT(-10, 80);
    esp_err_t result = temperature_sensor_install(&configuration, &s_sensor);
    if (result != ESP_OK) {
        return result;
    }
    result = temperature_sensor_enable(s_sensor);
    if (result != ESP_OK) {
        return result;
    }
    sample_temperature();
    if (!device_safety_allows_action()) {
        ESP_LOGW(TAG, "Control starts paused until temperature is readable and below threshold");
    }
    return xTaskCreate(temperature_task, "openclaw_temp", 3072, NULL, 5, NULL) == pdPASS
        ? ESP_OK : ESP_ERR_NO_MEM;
}

bool device_safety_allows_action(void)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const bool allowed = s_valid && !s_overheated;
    xSemaphoreGive(s_lock);
    return allowed;
}

bool device_safety_is_overheated(void)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const bool overheated = s_overheated;
    xSemaphoreGive(s_lock);
    return overheated;
}

bool device_safety_temperature_celsius(float *out_temperature)
{
    xSemaphoreTake(s_lock, portMAX_DELAY);
    const bool valid = s_valid;
    if (valid) {
        *out_temperature = s_temperature;
    }
    xSemaphoreGive(s_lock);
    return valid;
}
