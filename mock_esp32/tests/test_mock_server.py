from __future__ import annotations

import json
import threading
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone

from mock_esp32.mock_server import create_server


class MockESP32Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.token = "test-only-control-token-1234567890"
        self.server = create_server("127.0.0.1", 0, token=self.token)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, path: str, payload: dict | None = None, timeout: float = 2, token: str | None = None) -> tuple[int, dict]:
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=data,
            method="GET" if payload is None else "POST",
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {self.token if token is None else token}"},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def command(self, command_id: int, action: str, **extra: object) -> dict:
        return {
            "version": 1,
            "id": command_id,
            "action": action,
            "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            **extra,
        }

    def test_health(self) -> None:
        status, body = self.request("/v1/health")
        self.assertEqual(status, 200)
        self.assertEqual(body["protocolVersion"], 1)

    def test_unauthorized_requests_do_not_execute(self) -> None:
        status, _ = self.request("/v1/health", token="wrong")
        command_status, _ = self.request("/v1/command", self.command(77, "CLICK"), token="wrong")
        self.assertEqual(status, 401)
        self.assertEqual(command_status, 401)
        self.assertNotIn(77, self.server.device_state.seen)

    def test_version_is_required(self) -> None:
        command = self.command(78, "CLICK")
        del command["version"]
        status, body = self.request("/v1/command", command)
        self.assertEqual(status, 400)
        self.assertEqual(body["error"], "unsupported protocol version")
        self.assertNotIn(78, self.server.device_state.seen)

    def test_command_ack_and_duplicate_protection(self) -> None:
        status, first = self.request("/v1/command", self.command(1001, "CLICK", x=250, y=600))
        duplicate_status, duplicate = self.request("/v1/command", self.command(1001, "CLICK", x=250, y=600))
        self.assertEqual(status, 200)
        self.assertEqual(first["status"], "EXECUTED")
        self.assertEqual(duplicate_status, 200)
        self.assertEqual(duplicate["status"], "DUPLICATE")

    def test_emergency_stop_rejects_later_actions(self) -> None:
        _, stopped = self.request("/v1/command", self.command(1, "STOP"))
        status, rejected = self.request("/v1/command", self.command(2, "MOVE", x=1, y=2))
        self.assertEqual(stopped["status"], "EXECUTED")
        self.assertEqual(status, 409)
        self.assertEqual(rejected["status"], "REJECTED")

    def test_invalid_action(self) -> None:
        status, body = self.request("/v1/command", self.command(7, "INVALID"))
        self.assertEqual(status, 400)
        self.assertEqual(body["status"], "REJECTED")

    def test_network_disconnect(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        with self.assertRaises((urllib.error.URLError, ConnectionError, OSError)):
            self.request("/v1/health", timeout=0.1)

    def test_command_timeout(self) -> None:
        self.server.device_state.delay_ms = 250
        with self.assertRaises((TimeoutError, urllib.error.URLError, OSError)):
            self.request("/v1/command", self.command(99, "PING"), timeout=0.05)


if __name__ == "__main__":
    unittest.main()

