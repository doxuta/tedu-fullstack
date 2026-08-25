/** Điểm vào server — node/tsx. */
import 'dotenv/config';
import { serve } from '@hono/node-server';
import type { Server } from 'node:http';
import { createApp } from './app.js';
import { getDb } from './db/index.js';
import { ensureSchema } from './db/ddl.js';
import { attachWebSocket } from './realtime.js';

const db = await getDb();
await ensureSchema(db);

const app = createApp(getDb);
const port = Number(process.env.PORT ?? 8787);
const server = serve({ fetch: app.fetch, port, hostname: '0.0.0.0' }) as unknown as Server;
await attachWebSocket(server);
console.log(`✳ TEdu server chạy tại http://localhost:${port}  (API /api/v1 · WS /ws · health /health)`);
