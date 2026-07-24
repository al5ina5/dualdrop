import express, { Request, Response } from 'express';
import cors from 'cors';
import net from 'net';

// --- Configuration ---
const HTTP_PORT = process.env.PORT || 3000;
const TCP_PORT = process.env.TCP_PORT || 12346;

const FORMAT_SEATS: Record<string, number> = {
  '1v1': 2,
  '2v1': 3,
  '2v2': 4,
};

// --- Types ---
interface Room {
  code: string;
  hostName: string;
  isPublic: boolean;
  players: number; // seats used
  maxPlayers: number; // max seats
  format: string;
  createdAt: number;
  lastHeartbeat: number;
  gameStarted: boolean;
}

interface RoomData {
  sockets: net.Socket[];
  gameStarted: boolean;
}

// --- In-Memory State ---
const rooms = new Map<string, Room>();
const roomSockets = new Map<string, RoomData>();

function generateRoomCode(): string {
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  return code;
}

function resolveMaxSeats(format?: string, maxSeats?: number): number {
  if (typeof maxSeats === 'number' && maxSeats >= 2 && maxSeats <= 4) return maxSeats;
  if (format && FORMAT_SEATS[format]) return FORMAT_SEATS[format];
  return 2;
}

// --- HTTP Server (Matchmaker) ---
const app = express();
app.use(cors());
app.use(express.json());

app.post('/api/create-room', (req: Request, res: Response) => {
  const { isPublic, hostName = 'Host', format = '1v1', maxSeats, seatsUsed = 1 } = req.body;
  const code = generateRoomCode();
  const max = resolveMaxSeats(format, maxSeats);

  const room: Room = {
    code,
    hostName,
    isPublic: !!isPublic,
    players: Math.min(max, Math.max(1, Number(seatsUsed) || 1)),
    maxPlayers: max,
    format: format || '1v1',
    createdAt: Date.now(),
    lastHeartbeat: Date.now(),
    gameStarted: false,
  };

  rooms.set(code, room);
  res.json({ roomCode: code, format: room.format, maxPlayers: room.maxPlayers });
  console.log(`[HTTP] Room ${code} created (${room.format}, ${room.players}/${room.maxPlayers})`);
});

app.get('/api/list-rooms', (_req: Request, res: Response) => {
  const now = Date.now();
  const publicRooms = Array.from(rooms.values()).filter(r =>
    r.isPublic &&
    r.players < r.maxPlayers &&
    !r.gameStarted &&
    (now - r.lastHeartbeat) < 60000
  );
  res.json({ rooms: publicRooms });
});

app.post('/api/join-room', (req: Request, res: Response) => {
  const { roomCode, seats = 1 } = req.body;
  const room = rooms.get(String(roomCode || '').toUpperCase());
  const seatCount = Math.max(1, Math.min(2, Number(seats) || 1));

  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (room.players + seatCount > room.maxPlayers) {
    return res.status(400).json({ error: 'Room full' });
  }
  if (room.gameStarted) return res.status(400).json({ error: 'Game already in progress' });

  room.players = Math.min(room.maxPlayers, room.players + seatCount);
  room.lastHeartbeat = Date.now();

  res.json({ success: true, format: room.format, maxPlayers: room.maxPlayers });
});

app.post('/api/heartbeat', (req: Request, res: Response) => {
  const { roomCode, players } = req.body;
  const room = rooms.get(String(roomCode || '').toUpperCase());
  if (room) {
    room.lastHeartbeat = Date.now();
    if (typeof players === 'number' && players >= 0) {
      room.players = Math.min(room.maxPlayers, players);
    }
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Room not found' });
  }
});

app.listen(HTTP_PORT, () => {
  console.log(`[HTTP] Matchmaker listening on port ${HTTP_PORT}`);
});

// --- TCP Server (Real-time Relay) ---
// Capacity is per-console sockets; seat accounting is HTTP/lobby. Allow up to 4 consoles.
const MAX_SOCKETS_PER_ROOM = 4;

const tcpServer = net.createServer((socket: net.Socket) => {
  let currentRoomCode: string | null = null;
  let buffer = '';
  let cleanedUp = false;

  socket.on('data', (data: Buffer) => {
    buffer += data.toString();
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (line.startsWith('JOIN:')) {
        const code = line.split(':')[1].toUpperCase();
        currentRoomCode = code;

        const room = rooms.get(code);

        if (room && room.gameStarted) {
          socket.write('ERROR:Game already in progress\n');
          socket.end();
          continue;
        }

        let roomData = roomSockets.get(code);
        if (!roomData) {
          roomData = { sockets: [socket], gameStarted: false };
          roomSockets.set(code, roomData);
          console.log(`[TCP] Console joined room ${code} (1st)`);
        } else {
          if (roomData.sockets.length < MAX_SOCKETS_PER_ROOM) {
            roomData.sockets.push(socket);
            console.log(`[TCP] Console joined room ${code} (${roomData.sockets.length})`);
            // Notify all consoles someone joined (lobby sync handled by game protocol)
            roomData.sockets.forEach(s => s.write('PAIRED\n'));
          } else {
            socket.write('ERROR:Room full\n');
            socket.end();
          }
        }
        continue;
      }

      if (line.includes('|scd|') || line.startsWith('scd|')) {
        const roomData = roomSockets.get(currentRoomCode || '');
        const room = rooms.get(currentRoomCode || '');
        if (roomData) roomData.gameStarted = true;
        if (room) room.gameStarted = true;
        console.log(`[TCP] Game started in room ${currentRoomCode}`);
      }

      // Returning to lobby (rematch) clears the in-progress lock
      if (line.includes('|lobby|') || line.startsWith('lobby|')) {
        const roomData = roomSockets.get(currentRoomCode || '');
        const room = rooms.get(currentRoomCode || '');
        if (roomData) roomData.gameStarted = false;
        if (room) room.gameStarted = false;
      }

      if (currentRoomCode) {
        const roomData = roomSockets.get(currentRoomCode);
        if (roomData) {
          roomData.sockets.forEach(s => {
            if (s !== socket) s.write(line + '\n');
          });
        }
      }
    }
  });

  const cleanup = () => {
    if (cleanedUp) return;
    cleanedUp = true;

    if (currentRoomCode) {
      const roomData = roomSockets.get(currentRoomCode);
      if (roomData) {
        roomData.sockets = roomData.sockets.filter(s => s !== socket);
        const room = rooms.get(currentRoomCode);

        if (roomData.sockets.length === 0) {
          roomSockets.delete(currentRoomCode);
          rooms.delete(currentRoomCode);
          console.log(`[TCP] Room ${currentRoomCode} deleted (empty)`);
        } else {
          roomData.sockets.forEach(s => s.write('OPPONENT_LEFT\n'));
          console.log(`[TCP] Console left room ${currentRoomCode}, notified remaining`);

          if (roomData.gameStarted) {
            roomData.gameStarted = false;
            if (room) room.gameStarted = false;
          }
        }
      }
    }
  };

  socket.on('close', cleanup);
  socket.on('error', (err) => {
    console.log(`[TCP] Socket error: ${err.message}`);
    cleanup();
  });
});

tcpServer.listen(TCP_PORT, () => {
  console.log(`[TCP] Relay listening on port ${TCP_PORT}`);
});
