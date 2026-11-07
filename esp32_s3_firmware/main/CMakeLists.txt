idf_component_register(
    SRCS
        "app_main.c"
        "esp_hid_gap.c"
        "hid_control.c"
        "protocol_server.c"
        "wifi_station.c"
    INCLUDE_DIRS "."
    REQUIRES bt esp_event esp_hid esp_http_server esp_wifi nvs_flash
)
