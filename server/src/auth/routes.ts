/** /api/v1/auth — đăng ký, đăng nhập, refresh xoay vòng, đăng xuất. */
import { Hono } from 'hono';
import { z } from 'zod';
import { eq, and, isNull } from 'drizzle-orm';
import type { DB } from '../db/index.js';
import { schema } from '../db/index.js';
import { parseBody, badRequest, unauthorized, conflict, forbidden } from '../lib/http.js';
import { hashPassword, verifyPassword } from './password.js';
import { isAdminEmail } from '../modules/admin.js';
import { signAccess, newRefreshToken, hashToken, ACCESS_TTL_S } from './jwt.js';

const credsSchema = z.object({
  email: z.string().email('Email không hợp lệ').transform(s => s.trim().toLowerCase()),
  password: z.string().min(8, 'Mật khẩu tối thiểu 8 ký tự').max(200),
  name: z.string().max(120).optional(),
});

async function issueTokens(db: DB, userId: string, role: string) {
  const rt = newRefreshToken();
  await db.insert(schema.refreshTokens).values({ userId, tokenHash: rt.hash, expiresAt: rt.expiresAt });
  return {
    accessToken: await signAccess(userId, role),
    accessExpiresIn: ACCESS_TTL_S,
    refreshToken: rt.token,
  };
}

function publicUser(u: typeof schema.users.$inferSelect) {
  return { id: u.id, email: u.email, name: u.name, role: u.role, settings: u.settings };
}

export function authRoutes(getDb: () => Promise<DB>) {
  const r = new Hono();

  r.post('/register', async (c) => {
    const db = await getDb();
    const body = await parseBody(c, credsSchema);
    const existed = await db.select().from(schema.users).where(eq(schema.users.email, body.email)).limit(1);
    if (existed.length) throw conflict('Email này đã đăng ký — hãy đăng nhập');
    const [user] = await db.insert(schema.users).values({
      email: body.email,
      name: body.name ?? body.email.split('@')[0],
      passHash: await hashPassword(body.password),
      role: isAdminEmail(body.email) ? 'admin' : 'teacher',
    }).returning();
    const tokens = await issueTokens(db, user.id, user.role);
    return c.json({ user: publicUser(user), ...tokens }, 201);
  });

  r.post('/login', async (c) => {
    const db = await getDb();
    const body = await parseBody(c, credsSchema.pick({ email: true, password: true }));
    const [user] = await db.select().from(schema.users).where(eq(schema.users.email, body.email)).limit(1);
    if (!user || !(await verifyPassword(body.password, user.passHash)))
      throw unauthorized('Email hoặc mật khẩu không đúng');
    if (user.status === 'blocked') throw forbidden('Tài khoản đã bị quản trị viên tạm khoá');
    if (isAdminEmail(user.email) && user.role !== 'admin') {
      const [up] = await db.update(schema.users).set({ role: 'admin', updatedAt: new Date() })
        .where(eq(schema.users.id, user.id)).returning();
      const tokens = await issueTokens(db, up.id, up.role);
      return c.json({ user: publicUser(up), ...tokens });
    }
    const tokens = await issueTokens(db, user.id, user.role);
    return c.json({ user: publicUser(user), ...tokens });
  });

  r.post('/refresh', async (c) => {
    const db = await getDb();
    const { refreshToken } = await parseBody(c, z.object({ refreshToken: z.string().min(10) }));
    const h = hashToken(refreshToken);
    const [row] = await db.select().from(schema.refreshTokens)
      .where(and(eq(schema.refreshTokens.tokenHash, h), isNull(schema.refreshTokens.revokedAt))).limit(1);
    if (!row || row.expiresAt.getTime() < Date.now()) throw unauthorized('Phiên hết hạn — đăng nhập lại nhé');
    const [user] = await db.select().from(schema.users).where(eq(schema.users.id, row.userId)).limit(1);
    if (!user) throw unauthorized();
    if (user.status === 'blocked') throw forbidden('Tài khoản đã bị quản trị viên tạm khoá');
    // Xoay vòng: thu hồi token cũ, phát token mới
    await db.update(schema.refreshTokens).set({ revokedAt: new Date() }).where(eq(schema.refreshTokens.id, row.id));
    const tokens = await issueTokens(db, user.id, user.role);
    return c.json({ user: publicUser(user), ...tokens });
  });

  r.post('/logout', async (c) => {
    const db = await getDb();
    const { refreshToken } = await parseBody(c, z.object({ refreshToken: z.string().min(10) }));
    await db.update(schema.refreshTokens).set({ revokedAt: new Date() })
      .where(eq(schema.refreshTokens.tokenHash, hashToken(refreshToken)));
    return c.json({ ok: true });
  });

  return r;
}

export function requireAuth() {
  return async (c: any, next: any) => {
    const h = c.req.header('authorization') ?? '';
    const token = h.startsWith('Bearer ') ? h.slice(7) : '';
    if (!token) throw unauthorized();
    const { verifyAccess } = await import('./jwt.js');
    const payload = await verifyAccess(token);
    if (!payload) throw unauthorized();
    c.set('userId', payload.sub);
    c.set('role', payload.role);
    await next();
  };
}
