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
confirmed ESP32-S3, DIO at 80 MHz, and a 16 MB flash header. After adding
NVS-backed control-token authentication, the firmware was rebuilt successfully.
The Wi-Fi credentials were configured only in the local staging directory's
ignored `sdkconfig`; their values and the resulting personalized binary are not
committed to Git.

On 2026-11-07, a full 16 MB read-only backup was saved at
`C:\Espressif\builds\esp32-before-openclaw-20261107.bin` before writing the
board. Its SHA-256 is
`5B44C859F01F450FDB77CE41462D1A6B5CF0D965252A94A1C53CE26BF5026E0A`.
`idf.py flash` then completed with exit code 0 on `COM3`. The board booted,
started BLE HID advertising, initialized the chip temperature sensor, and
obtained IPv4 address `172.20.10.2`. This is a real flash and boot observation,
not yet an iPhone BLE pairing or phone-control verification.

The final temperature-enabled application image is 1,315,280 bytes, SHA-256
`D29E7432113B8BD34FB73D21B70AE2ABB92D42CC77D88938262AED2B23D2F154`.
It was flashed with `esptool write-flash` after the successful ESP-IDF 6.1
build. A fresh serial boot capture confirmed both 16-character pairing-token
parts, BLE advertising, temperature-sensor initialization and the IPv4 address.
The actual token was withheld from this record.

The Windows PC was on a different Wi-Fi network at this check. TCP to the
board's port `3333` therefore failed; HTTP authentication, PING and command
execution against the physical board remain unverified. A private local NVS
read confirmed a 32-character control token exists, without printing or
committing it. The board and test client must be on the same LAN for the next
HTTP test.

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

- HTTP authorization, PING, deduplication, STOP and temperature status on the
  actual board after the test client joins the same Wi-Fi network.
- iPhone Bluetooth pairing and reconnect behavior.
- Mouse direction, scroll direction, pointer acceleration, and absolute
  coordinate calibration.
- ASCII keyboard layout on the selected iOS keyboard.
- Chinese text entry strategy.
- Long-running Wi-Fi reconnect, latency, power, and thermal measurements.
- Overheat-trigger and recovery behavior on hardware; sensor initialization
  alone does not prove thermal shutdown works.

A successful Mock test proves protocol behavior only; it does not prove a BLE
HID report reached the iPhone.

## Build environment

The repository lives below a Chinese Windows path, so the in-tree toolchain
mis-encoded `文档`. Building from the ASCII-only staging source at
`C:\Espressif\builds\openclaw-source-16mb` with output at
`C:\Espressif\builds\openclaw-esp32s3-16mb` resolved that host tooling issue.
The personalized local BIN contains the configured Wi-Fi credentials and must
not be published or attached to a GitHub release.
