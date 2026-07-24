#!/usr/bin/env python3
"""Advertise SERVER and reply to DISCOVER for N seconds."""
import socket
import sys
import time

DISC = 12346
name = sys.argv[1] if len(sys.argv) > 1 else "host"
seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 12.0

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.bind(("", DISC))
sock.settimeout(0.3)
msg = f"SERVER|{name}|12345|1|4".encode()
end = time.time() + seconds
print(f"HOST_START {name}", flush=True)
while time.time() < end:
    for addr in ("255.255.255.255", "10.0.0.255"):
        try:
            sock.sendto(msg, (addr, DISC))
        except OSError:
            pass
    try:
        data, ip = sock.recvfrom(2048)
        print("HOST_RX", data, ip, flush=True)
        if data.startswith(b"DISCOVER"):
            sock.sendto(msg, ip)
            print("HOST_REPLIED", ip, flush=True)
    except socket.timeout:
        pass
    time.sleep(0.15)
sock.close()
print("HOST_DONE", flush=True)
