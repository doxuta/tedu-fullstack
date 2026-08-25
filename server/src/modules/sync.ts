/**
 * Đồng bộ offline-first:
 *  GET  /sync?since=ISO   → mọi bản ghi đổi sau `since` (kể cả deleted) + serverTime
 *  POST /sync             → đẩy thay đổi cục bộ; giải quyết xung đột Last-Write-Wins theo updatedAt
 */
import { Hono } from 'hono';
import { z } from 'zod';
import { and, eq, gt, inArray } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody } from '../lib/http.js';

const upstreamRow = z.object({ id: z.string().uuid(), updatedAt: z.string().datetime({ offset: true }).or(z.string().datetime()) }).passthrough();
const pushSchema = z.object({
  students: z.array(upstreamRow).default([]),
  classes: z.array(upstreamRow).default([]),
  payments: z.array(upstreamRow).default([]),
  scores: z.array(upstreamRow).default([]),
  lessons: z.array(upstreamRow).default([]),
});

const SYNC_TABLES = {
  students: { table: schema.students, cols: ['name','grade','subject','rate','parentName','parentPhone','phone','note','status','startDate','deleted'] },
  classes: { table: schema.classes, cols: ['name','subject','days','startTime','endTime','color','startDate','endDate','deleted'] },
  payments: { table: schema.payments, cols: ['studentId','month','amount','paidAt','method','note','deleted'] },
  scores: { table: schema.scores, cols: ['studentId','date','title','score','note','deleted'] },
  lessons: { table: schema.lessons, cols: ['date','classId','title','content','homework','deleted'] },
} as const;

export function syncRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string } }>();

  r.get('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const since = c.req.query('since');
    const sinceDate = since ? new Date(since) : new Date(0);
    const out: Record<string, unknown> = { serverTime: new Date().toISOString() };

    for (const [key, def] of Object.entries(SYNC_TABLES)) {
      out[key] = await db.select().from(def.table as any)
        .where(and(eq((def.table as any).userId, uid), gt((def.table as any).updatedAt, sinceDate)));
    }
    // attendance + records + liên kết ca-học sinh gửi trọn (thay đổi sau since)
    const atts = await db.select().from(schema.attendance)
      .where(and(eq(schema.attendance.userId, uid), gt(schema.attendance.updatedAt, sinceDate)));
    const recs = atts.length ? await db.select().from(schema.attendanceRecords)
      .where(inArray(schema.attendanceRecords.attendanceId, atts.map(a => a.id))) : [];
    out.attendance = atts.map(a => ({
      ...a, records: recs.filter(x => x.attendanceId === a.id).map(({ attendanceId: _i, ...rest }) => rest),
    }));
    out.classStudents = await db.select().from(schema.classStudents)
      .where(eq(schema.classStudents.userId, uid));
    return c.json(out);
  });

  r.post('/', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const body = await parseBody(c, pushSchema);
    const applied: Record<string, number> = {};

    for (const [key, def] of Object.entries(SYNC_TABLES)) {
      const incoming = (body as any)[key] as Array<Record<string, unknown>>;
      let n = 0;
      for (const row of incoming) {
        const clientAt = new Date(String(row.updatedAt));
        const t: any = def.table;
        const [existing] = await db.select().from(t)
          .where(and(eq(t.id, String(row.id)), eq(t.userId, uid))).limit(1);
        const patch: Record<string, unknown> = {};
        for (const col of def.cols) if (col in row) patch[col] = (row as any)[col];
        if (!existing) {
          await db.insert(t).values({ ...patch, id: row.id, userId: uid, updatedAt: clientAt });
          n++;
        } else if (existing.updatedAt.getTime() < clientAt.getTime()) {
          await db.update(t).set({ ...patch, updatedAt: clientAt })
            .where(and(eq(t.id, String(row.id)), eq(t.userId, uid)));
          n++;
        } // ngược lại: bản trên server mới hơn → giữ server (LWW)
      }
      applied[key] = n;
    }
    return c.json({ ok: true, applied, serverTime: new Date().toISOString() });
  });

  return r;
}
