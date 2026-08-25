/** Access token (JWT HS256, 15 phút) + refresh token (chuỗi ngẫu nhiên, 30 ngày, xoay vòng). */
import { SignJWT, jwtVerify } from 'jose';
import { createHash, randomBytes } from 'node:crypto';

const secret = () => new TextEncoder().encode(process.env.JWT_SECRET || 'tedu-dev-secret-change-me');

export const ACCESS_TTL_S = 15 * 60;
export const REFRESH_TTL_S = 30 * 24 * 60 * 60;

export async function signAccess(userId: string, role: string): Promise<string> {
  return new SignJWT({ sub: userId, role })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(Math.floor(Date.now() / 1000) + ACCESS_TTL_S)
    .sign(secret());
}

export async function verifyAccess(token: string): Promise<{ sub: string; role: string } | null> {
  try {
    const { payload } = await jwtVerify(token, secret());
    if (typeof payload.sub !== 'string') return null;
    return { sub: payload.sub, role: String(payload.role ?? 'teacher') };
  } catch { return null; }
}

export function newRefreshToken(): { token: string; hash: string; expiresAt: Date } {
  const token = randomBytes(48).toString('base64url');
  return { token, hash: hashToken(token), expiresAt: new Date(Date.now() + REFRESH_TTL_S * 1000) };
}
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
