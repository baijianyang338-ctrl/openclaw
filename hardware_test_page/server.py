"""A local, disposable page for checking iPhone BLE HID input without Douyin."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading


_lock = threading.Lock()
_clicks = 0
_events = []

PAGE = """<!doctype html>
<html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>OpenClaw HID 联调</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;padding:20px;background:#f4f6fb;color:#10233d}
main{max-width:600px;margin:auto;text-align:center}
.gift-icon{position:fixed;top:64px;left:12px;width:54px;height:54px;border-radius:50%;
background:#ed4a39;color:white;display:grid;place-items:center;font-size:30px}
.rules{background:white;border-radius:20px;padding:12px;margin:14px auto;text-align:left}
.rules p{margin:8px 0;font-size:20px}
button{width:100%;height:48vh;margin-top:10px;border:0;border-radius:24px;
background:#245de8;color:white;font-size:32px;font-weight:700}
output{display:block;margin-top:16px;font-size:21px}
</style>
<div class="gift-icon" aria-label="模拟福袋图标">🎁</div>
<main><h1>鼠标点击测试</h1>
<p>页面加载后请不要用手触摸蓝色区域。等待 ESP32 发送一次点击。</p>
<section class="rules"><h2>福袋</h2><p>参与条件</p>
<p>指定评论：Hello123</p><p>倒计时 00:30</p></section>
<button id="target">点击这里</button><output id="result">等待点击</output></main>
<script>
let lastMove = 0;
async function report(event) {
  const r = await fetch('/event', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      type: event.type,
      pointerType: event.pointerType || 'unknown',
      x: Math.round(event.clientX),
      y: Math.round(event.clientY),
      buttons: event.buttons
    })
  });
  if (event.type === 'click') {
    const data = await r.json();
    document.querySelector('#result').textContent = '收到点击：' + data.clicks + ' 次';
  }
}
for (const name of ['pointermove', 'pointerdown', 'pointerup', 'click']) {
  document.addEventListener(name, event => {
    if (name === 'pointermove') {
      const now = Date.now();
      if (now - lastMove < 250) return;
      lastMove = now;
    }
    report(event).catch(() => {});
  });
}
</script></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
        elif self.path == "/status":
            with _lock:
                body = json.dumps({"clicks": _clicks, "events": _events[-20:]}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
        else:
            self.send_error(404)
            return
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        global _clicks
        if self.path != "/event":
            self.send_error(404)
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 1024)
            event = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self.send_error(400)
            return
        if not isinstance(event, dict):
            self.send_error(400)
            return
        summary = {
            "type": str(event.get("type", "unknown"))[:20],
            "pointerType": str(event.get("pointerType", "unknown"))[:20],
            "x": event.get("x"),
            "y": event.get("y"),
            "buttons": event.get("buttons"),
        }
        with _lock:
            _events.append(summary)
            del _events[:-100]
            if summary["type"] == "click":
                _clicks += 1
            body = json.dumps({"clicks": _clicks}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8765), Handler)
    print("HID test page listening on port 8765", flush=True)
    server.serve_forever()

