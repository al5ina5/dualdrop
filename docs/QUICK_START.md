# Quick Start

## Play on ES-DE kiosks (aio / kiosk)

See **[ESDE_LAN_INSTALL.md](ESDE_LAN_INSTALL.md)** for the minimal install path.

Rebuild and overwrite game files on both machines (leaves `~/ROMs/ports/Dualdrop.sh` alone):

```bash
npm run deploy:machines
```

Or one host at a time:

```bash
npm run deploy:kiosk
npm run deploy:aio
```

`deploy:aio` uses `kiosk.local` as jump host when direct SSH is closed. Optional password:

```bash
DEPLOY_SSH_PASS='...' npm run deploy:aio
```

LAN: Multiplayer → LAN → Create Game on one machine, Find Game (or Join By IP) on the other.

## Run locally (dev)

```bash
love .
```

Requires LÖVE 11.5.

## Online multiplayer (optional)

Online matchmaking uses the Railway relay configured in `src/constants.lua` (`API_BASE_URL`, `RELAY_HOST`, `RELAY_PORT`). Source for the relay server is in `relay/`.

Legacy Ably/Vercel docs are obsolete and were removed from this quick start.
