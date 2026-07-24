#!/usr/bin/env python3
"""Send DISCOVER and wait for SERVER (Dualdrop LAN discovery)."""
import socket
import time

DISC = 12346
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.settimeout(1.0)
sock.bind(("", 0))
for addr in ("255.255.255.255", "10.0.0.255"):
    sock.sendto(b"DISCOVER", (addr, DISC))
print("SENT_DISCOVER")
end = time.time() + 5
found = []
while time.time() < end:
    try:
        data, ip = sock.recvfrom(1024)
        print("RX", data, "from", ip)
        if data.startswith(b"SERVER"):
            found.append((data.decode(errors="replace"), ip[0]))
    except socket.timeout:
        pass
sock.close()
if found:
    print("FOUND", len(found))
    for item in found:
        print("SERVER", item)
else:
    print("NOT_FOUND")
    raise SystemExit(1)
