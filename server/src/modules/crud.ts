/**
 * CRUD chung cho các bảng nghiệp vụ đơn giản (students, payments, scores, lessons).
 * - Client ĐƯỢC PHÉP gửi id (uuid tự sinh phía app) → phục vụ offline-first.
 * - DELETE là xoá mềm (deleted=true) để còn đồng bộ xuống các máy khác.
 */
import { Hono } from 'hono';
import { z, ZodSchema } from 'zod';
import { and, eq } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { parseBody, notFound } from '../lib/http.js';

type AnyPgTable = any;

export function crudRoutes(opts: {
  getDb: () => Promise<DB>;
  table: AnyPgTable;
  createSchema: ZodSchema;
  updateSchema: ZodSchema;
}) {
  const { getDb, table, createSchema, updateSchema } = opts;
  const r = new Hono<{ Variables: { userId: string } }>();

  r.get('/', async (c) => {
    const db = await getDb();
    const includeDeleted = c.req.query('all') === '1';
    const uid = c.get('userId');
    const rows = includeDeleted
      ? await db.select().from(table).where(eq(table.userId, uid))
      : await db.select().from(table).where(and(eq(table.userId, uid), eq(table.deleted, false)));
    return c.json({ items: rows });
  });

  r.post('/', async (c) => {
    const db = await getDb();
    const body: any = await parseBody(c, createSchema);
    const values = { ...body, userId: c.get('userId'), updatedAt: new Date() };
    const rows = (await db.insert(table).values(values)
      .onConflictDoUpdate({ target: table.id, set: { ...body, updatedAt: new Date() } })
      .returning()) as unknown as any[];
    const row = rows[0];
    return c.json({ item: row }, 201);
  });

  r.patch('/:id', async (c) => {
    const db = await getDb();
    const body: any = await parseBody(c, updateSchema);
    const [row] = await db.update(table)
      .set({ ...body, updatedAt: new Date() })
      .where(and(eq(table.id, c.req.param('id')), eq(table.userId, c.get('userId'))))
      .returning();
    if (!row) throw notFound();
    return c.json({ item: row });
  });

  r.delete('/:id', async (c) => {
    const db = await getDb();
    const [row] = await db.update(table)
      .set({ deleted: true, updatedAt: new Date() })
      .where(and(eq(table.id, c.req.param('id')), eq(table.userId, c.get('userId'))))
      .returning();
    if (!row) throw notFound();
    return c.json({ ok: true });
  });

  return r;
}

/* ---------- Zod schemas dùng chung ---------- */
export const idOpt = { id: z.string().uuid().optional() };
export const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Ngày dạng YYYY-MM-DD');
export const isoMonth = z.string().regex(/^\d{4}-\d{2}$/, 'Tháng dạng YYYY-MM');
export const hhmm = z.string().regex(/^\d{2}:\d{2}$/, 'Giờ dạng HH:MM');
