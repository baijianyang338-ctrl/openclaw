#include "esp_err.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "hid_control.h"
#include "device_safety.h"
#include "protocol_server.h"
#include "wifi_station.h"

static const char *TAG = "openclaw_main";

void app_main(void)
{
    esp_err_t result = nvs_flash_init();
    if (result == ESP_ERR_NVS_NO_FREE_PAGES ||
        result == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        result = nvs_flash_init();
    }
    ESP_ERROR_CHECK(result);

    ESP_ERROR_CHECK(hid_control_init());
    ESP_ERROR_CHECK(device_safety_start());
    ESP_LOGI(TAG, "BLE HID ready; pair 'OpenClaw Controller' in iPhone Settings");

    result = openclaw_wifi_station_start();
    if (result != ESP_OK) {
        ESP_LOGE(TAG, "HTTP control disabled because Wi-Fi failed: %s",
                 esp_err_to_name(result));
        return;
    }

    ESP_ERROR_CHECK(protocol_server_start());
}
