#pragma once

#include <stdbool.h>

#include "esp_err.h"

esp_err_t device_safety_start(void);
bool device_safety_allows_action(void);
bool device_safety_is_overheated(void);
bool device_safety_temperature_celsius(float *out_temperature);
