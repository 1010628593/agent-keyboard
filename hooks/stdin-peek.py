import os
import select
import sys
import time

if sys.stdin.isatty():
    raise SystemExit
ready, _, _ = select.select([sys.stdin], [], [], 0.2)
if not ready:
    raise SystemExit
fd = sys.stdin.fileno()
os.set_blocking(fd, False)
buf = b""
deadline = time.time() + 0.2
while time.time() < deadline:
    try:
        chunk = os.read(fd, 65536)
    except BlockingIOError:
        time.sleep(0.02)
        continue
    if not chunk:
        break
    buf += chunk
sys.stdout.buffer.write(buf)
