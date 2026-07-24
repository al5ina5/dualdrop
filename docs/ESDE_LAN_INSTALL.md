# ES-DE / LAN install (aio + kiosk)

Minimal install only — does not modify Emusation, PortMaster, or other games.

## Build

```bash
./build/esde/build.sh
```

Produces:

- `dist/esde/Dualdrop/love.AppImage` — bundled LÖVE 11.5
- `dist/esde/Dualdrop/Dualdrop.love`
- `dist/esde/Dualdrop.sh` — ES-DE Ports launcher

## Deploy

Preferred (rebuilds, then overwrites **game files only** on the host):

```bash
npm run deploy:machines   # kiosk + aio
npm run deploy:kiosk      # kiosk.local only
npm run deploy:aio        # aio.local (jumps via kiosk when needed)
```

Does **not** touch `~/ROMs/ports/Dualdrop.sh` (Emusation hotkey/fullscreen wrapper stays put).

Underlying scripts (same result):

```bash
./build/esde/deploy.sh kiosk.local
./build/esde/deploy.sh aio.local
```

Uses SSH as `alsinas@host` (key auth preferred). Optional password:

```bash
DEPLOY_SSH_PASS='...' npm run deploy:aio
```

## What gets written on the host

| Path | Purpose |
|------|---------|
| `~/Games/Dualdrop/` | Game + bundled LÖVE (overwritten on deploy) |
| `~/ROMs/ports/Dualdrop.sh` | **Not deployed** — keep the Emusation wrapper on the machine |

Nothing else.

## Play LAN

1. Both machines: ES-DE → Ports → Dualdrop  
2. Host: Multiplayer → LAN → Create Game (note `IP:12345`)  
3. Guest: Multiplayer → LAN → Find Game (or Join By IP)  

Ports: game `12345`, discovery `12346` (UDP).

### Firewall (required on hosts with UFW)

If UFW is active (aio uses it), allow LAN UDP like other ports games:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 12345 proto udp comment 'Dualdrop LAN game'
sudo ufw allow from 10.0.0.0/24 to any port 12346 proto udp comment 'Dualdrop LAN discovery'
```

Without this, FIND GAME / JOIN BY IP will fail when that machine is host.

### Jump deploy (aio when port 22 closed from your Mac)

`npm run deploy:aio` / `npm run deploy:machines` already set `DEPLOY_JUMP=kiosk.local`. Manual equivalent:

```bash
DEPLOY_JUMP=kiosk.local DEPLOY_SSH_PASS='...' ./build/esde/deploy.sh aio.local
```

## Online (optional)

Matchmaker/relay: Railway URL in `src/constants.lua`. LAN does not need it.
