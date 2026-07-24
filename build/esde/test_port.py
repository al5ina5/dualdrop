#!/usr/bin/env python3
"""Probe whether UDP/TCP game port 12345 is reachable."""
import socket
import sys

host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
port = int(sys.argv[2]) if len(sys.argv) > 2 else 12345

# UDP send (ENet listens UDP)
u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
u.settimeout(1.0)
try:
    u.sendto(b"ping", (host, port))
    print("UDP_SENT", host, port)
except OSError as e:
    print("UDP_FAIL", e)
    raise SystemExit(1)
finally:
    u.close()

# TCP connect attempt (may fail if ENet-only; still useful for firewall)
t = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
t.settimeout(1.0)
try:
    r = t.connect_ex((host, port))
    print("TCP_CONNECT_EX", r)
except OSError as e:
    print("TCP_ERR", e)
finally:
    t.close()
print("PORT_PROBE_DONE")
