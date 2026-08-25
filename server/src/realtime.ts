/**
 * Realtime — WebSocket /ws?token=<accessToken>
 * Mỗi mutation thành công đẩy {"type":"changed"} tới MỌI thiết bị của user đó
 * → thiết bị khác tự tải lại. Đơn giản, đủ dùng, không cần message phức tạp.
 */
import type { Server } from 'node:http';
import { verifyAccess } from './auth/jwt.js';

type Client = { send: (s: string) => void; readyState?: number };
const clients = new Map<string, Set<Client>>(); // userId -> sockets

export function registerClient(userId: string, ws: Client) {
  if (!clients.has(userId)) clients.set(userId, new Set());
  clients.get(userId)!.add(ws);
}
export function unregisterClient(userId: string, ws: Client) {
  clients.get(userId)?.delete(ws);
  if (clients.get(userId)?.size === 0) clients.delete(userId);
}
export function notifyChanged(userId: string, source = 'api') {
  const set = clients.get(userId);
  if (!set) return 0;
  const msg = JSON.stringify({ type: 'changed', source, at: new Date().toISOString() });
  let n = 0;
  for (const ws of set) {
    try { if (ws.readyState === undefined || ws.readyState === 1) { ws.send(msg); n++; } } catch { /* bỏ qua socket chết */ }
  }
  return n;
}
export function clientCount(userId: string) { return clients.get(userId)?.size ?? 0; }

/** Gắn WebSocketServer vào HTTP server (gọi từ index.ts, không chạy trong test). */
export async function attachWebSocket(server: Server) {
  const { WebSocketServer } = await import('ws');
  const wss = new WebSocketServer({ noServer: true });
  server.on('upgrade', async (req, socket, head) => {
    try {
      const url = new URL(req.url ?? '', 'http://x');
      if (url.pathname !== '/ws') { socket.destroy(); return; }
      const token = url.searchParams.get('token') ?? '';
      const payload = await verifyAccess(token);
      if (!payload) { socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n'); socket.destroy(); return; }
      wss.handleUpgrade(req, socket, head, (ws) => {
        registerClient(payload.sub, ws as unknown as Client);
        ws.on('close', () => unregisterClient(payload.sub, ws as unknown as Client));
        ws.send(JSON.stringify({ type: 'hello' }));
      });
    } catch { socket.destroy(); }
  });
  return wss;
}
