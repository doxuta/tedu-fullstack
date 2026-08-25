/**
 * Thống kê — trái tim nghiệp vụ của TEdu:
 * học phí tháng = số buổi tính phí (present + late [+ absent nếu bật]) × đơn giá từng em.
 */
import { Hono } from 'hono';
import { and, eq, gte, lte, inArray } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { isoMonth } from './crud.js';

function billableStatuses(chargeUnexcused: boolean) {
  return chargeUnexcused ? ['present', 'late', 'absent'] : ['present', 'late'];
}

export function statsRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string } }>();

  // GET /stats/month/:ym — bảng học phí tháng
  r.get('/month/:ym', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const ym = isoMonth.parse(c.req.param('ym'));

    const [user] = await db.select().from(schema.users).where(eq(schema.users.id, uid)).limit(1);
    const chargeUnexcused = Boolean((user?.settings as any)?.chargeUnexcused);
    const billable = billableStatuses(chargeUnexcused);

    const studentsRows = await db.select().from(schema.students)
      .where(and(eq(schema.students.userId, uid), eq(schema.students.deleted, false)));

    const atts = await db.select().from(schema.attendance).where(and(
      eq(schema.attendance.userId, uid),
      eq(schema.attendance.deleted, false),
      gte(schema.attendance.date, `${ym}-01`),
      lte(schema.attendance.date, `${ym}-31`),
    ));
    const recs = atts.length
      ? await db.select().from(schema.attendanceRecords)
          .where(inArray(schema.attendanceRecords.attendanceId, atts.map(a => a.id)))
      : [];

    const pays = await db.select().from(schema.payments).where(and(
      eq(schema.payments.userId, uid),
      eq(schema.payments.deleted, false),
      eq(schema.payments.month, ym),
    ));

    const rows = studentsRows.map(s => {
      const sessions = recs.filter(rc => rc.studentId === s.id && billable.includes(rc.status)).length;
      const fee = sessions * s.rate;
      const paid = pays.filter(p => p.studentId === s.id).reduce((t, p) => t + p.amount, 0);
      return { studentId: s.id, name: s.name, rate: s.rate, sessions, fee, paid, remaining: fee - paid };
    });

    const totals = rows.reduce((t, x) => ({
      sessions: t.sessions + x.sessions, fee: t.fee + x.fee,
      paid: t.paid + x.paid, remaining: t.remaining + x.remaining,
    }), { sessions: 0, fee: 0, paid: 0, remaining: 0 });

    return c.json({ month: ym, chargeUnexcused, rows, totals });
  });

  // GET /stats/today?date=YYYY-MM-DD — các ca dạy trong ngày (mặc định hôm nay)
  r.get('/today', async (c) => {
    const db = await getDb(); const uid = c.get('userId');
    const date = c.req.query('date') ?? new Date().toISOString().slice(0, 10);
    const dow = new Date(date + 'T00:00:00Z').getUTCDay(); // 0=CN … 6=T7

    const classesRows = await db.select().from(schema.classes)
      .where(and(eq(schema.classes.userId, uid), eq(schema.classes.deleted, false)));
    const links = await db.select().from(schema.classStudents)
      .where(eq(schema.classStudents.userId, uid));
    const atts = await db.select().from(schema.attendance).where(and(
      eq(schema.attendance.userId, uid),
      eq(schema.attendance.date, date),
      eq(schema.attendance.deleted, false),
    ));

    const items = classesRows
      .filter(cl => Array.isArray(cl.days) && (cl.days as number[]).includes(dow))
      .filter(cl => (!cl.startDate || cl.startDate <= date) && (!cl.endDate || date <= cl.endDate))
      .sort((a, b) => a.startTime.localeCompare(b.startTime))
      .map(cl => ({
        classId: cl.id, name: cl.name, subject: cl.subject,
        startTime: cl.startTime, endTime: cl.endTime, color: cl.color,
        studentCount: links.filter(l => l.classId === cl.id).length,
        attendanceTaken: atts.some(a => a.classId === cl.id),
      }));

    return c.json({ date, items });
  });

  return r;
}
