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

The latest application image is 1,315,760 bytes, SHA-256
`67B1A4AA38BED07C41C8FD35181D451122002F244ED2CC07CB22A826EFC22737`.
It was flashed with `esptool write-flash` after the successful ESP-IDF 6.1
build. A fresh serial boot capture confirmed both 16-character pairing-token
parts, successful BLE advertising configuration and start, temperature-sensor
initialization and the IPv4 address.
The actual token was withheld from this record.

Initially, the Windows PC was on a different Wi-Fi network, and TCP to port
`3333` failed. After the PC joined the board's LAN, the physical HTTP test
returned HTTP 401 without a token, HTTP 200 for authenticated health, HTTP
200/`EXECUTED` for PING, and `DUPLICATE` for an identical command ID. Health
reported protocol v1, chip temperature 33-35 °C, and no overheat. No response
contained the token. A private local NVS read confirmed a 32-character token;
its value was never printed or committed.

On 2026-11-09, the board was reconnected on `COM3`, joined the iPhone hotspot
as `172.20.10.2`, and passed a fresh authenticated health check. Health
reported BLE connected, not stopped, and 27-28 °C. A new PING returned
`EXECUTED`; reusing its ID returned `DUPLICATE`. The board typed its own
32-character token into the focused iPhone App field via BLE HID keyboard;
the user then confirmed the App's authenticated connection test showed
connected, BLE connected, and 28 °C. The user also sent PING from the App and
provided a screenshot of the matching `EXECUTED` acknowledgement. This verifies
the iPhone App to Wi-Fi to physical ESP32 request/response path and one ASCII
BLE keyboard input. It does not prove Chinese input or a completed screen action.

The first BLE advertising payload exceeded the legacy packet limit and the
serial log reported a partial write. A subsequent structured-data attempt
failed with code 258. The current firmware uses an explicit 28-byte packet
containing the HID service UUID and full device name; the serial log confirms
both data configuration and advertising start. The user then paired
`OpenClaw Controller` with the iPhone, and the board's health endpoint reported
`bleConnected: true`.

A relative `MOVE` command first returned HTTP 200/`EXECUTED` with “BLE HID
report sent”, but the user saw no pointer motion. An authenticated STOP then
returned `EXECUTED`, and health confirmed `stopped: true`. Apple documents
that iPhone mouse pointer use requires AssistiveTouch to be enabled
([Apple Support](https://support.apple.com/zh-cn/111775)). After the user
enabled AssistiveTouch, the board was rebooted to clear the stop latch, BLE
reconnected, and health reported `bleConnected: true`. A second relative
`MOVE` (`deltaX: 30`) returned `EXECUTED`; the user confirmed the gray iPhone
pointer moved to the right. This verifies one real Wi-Fi → ESP32 → BLE HID →
iPhone pointer-movement path. It does not verify clicking, scrolling, keyboard
input, coordinate calibration, or activity participation.

For the next click test, an iPhone Safari page served from the Windows PC was
loaded successfully. The user tapped its blue area by finger and the server
count increased from 0 to 1, proving the page's click recorder works. One HID
`CLICK`, then a separate 300 ms `PRESS`/`RELEASE`, both returned `EXECUTED`
from the ESP32, but the server count did not increase. The click path is **not
verified**; the pointer position and iPhone button mapping need further
diagnosis. The final authenticated `STOP` returned `EXECUTED` and health
confirmed `stopped: true`. The temporary page server was then shut down.

On 2026-11-09, the Safari test page was served again from the Windows PC and
the phone fetched it over the hotspot. A physical `CLICK` again returned
`EXECUTED` but did not increment the server counter. A move-to-page sequence
also returned `EXECUTED` for two moves and a click, with no new click event.
The user confirmed AssistiveTouch was enabled and Bluetooth was connected,
but the pointer was not visible in Safari and the controller did not appear
under AssistiveTouch's Devices list. Pointer visibility and iOS button mapping
remain under diagnosis. `EXECUTED` still means only that the firmware API
accepted the BLE report.

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

- iPhone click, scroll, precise pointer calibration, and repeated
  disconnect/reconnect cycles. BLE pairing and one pointer movement were
  user-observed, but click has not changed a test page.
- Mouse direction, scroll direction, pointer acceleration, and absolute
  coordinate calibration.
- ASCII keyboard layout beyond the tested lowercase hexadecimal token.
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

