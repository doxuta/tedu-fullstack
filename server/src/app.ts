/** Lắp ráp ứng dụng Hono — tách khỏi index.ts để test được trực tiếp. */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { z } from 'zod';
import { eq } from 'drizzle-orm';
import type { DB } from './db/index.js';
import { schema } from './db/index.js';
import { ApiError, parseBody } from './lib/http.js';
import { authRoutes, requireAuth } from './auth/routes.js';
import { crudRoutes, idOpt, isoDate, isoMonth } from './modules/crud.js';
import { classRoutes } from './modules/classes.js';
import { attendanceRoutes } from './modules/attendance.js';
import { statsRoutes } from './modules/stats.js';
import { syncRoutes } from './modules/sync.js';
import { adminRoutes } from './modules/admin.js';
import { fileRoutes } from './modules/files.js';
import { notifyChanged } from './realtime.js';

export function createApp(getDb: () => Promise<DB>) {
  const app = new Hono<{ Variables: { userId: string; role: string } }>();

  app.use('*', cors({ origin: (o) => o ?? '*', allowHeaders: ['Content-Type', 'Authorization'] }));
  if (process.env.NODE_ENV !== 'test') app.use('*', logger());

  app.onError((err, c) => {
    if (err instanceof ApiError)
      return c.json({ error: { code: err.code, message: err.message } }, err.status as any);
    if (err instanceof z.ZodError)
      return c.json({ error: { code: 'bad_request', message: err.issues.map(i => i.message).join('; ') } }, 400);
    console.error(err);
    return c.json({ error: { code: 'internal', message: 'Lỗi máy chủ' } }, 500);
  });

  app.get('/health', (c) => c.json({ ok: true, name: 'tedu-server', time: new Date().toISOString() }));

  const v1 = new Hono<{ Variables: { userId: string; role: string } }>();
  v1.route('/auth', authRoutes(getDb));

  /* --- các route cần đăng nhập --- */
  v1.use('*', requireAuth());

  /* realtime: mutation thành công → báo mọi thiết bị của user */
  v1.use('*', async (c, next) => {
    await next();
    const m = c.req.method;
    if (m !== 'GET' && m !== 'OPTIONS' && c.res.status < 400) {
      try { notifyChanged(c.get('userId')); } catch { /* không chặn response */ }
    }
  });

  v1.get('/me', async (c) => {
    const db = await getDb();
    const [u] = await db.select().from(schema.users).where(eq(schema.users.id, c.get('userId'))).limit(1);
    return c.json({ user: { id: u.id, email: u.email, name: u.name, role: u.role, settings: u.settings } });
  });
  v1.patch('/me', async (c) => {
    const db = await getDb();
    const body = await parseBody(c, z.object({
      name: z.string().max(120).optional(),
      settings: z.record(z.unknown()).optional(),
    }));
    const [u] = await db.update(schema.users)
      .set({ ...(body.name !== undefined ? { name: body.name } : {}),
             ...(body.settings !== undefined ? { settings: body.settings } : {}),
             updatedAt: new Date() })
      .where(eq(schema.users.id, c.get('userId'))).returning();
    return c.json({ user: { id: u.id, email: u.email, name: u.name, role: u.role, settings: u.settings } });
  });

  /* Học sinh */
  const studentBase = {
    name: z.string().min(1).max(200),
    grade: z.string().max(200).default(''),
    subject: z.string().max(100).default(''),
    rate: z.number().int().min(0).default(0),
    parentName: z.string().max(200).default(''),
    parentPhone: z.string().max(30).default(''),
    phone: z.string().max(30).default(''),
    note: z.string().max(2000).default(''),
    status: z.enum(['active', 'paused', 'stopped']).default('active'),
    startDate: z.union([isoDate, z.literal('')]).default(''),
  };
  v1.route('/students', crudRoutes({
    getDb, table: schema.students,
    createSchema: z.object({ ...idOpt, ...studentBase }),
    updateSchema: z.object(studentBase).partial(),
  }));

  v1.route('/classes', classRoutes(getDb));
  v1.route('/attendance', attendanceRoutes(getDb));

  /* Thu học phí */
  const paymentBase = {
    studentId: z.string().uuid(),
    month: isoMonth,
    amount: z.number().int().positive(),
    paidAt: z.union([isoDate, z.literal('')]).default(''),
    method: z.string().max(50).default('Chuyển khoản'),
    note: z.string().max(500).default(''),
  };
  v1.route('/payments', crudRoutes({
    getDb, table: schema.payments,
    createSchema: z.object({ ...idOpt, ...paymentBase }),
    updateSchema: z.object(paymentBase).partial(),
  }));

  /* Điểm kiểm tra */
  const scoreBase = {
    studentId: z.string().uuid(),
    date: z.union([isoDate, z.literal('')]).default(''),
    title: z.string().max(200).default('Kiểm tra'),
    score: z.number().min(0).max(10),
    note: z.string().max(1000).default(''),
  };
  v1.route('/scores', crudRoutes({
    getDb, table: schema.scores,
    createSchema: z.object({ ...idOpt, ...scoreBase }),
    updateSchema: z.object(scoreBase).partial(),
  }));

  /* Giáo án */
  const lessonBase = {
    date: z.union([isoDate, z.literal('')]).default(''),
    classId: z.string().uuid().nullable().optional(),
    title: z.string().min(1).max(300),
    content: z.string().max(20000).default(''),
    homework: z.string().max(5000).default(''),
  };
  v1.route('/lessons', crudRoutes({
    getDb, table: schema.lessons,
    createSchema: z.object({ ...idOpt, ...lessonBase }),
    updateSchema: z.object(lessonBase).partial(),
  }));

  v1.route('/stats', statsRoutes(getDb));
  v1.route('/sync', syncRoutes(getDb));
  v1.route('/admin', adminRoutes(getDb));
  v1.route('/files', fileRoutes(getDb));

  app.route('/api/v1', v1);
  return app;
}
