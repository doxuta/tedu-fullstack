/** Quản trị hệ thống — chỉ role=admin: xem tài khoản, khoá/mở khoá. */
import { Hono } from 'hono';
import { z } from 'zod';
import { eq, sql } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody, forbidden, notFound, badRequest } from '../lib/http.js';

export function isAdminEmail(email: string): boolean {
  return (process.env.ADMIN_EMAILS ?? '')
    .split(',').map(s => s.trim().toLowerCase()).filter(Boolean)
    .includes(email.toLowerCase());
}

function requireAdmin() {
  return async (c: any, next: any) => {
    if (c.get('role') !== 'admin') throw forbidden('Chỉ quản trị viên mới vào được');
    await next();
  };
}

export function adminRoutes(getDb: () => Promise<DB>) {
  const r = new Hono<{ Variables: { userId: string; role: string } }>();
  r.use('*', requireAdmin());

  r.get('/users', async (c) => {
    const db = await getDb();
    const users = await db.select({
      id: schema.users.id, email: schema.users.email, name: schema.users.name,
      role: schema.users.role, status: schema.users.status, createdAt: schema.users.createdAt,
    }).from(schema.users);
    const counts = await db.select({
      userId: schema.students.userId,
      n: sql<number>`count(*)`.as('n'),
    }).from(schema.students).where(eq(schema.students.deleted, false)).groupBy(schema.students.userId);
    const map = new Map(counts.map(x => [x.userId, Number(x.n)]));
    return c.json({ items: users.map(u => ({ ...u, studentCount: map.get(u.id) ?? 0 })) });
  });

  r.patch('/users/:id', async (c) => {
    const db = await getDb();
    const { status } = await parseBody(c, z.object({ status: z.enum(['active', 'blocked']) }));
    if (c.req.param('id') === c.get('userId') && status === 'blocked')
      throw badRequest('Không thể tự khoá chính mình');
    const [u] = await db.update(schema.users)
      .set({ status, updatedAt: new Date() })
      .where(eq(schema.users.id, c.req.param('id'))).returning();
    if (!u) throw notFound('Không tìm thấy tài khoản');
    return c.json({ item: { id: u.id, email: u.email, status: u.status } });
  });

  return r;
}
