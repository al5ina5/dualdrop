#!/usr/bin/env python3
"""Advertise a Dualdrop-compatible discovery SERVER packet."""
import socket
import time
import sys

DISC = 12346
name = sys.argv[1] if len(sys.argv) > 1 else "test-host"
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.bind(("", DISC))
sock.settimeout(0.5)
msg = f"SERVER|{name}|12345|1|4".encode()
for _ in range(8):
    for addr in ("255.255.255.255", "10.0.0.255", "127.0.0.1"):
        try:
            sock.sendto(msg, (addr, DISC))
        except OSError as e:
            print("send_err", addr, e)
    time.sleep(0.15)
print("ADVERTISED", name)
end = time.time() + 4
while time.time() < end:
    try:
        data, ip = sock.recvfrom(1024)
        print("RX", data, "from", ip)
        if data.startswith(b"DISCOVER"):
            sock.sendto(msg, ip)
            print("REPLIED", ip)
    except socket.timeout:
        pass
sock.close()
