#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"

esp_err_t hid_control_init(void);
bool hid_control_is_connected(void);
esp_err_t hid_control_mouse(uint8_t buttons, int8_t dx, int8_t dy, int8_t wheel);
esp_err_t hid_control_click(void);
esp_err_t hid_control_press(void);
esp_err_t hid_control_release(void);
esp_err_t hid_control_move(int dx, int dy);
esp_err_t hid_control_scroll(int delta);
esp_err_t hid_control_type_ascii(const char *text, size_t length);
esp_err_t hid_control_release_all(void);
