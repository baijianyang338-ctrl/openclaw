# ESP32-S3 firmware validation record

## Current Windows inspection

- Device enumerated as Espressif ESP32-S3 USB JTAG/serial debug unit.
- Serial port observed: `COM3`.
- USB identifier observed: `VID_303A&PID_1001`.
- ESP-IDF 6.1 was present through Espressif Installation Manager but required
  its environment variables to be activated manually in the non-interactive
  terminal.
- The initial inspection did not access the serial bootloader.

## Read-only board probe and 16 MB rebuild

On 2026-11-07, `esptool flash-id` connected through `COM3` and reported an
ESP32-S3 revision v0.2, 8 MB embedded PSRAM, and 16 MB quad flash. The probe
used the serial bootloader and reset the board afterward; it did not read,
erase, or write flash contents. The device MAC address is intentionally omitted
from this repository.

The earlier generated configuration used the ESP-IDF default 2 MB flash size.
`sdkconfig.defaults` now selects 16 MB to match the measured board. A direct
reconfigure from the repository path failed because the Windows toolchain
mis-encoded `文档` in `Kconfig.projbuild`. The same source and configuration were
copied to the ASCII-only directory `C:\Espressif\builds\openclaw-source-16mb`
and built at `C:\Espressif\builds\openclaw-esp32s3-16mb`.

The complete ESP-IDF 6.1 build finished with exit code 0. `esptool image-info`
confirmed ESP32-S3, DIO at 80 MHz, and a 16 MB flash header. The application
image is 851,184 bytes, with 45% of its app partition free. The local Wi-Fi
SSID and password remain unconfigured, and this image has not been flashed.

After adding NVS-backed control-token authentication and rejection of open
Wi-Fi, the firmware was rebuilt successfully with ESP-IDF 6.1. The resulting
16 MB image is 852,768 bytes (`0xd0320`) with 44% of the app partition free.
This is a compile result; no physical Wi-Fi, BLE, or authorization test has
been performed on the board yet.

The COM port is transient and must be rechecked immediately before flashing.

## Host-side protocol tests

The HTTP protocol is exercised by `mock_esp32/tests/test_mock_server.py` for:

- health response;
- command acknowledgement;
- duplicate command protection;
- emergency-stop behavior;
- unsupported actions;
- network disconnect; and
- command timeout.

Run:

```text
python -m unittest discover -s mock_esp32/tests -v
```

## Still requiring hardware verification

- Flash and boot log on the exact 正点原子 DNESP32S3 revision.
- iPhone Bluetooth pairing and reconnect behavior.
- Mouse direction, scroll direction, pointer acceleration, and absolute
  coordinate calibration.
- ASCII keyboard layout on the selected iOS keyboard.
- Chinese text entry strategy.
- Long-running Wi-Fi reconnect, latency, power, and thermal measurements.

A successful Mock test proves protocol behavior only; it does not prove a BLE
HID report reached the iPhone.

## ESP-IDF build result

The firmware was compiled successfully for target `esp32s3` with ESP-IDF 6.1.
The repository lives below a Chinese Windows path, so the normal in-tree build
failed when GCC misread the generated specs path. Building in the ASCII-only
directory `C:\Espressif\builds\openclaw-esp32s3` resolved that host tooling
issue without moving or modifying the repository.

Generated artifacts:

- bootloader: 21,120 bytes;
- partition table: 3,072 bytes;
- application image: 851,184 bytes (`0xcfcf0`);
- smallest application partition: `0x177000`, leaving `0xa7310` bytes (45%).

The build generated `openclaw_esp32_s3.bin` and completed with exit code 0.
Build artifacts remain outside Git and have not been flashed.

