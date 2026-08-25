/**
 * Kết nối DB — tự chọn driver:
 *  - DATABASE_URL dạng postgres://…  → postgres-js (Postgres thật / Neon)
 *  - DATABASE_URL = "pglite:<đường-dẫn|memory>" → PGlite (dev nhanh / test)
 */
import { drizzle as drizzlePg } from 'drizzle-orm/postgres-js';
import { drizzle as drizzlePglite } from 'drizzle-orm/pglite';
import * as schema from './schema.js';

export type DB = ReturnType<typeof drizzlePg<typeof schema>> | ReturnType<typeof drizzlePglite<typeof schema>>;

let _db: DB | null = null;

export async function makeDb(url: string): Promise<DB> {
  if (url.startsWith('pglite:')) {
    const target = url.slice('pglite:'.length) || 'memory://';
    const { PGlite } = await import('@electric-sql/pglite');
    const client = new PGlite(target === 'memory' ? 'memory://' : target);
    return drizzlePglite(client, { schema });
  }
  const { default: postgres } = await import('postgres');
  const client = postgres(url, { max: 10, onnotice: () => {} });
  return drizzlePg(client, { schema });
}

export async function getDb(): Promise<DB> {
  if (_db) return _db;
  const url = process.env.DATABASE_URL ?? 'postgres://tedu:tedu_dev_password@localhost:5433/tedu';
  _db = await makeDb(url);
  return _db;
}

export function setDb(db: DB) { _db = db; }
export { schema };
