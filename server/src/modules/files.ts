/**
 * File đính kèm giáo án — lưu ngay trong PostgreSQL (base64).
 * Quy mô gia sư (PDF/ảnh vài MB) thì Postgres dư sức, khỏi cần S3.
 */
import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody, notFound, badRequest } from '../lib/http.js';

const MAX_BYTES = 15 * 1024 * 1024; // 15MB

const uploadSchema = z.object({
  id: z.string().uuid().optional(),
  lessonId: z.string().uuid().nullable().optional(),
  name: z.string().min(1).max(300),
  mime: z.string().max(120).default('application/octet-stream'),
  dataBase64: z.string().min(1),
});

export function fileRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string } }>();

  // metadata list — ?lessonId= để lấy file của một giáo án
  r.get('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const conds = [eq(schema.files.userId, uid)];
    const lessonId = c.req.query('lessonId');
    if (lessonId) conds.push(eq(schema.files.lessonId, lessonId));
    const rows = await db.select({
      id: schema.files.id, lessonId: schema.files.lessonId, name: schema.files.name,
      mime: schema.files.mime, size: schema.files.size, createdAt: schema.files.createdAt,
    }).from(schema.files).where(and(...conds));
    return c.json({ items: rows });
  });

  r.post('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const body = await parseBody(c, uploadSchema);
    const size = Math.floor(body.dataBase64.length * 3 / 4);
    if (size > MAX_BYTES) throw badRequest('File quá lớn (tối đa 15MB)');
    const [row] = await db.insert(schema.files).values({
      ...(body.id ? { id: body.id } : {}),
      userId: uid, lessonId: body.lessonId ?? null,
      name: body.name, mime: body.mime, size, data: body.dataBase64,
    }).returning();
    return c.json({ item: { id: row.id, name: row.name, size: row.size, lessonId: row.lessonId } }, 201);
  });

  r.get('/:id', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const [row] = await db.select().from(schema.files)
      .where(and(eq(schema.files.id, c.req.param('id')), eq(schema.files.userId, uid))).limit(1);
    if (!row) throw notFound('Không tìm thấy file');
    return c.json({ item: { id: row.id, name: row.name, mime: row.mime, size: row.size, dataBase64: row.data } });
  });

  r.delete('/:id', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const rows = await db.delete(schema.files)
      .where(and(eq(schema.files.id, c.req.param('id')), eq(schema.files.userId, uid)))
      .returning();
    if (!rows.length) throw notFound('Không tìm thấy file');
    return c.json({ ok: true });
  });

  return r;
}
