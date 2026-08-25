/** Điểm danh — upsert nguyên buổi (date + classId), truy vấn theo khoảng ngày / theo ca. */
import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, gte, lte, inArray } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody, notFound } from '../lib/http.js';
import { isoDate } from './crud.js';

const recordSchema = z.object({
  studentId: z.string().uuid(),
  status: z.enum(['present', 'late', 'excused', 'absent']),
  note: z.string().max(500).default(''),
});
const putSchema = z.object({
  records: z.array(recordSchema),
  note: z.string().max(1000).default(''),
});

async function withRecords(db: DB, rows: (typeof schema.attendance.$inferSelect)[]) {
  if (!rows.length) return [];
  const recs = await db.select().from(schema.attendanceRecords)
    .where(inArray(schema.attendanceRecords.attendanceId, rows.map(r => r.id)));
  return rows.map(r => ({
    ...r,
    records: recs.filter(x => x.attendanceId === r.id)
      .map(({ attendanceId: _a, ...rest }) => rest),
  }));
}

export function attendanceRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string } }>();

  // GET /attendance?from=&to=&classId=
  r.get('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const conds = [eq(schema.attendance.userId, uid), eq(schema.attendance.deleted, false)];
    const { from, to, classId } = c.req.query();
    if (from) conds.push(gte(schema.attendance.date, from));
    if (to) conds.push(lte(schema.attendance.date, to));
    if (classId) conds.push(eq(schema.attendance.classId, classId));
    const rows = await db.select().from(schema.attendance).where(and(...conds));
    return c.json({ items: await withRecords(db, rows) });
  });

  // PUT /attendance/:date/:classId — ghi đè nguyên buổi
  r.put('/:date/:classId', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const date = isoDate.parse(c.req.param('date'));
    const classId = c.req.param('classId');
    const body = await parseBody(c, putSchema);

    const [cls] = await db.select().from(schema.classes)
      .where(and(eq(schema.classes.id, classId), eq(schema.classes.userId, uid))).limit(1);
    if (!cls) throw notFound('Không tìm thấy ca học');

    const [existing] = await db.select().from(schema.attendance).where(and(
      eq(schema.attendance.userId, uid),
      eq(schema.attendance.date, date),
      eq(schema.attendance.classId, classId),
    )).limit(1);

    let att;
    if (existing) {
      [att] = await db.update(schema.attendance)
        .set({ note: body.note, deleted: false, updatedAt: new Date() })
        .where(eq(schema.attendance.id, existing.id)).returning();
      await db.delete(schema.attendanceRecords)
        .where(eq(schema.attendanceRecords.attendanceId, existing.id));
    } else {
      [att] = await db.insert(schema.attendance)
        .values({ userId: uid, date, classId, note: body.note, updatedAt: new Date() }).returning();
    }
    if (body.records.length) {
      await db.insert(schema.attendanceRecords).values(
        body.records.map(rec => ({ attendanceId: att.id, ...rec })),
      );
    }
    return c.json({ item: (await withRecords(db, [att]))[0] });
  });

  // DELETE /attendance/:date/:classId — huỷ buổi (xoá mềm)
  r.delete('/:date/:classId', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const [row] = await db.update(schema.attendance)
      .set({ deleted: true, updatedAt: new Date() })
      .where(and(
        eq(schema.attendance.userId, uid),
        eq(schema.attendance.date, c.req.param('date')),
        eq(schema.attendance.classId, c.req.param('classId')),
      )).returning();
    if (!row) throw notFound();
    return c.json({ ok: true });
  });

  return r;
}
