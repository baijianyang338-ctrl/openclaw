"""A local, disposable page for checking iPhone BLE HID input without Douyin."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading


_lock = threading.Lock()
_clicks = 0

PAGE = """<!doctype html>
<html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<title>OpenClaw HID 联调</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;padding:20px;background:#f4f6fb;color:#10233d}
main{max-width:600px;margin:auto;text-align:center}
button{width:100%;height:65vh;margin-top:20px;border:0;border-radius:24px;
background:#245de8;color:white;font-size:32px;font-weight:700}
output{display:block;margin-top:16px;font-size:21px}
</style>
<main><h1>鼠标点击测试</h1>
<p>页面加载后请不要用手触摸蓝色区域。等待 ESP32 发送一次点击。</p>
<button id="target">点击这里</button><output id="result">等待点击</output></main>
<script>
document.addEventListener('click',async()=>{
  const r=await fetch('/event',{method:'POST'});
  const data=await r.json();
  document.querySelector('#result').textContent='收到点击：'+data.clicks+' 次';
});
</script></html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
        elif self.path == "/status":
            with _lock:
                body = json.dumps({"clicks": _clicks}).encode("utf-8")
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
        with _lock:
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
