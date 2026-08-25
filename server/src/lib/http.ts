/** Tiện ích HTTP: lỗi chuẩn hoá + validate zod. */
import type { Context } from 'hono';
import { z, ZodSchema } from 'zod';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
export const badRequest = (m: string) => new ApiError(400, 'bad_request', m);
export const unauthorized = (m = 'Chưa đăng nhập hoặc phiên hết hạn') => new ApiError(401, 'unauthorized', m);
export const forbidden = (m = 'Không có quyền') => new ApiError(403, 'forbidden', m);
export const notFound = (m = 'Không tìm thấy') => new ApiError(404, 'not_found', m);
export const conflict = (m: string) => new ApiError(409, 'conflict', m);

export async function parseBody<T extends ZodSchema>(c: Context, schema: T): Promise<z.infer<T>> {
  let raw: unknown;
  try { raw = await c.req.json(); } catch { throw badRequest('Body phải là JSON'); }
  const r = schema.safeParse(raw);
  if (!r.success) {
    const msg = r.error.issues.map(i => `${i.path.join('.') || '(root)'}: ${i.message}`).join('; ');
    throw badRequest(msg);
  }
  return r.data;
}
