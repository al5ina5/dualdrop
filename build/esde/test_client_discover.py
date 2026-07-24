#!/usr/bin/env python3
"""DISCOVER via broadcast and unicast to a peer IP."""
import socket
import sys
import time

DISC = 12346
peer = sys.argv[1] if len(sys.argv) > 1 else "10.0.0.165"
seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.settimeout(0.5)
sock.bind(("", 0))
targets = [
    ("255.255.255.255", DISC),
    ("10.0.0.255", DISC),
    (peer, DISC),
]
end = time.time() + seconds
found = []
print(f"CLIENT_START peer={peer}", flush=True)
while time.time() < end:
    for t in targets:
        try:
            sock.sendto(b"DISCOVER", t)
        except OSError as e:
            print("SEND_ERR", t, e, flush=True)
    try:
        data, ip = sock.recvfrom(2048)
        print("CLIENT_RX", data, ip, flush=True)
        if data.startswith(b"SERVER"):
            found.append((data.decode(errors="replace"), ip[0]))
            break
    except socket.timeout:
        pass
sock.close()
if found:
    print("FOUND", found[0], flush=True)
    raise SystemExit(0)
print("NOT_FOUND", flush=True)
raise SystemExit(1)
