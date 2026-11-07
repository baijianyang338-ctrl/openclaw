#!/usr/bin/env python3
"""HTTP mock for the OpenClaw ESP32-S3 control protocol.

This is a development server only. It never controls Bluetooth HID hardware.
"""

from __future__ import annotations

import argparse
import json
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


ACTIONS = {"MOVE", "CLICK", "PRESS", "RELEASE", "SCROLL", "TYPE", "STOP", "PING"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


@dataclass
class MockDeviceState:
    delay_ms: int = 0
    seen: dict[int, dict[str, Any]] = field(default_factory=dict)
    stopped: bool = False
    lock: threading.Lock = field(default_factory=threading.Lock)

    def execute(self, command: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        command_id = command.get("id")
        action = command.get("action")
        if not isinstance(command_id, int) or command_id < 0:
            return HTTPStatus.BAD_REQUEST, self._ack(0, "REJECTED", "id must be a non-negative integer")
        if action not in ACTIONS:
            return HTTPStatus.BAD_REQUEST, self._ack(command_id, "REJECTED", "unsupported action")

        with self.lock:
            if command_id in self.seen:
                return HTTPStatus.OK, self._ack(command_id, "DUPLICATE", "command was already processed")
            self.seen[command_id] = command

            if action == "STOP":
                self.stopped = True
                return HTTPStatus.OK, self._ack(command_id, "EXECUTED", "emergency stop latched")
            if action == "PING":
                return HTTPStatus.OK, self._ack(command_id, "EXECUTED", "pong")
            if self.stopped:
                return HTTPStatus.CONFLICT, self._ack(command_id, "REJECTED", "device is stopped")
            return HTTPStatus.OK, self._ack(command_id, "EXECUTED", "mock execution only")

    @staticmethod
    def _ack(command_id: int, status: str, message: str) -> dict[str, Any]:
        return {"id": command_id, "status": status, "executedAt": utc_now(), "message": message}


class MockESP32Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], state: MockDeviceState):
        super().__init__(address, MockESP32Handler)
        self.device_state = state


class MockESP32Handler(BaseHTTPRequestHandler):
    server: MockESP32Server

    def do_GET(self) -> None:
        if self.path != "/v1/health":
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        self._send(
            HTTPStatus.OK,
            {"status": "ok", "device": "Mock ESP32-S3", "protocolVersion": 1},
        )

    def do_POST(self) -> None:
        if self.path != "/v1/command":
            self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
            self._send(HTTPStatus.BAD_REQUEST, {"error": "invalid JSON"})
            return
        if self.server.device_state.delay_ms:
            time.sleep(self.server.device_state.delay_ms / 1000)
        status, response = self.server.device_state.execute(payload)
        self._send(status, response)

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, fmt: str, *args: object) -> None:
        print("mock-esp32:", fmt % args)


def create_server(host: str, port: int, delay_ms: int = 0) -> MockESP32Server:
    return MockESP32Server((host, port), MockDeviceState(delay_ms=delay_ms))


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenClaw mock ESP32-S3 HTTP server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=3333)
    parser.add_argument("--delay-ms", type=int, default=0)
    args = parser.parse_args()
    server = create_server(args.host, args.port, args.delay_ms)
    print(f"Mock ESP32-S3 listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
