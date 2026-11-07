# ESP32-S3 firmware validation record

## Current Windows inspection

- Device enumerated as Espressif ESP32-S3 USB JTAG/serial debug unit.
- Serial port observed: `COM3`.
- USB identifier observed: `VID_303A&PID_1001`.
- ESP-IDF 6.1 was present through Espressif Installation Manager but required
  its environment variables to be activated manually in the non-interactive
  terminal.
- No flash, erase, reset, or serial write operation was performed.

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
