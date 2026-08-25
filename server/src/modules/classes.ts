/** Ca học — CRUD + gán học sinh vào ca. */
import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, inArray } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody, notFound } from '../lib/http.js';
import { hhmm, isoDate } from './crud.js';

const base = {
  name: z.string().min(1).max(200),
  subject: z.string().max(100).default(''),
  days: z.array(z.number().int().min(0).max(6)).min(1, 'Chọn ít nhất 1 thứ trong tuần'),
  startTime: hhmm.default('18:00'),
  endTime: hhmm.default('19:30'),
  color: z.string().max(20).default('#2F5D50'),
  startDate: z.union([isoDate, z.literal('')]).default(''),
  endDate: z.union([isoDate, z.literal('')]).default(''),
  studentIds: z.array(z.string().uuid()).default([]),
};
const createSchema = z.object({ id: z.string().uuid().optional(), ...base });
const updateSchema = z.object(base).partial();

async function withStudents(db: DB, uid: string, rows: (typeof schema.classes.$inferSelect)[]) {
  if (!rows.length) return [];
  const links = await db.select().from(schema.classStudents)
    .where(and(eq(schema.classStudents.userId, uid),
      inArray(schema.classStudents.classId, rows.map(r => r.id))));
  return rows.map(r => ({ ...r, studentIds: links.filter(l => l.classId === r.id).map(l => l.studentId) }));
}

async function setStudents(db: DB, uid: string, classId: string, studentIds: string[]) {
  await db.delete(schema.classStudents)
    .where(and(eq(schema.classStudents.userId, uid), eq(schema.classStudents.classId, classId)));
  if (studentIds.length) {
    const owned = await db.select({ id: schema.students.id }).from(schema.students)
      .where(and(eq(schema.students.userId, uid), inArray(schema.students.id, studentIds)));
    if (owned.length) {
      await db.insert(schema.classStudents)
        .values(owned.map(s => ({ userId: uid, classId, studentId: s.id })))
        .onConflictDoNothing();
    }
  }
}

export function classRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string } }>();

  r.get('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const rows = await db.select().from(schema.classes)
      .where(and(eq(schema.classes.userId, uid), eq(schema.classes.deleted, false)));
    return c.json({ items: await withStudents(db, uid, rows) });
  });

  r.post('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const { studentIds, ...body } = await parseBody(c, createSchema);
    const [row] = await db.insert(schema.classes)
      .values({ ...body, userId: uid, updatedAt: new Date() })
      .onConflictDoUpdate({ target: schema.classes.id, set: { ...body, updatedAt: new Date() } })
      .returning();
    await setStudents(db, uid, row.id, studentIds);
    return c.json({ item: (await withStudents(db, uid, [row]))[0] }, 201);
  });

  r.patch('/:id', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const { studentIds, ...body } = await parseBody(c, updateSchema);
    const [row] = await db.update(schema.classes)
      .set({ ...body, updatedAt: new Date() })
      .where(and(eq(schema.classes.id, c.req.param('id')), eq(schema.classes.userId, uid)))
      .returning();
    if (!row) throw notFound();
    if (studentIds) await setStudents(db, uid, row.id, studentIds);
    return c.json({ item: (await withStudents(db, uid, [row]))[0] });
  });

  r.delete('/:id', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const [row] = await db.update(schema.classes)
      .set({ deleted: true, updatedAt: new Date() })
      .where(and(eq(schema.classes.id, c.req.param('id')), eq(schema.classes.userId, uid)))
      .returning();
    if (!row) throw notFound();
    return c.json({ ok: true });
  });

  return r;
}
