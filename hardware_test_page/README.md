# iPhone BLE HID click test

Run `python hardware_test_page/server.py` on the Windows PC while the PC and
iPhone are on the same trusted LAN. Open `http://<PC-LAN-IP>:8765/` in iPhone
Safari. The large blue button fills most of the page; after it loads, do not
touch the page. Move the BLE pointer into the webpage and send one `CLICK` from
the ESP32. Any click inside the page is counted. The page displays the number
of clicks, and `GET /status` lets the PC
verify that the event arrived. The page also records `pointermove`,
`pointerdown`, and `pointerup` with pointer type and viewport coordinates in
`GET /status`; this helps distinguish a missing HID event from a pointer
landing outside the button. Reload the page after changing the test server.
Use this test before attempting input in any
third-party app. Stop the local server when done.

The server has no authentication and listens on the PC's LAN interface, so use
it only for a short session on a trusted network. It receives no screenshots,
credentials, or activity data.

