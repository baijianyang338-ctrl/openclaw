# OpenClaw ESP32-S3 firmware

This is the real ESP-IDF firmware counterpart to the iPhone app. It is kept in
its own directory and does not replace the existing iOS project.

Implemented now:

- BLE HID composite mouse and keyboard named `OpenClaw Controller`.
- Wi-Fi station mode with credentials supplied by `menuconfig`.
- `GET /v1/health` and `POST /v1/command` on port `3333` by default.
- `MOVE`, `CLICK`, `PRESS`, `RELEASE`, `SCROLL`, ASCII `TYPE`, `STOP`, and
  `PING`.
- Recent command ID deduplication and an emergency-stop latch.
- Accurate failure responses when BLE is disconnected or a command cannot be
  represented safely.

## Requirements

- ESP-IDF 6.1 (the project is compiled and dependency-locked against 6.1.0).
- An ESP32-S3 board with BLE and Wi-Fi.
- The iPhone and board on the same local Wi-Fi network.
- The connected board was measured as ESP32-S3 revision v0.2 with 16 MB flash
  and 8 MB PSRAM. The committed defaults select 16 MB flash for this board.

No Wi-Fi password, signing key, API key, or other credential belongs in Git.
The generated `sdkconfig` is intentionally ignored.

## Configure and build

Run these commands from an initialized ESP-IDF terminal:

```powershell
cd esp32_s3_firmware
idf.py set-target esp32s3
idf.py menuconfig
idf.py build
```

On Windows, both the source staging directory and build directory need ASCII
paths when the source repository lives under a path such as `文档`. Copy the
firmware sources and local `sdkconfig` to an ASCII-only staging directory, then
build there. The verified build output directory was:

```powershell
idf.py -B C:\Espressif\builds\openclaw-esp32s3-16mb build
```

In `menuconfig`, open `OpenClaw ESP32-S3 Configuration` and set the Wi-Fi SSID
and password. Build output must be clean before flashing.

Only after verifying the exact COM port and board:

```powershell
idf.py -p COM3 flash monitor
```

The port above is an example from the current Windows inspection, not a
permanent setting. Always check Device Manager or `Get-CimInstance
Win32_SerialPort` again before flashing.

## Pair and test

1. On iPhone, open Settings > Bluetooth and pair `OpenClaw Controller`.
2. Read the board's IPv4 address from the serial monitor or router.
3. Enter that address and port `3333` in the OpenClaw iPhone app.
4. Run connection test, then `PING`.
5. Test small relative mouse movements before any automated operation.

`MOVE` currently accepts only `deltaX`/`deltaY`. Absolute screen coordinates
and `CLICK` with `x`/`y` are rejected until pointer acceleration and screen
geometry are calibrated on the real iPhone. This prevents an uncalibrated
command from clicking the wrong control.

`TYPE` currently accepts ASCII only. Non-ASCII UTF-8, including Chinese, is
rejected before any key is sent. Chinese input requires a separate verified
iOS input-method strategy and must never be guessed.

`STOP` releases mouse and keyboard reports and latches the device. Reboot the
board to resume. `PING` remains available while stopped for diagnostics.

## Attribution

`main/esp_hid_gap.c` and `main/esp_hid_gap.h` come from Espressif's official
ESP-IDF `examples/bluetooth/esp_hid_device` example and retain the original
`Unlicense OR CC0-1.0` SPDX headers. The OpenClaw-specific HID report map,
protocol validation, and command execution are implemented separately.

