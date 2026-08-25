/** Test tích hợp end-to-end trên PGlite (Postgres-in-process). */
import { describe, it, expect, beforeAll } from 'vitest';
import { makeDb, setDb, getDb, type DB } from '../src/db/index.js';
import { ensureSchema } from '../src/db/ddl.js';
import { createApp } from '../src/app.js';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret';

let app: ReturnType<typeof createApp>;
let access = '';
let refresh = '';
let sid1 = '', sid2 = '', classId = '';

const j = (r: Response) => r.json() as Promise<any>;
const req = (path: string, init: RequestInit = {}, auth = true) =>
  app.request('/api/v1' + path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(auth && access ? { Authorization: `Bearer ${access}` } : {}),
      ...(init.headers ?? {}),
    },
  });

beforeAll(async () => {
  const db: DB = await makeDb('pglite:memory');
  await ensureSchema(db);
  setDb(db);
  app = createApp(getDb);
});

describe('auth', () => {
  it('đăng ký → nhận token', async () => {
    const r = await req('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email: 'Giasu@Example.com', password: 'matkhau123', name: 'Cô Tài' }),
    }, false);
    expect(r.status).toBe(201);
    const b = await j(r);
    expect(b.user.email).toBe('giasu@example.com');
    access = b.accessToken; refresh = b.refreshToken;
    expect(access.length).toBeGreaterThan(20);
  });

  it('trùng email → 409', async () => {
    const r = await req('/auth/register', {
      method: 'POST', body: JSON.stringify({ email: 'giasu@example.com', password: 'matkhau123' }),
    }, false);
    expect(r.status).toBe(409);
  });

  it('đăng nhập sai mật khẩu → 401', async () => {
    const r = await req('/auth/login', {
      method: 'POST', body: JSON.stringify({ email: 'giasu@example.com', password: 'saimatkhau' }),
    }, false);
    expect(r.status).toBe(401);
  });

  it('refresh xoay vòng: token mới dùng được, token cũ chết', async () => {
    const r1 = await req('/auth/refresh', { method: 'POST', body: JSON.stringify({ refreshToken: refresh }) }, false);
    expect(r1.status).toBe(200);
    const b1 = await j(r1);
    const oldRefresh = refresh;
    access = b1.accessToken; refresh = b1.refreshToken;
    const r2 = await req('/auth/refresh', { method: 'POST', body: JSON.stringify({ refreshToken: oldRefresh }) }, false);
    expect(r2.status).toBe(401);
  });

  it('không token → 401', async () => {
    const r = await app.request('/api/v1/students');
    expect(r.status).toBe(401);
  });
});

describe('học sinh & ca học', () => {
  it('tạo 2 học sinh (đơn giá 180k / 150k)', async () => {
    const mk = (name: string, rate: number) => req('/students', {
      method: 'POST', body: JSON.stringify({ name, rate, grade: '9A1', subject: 'Toán' }),
    });
    const b1 = await j(await mk('Nguyễn Minh Anh', 180000));
    const b2 = await j(await mk('Trần Gia Bảo', 150000));
    sid1 = b1.item.id; sid2 = b2.item.id;
    const list = await j(await req('/students'));
    expect(list.items.length).toBe(2);
  });

  it('sửa học sinh', async () => {
    const r = await req(`/students/${sid1}`, { method: 'PATCH', body: JSON.stringify({ rate: 200000 }) });
    expect((await j(r)).item.rate).toBe(200000);
  });

  it('tạo ca kèm gán học sinh', async () => {
    const r = await req('/classes', {
      method: 'POST',
      body: JSON.stringify({ name: 'Toán 9 – Nhóm tối', days: [1, 4], startTime: '18:00', endTime: '19:30', studentIds: [sid1, sid2] }),
    });
    const b = await j(r);
    classId = b.item.id;
    expect(b.item.studentIds.sort()).toEqual([sid1, sid2].sort());
  });
});

describe('điểm danh & học phí', () => {
  it('điểm danh 3 buổi (1 buổi vắng KP của Bảo)', async () => {
    const put = (date: string, records: any[]) => req(`/attendance/${date}/${classId}`, {
      method: 'PUT', body: JSON.stringify({ records }),
    });
    await put('2026-07-06', [
      { studentId: sid1, status: 'present' }, { studentId: sid2, status: 'present' }]);
    await put('2026-07-09', [
      { studentId: sid1, status: 'late' }, { studentId: sid2, status: 'absent' }]);
    const r = await put('2026-07-13', [
      { studentId: sid1, status: 'present' }, { studentId: sid2, status: 'excused' }]);
    expect(r.status).toBe(200);
    const list = await j(await req(`/attendance?from=2026-07-01&to=2026-07-31`));
    expect(list.items.length).toBe(3);
  });

  it('ghi đè một buổi không nhân đôi bản ghi', async () => {
    await req(`/attendance/2026-07-06/${classId}`, {
      method: 'PUT',
      body: JSON.stringify({ records: [{ studentId: sid1, status: 'present' }, { studentId: sid2, status: 'late' }] }),
    });
    const list = await j(await req(`/attendance?from=2026-07-06&to=2026-07-06`));
    expect(list.items.length).toBe(1);
    expect(list.items[0].records.length).toBe(2);
  });

  it('học phí tháng: Minh Anh 3 buổi × 200k, Bảo 2 buổi tính phí × 150k', async () => {
    const b = await j(await req('/stats/month/2026-07'));
    const anh = b.rows.find((x: any) => x.studentId === sid1);
    const bao = b.rows.find((x: any) => x.studentId === sid2);
    expect(anh.sessions).toBe(3);           // present + late + present
    expect(anh.fee).toBe(600000);
    expect(bao.sessions).toBe(1);           // late(6/7 sau ghi đè)… absent & excused không tính
    expect(bao.fee).toBe(150000);
    expect(b.totals.fee).toBe(750000);
  });

  it('bật tính phí vắng KP qua settings → phí của Bảo tăng', async () => {
    await req('/me', { method: 'PATCH', body: JSON.stringify({ settings: { chargeUnexcused: true } }) });
    const b = await j(await req('/stats/month/2026-07'));
    const bao = b.rows.find((x: any) => x.studentId === sid2);
    expect(bao.sessions).toBe(2);           // late + absent
    await req('/me', { method: 'PATCH', body: JSON.stringify({ settings: { chargeUnexcused: false } }) });
  });

  it('thu tiền một phần → remaining đúng', async () => {
    const r = await req('/payments', {
      method: 'POST',
      body: JSON.stringify({ studentId: sid1, month: '2026-07', amount: 400000, method: 'Tiền mặt' }),
    });
    expect(r.status).toBe(201);
    const b = await j(await req('/stats/month/2026-07'));
    const anh = b.rows.find((x: any) => x.studentId === sid1);
    expect(anh.paid).toBe(400000);
    expect(anh.remaining).toBe(200000);
  });

  it('lịch hôm nay đúng theo thứ', async () => {
    // 2026-07-06 là Thứ 2 (dow=1) — ca days [1,4] phải xuất hiện
    const b = await j(await req('/stats/today?date=2026-07-06'));
    expect(b.items.length).toBe(1);
    expect(b.items[0].attendanceTaken).toBe(true);
    const b2 = await j(await req('/stats/today?date=2026-07-07')); // Thứ 3 → không có ca
    expect(b2.items.length).toBe(0);
  });
});

describe('điểm & giáo án & xoá mềm', () => {
  it('thêm điểm 8.5', async () => {
    const r = await req('/scores', {
      method: 'POST', body: JSON.stringify({ studentId: sid1, score: 8.5, title: 'Thi thử', date: '2026-07-10' }),
    });
    expect(r.status).toBe(201);
  });
  it('điểm 11 → 400', async () => {
    const r = await req('/scores', { method: 'POST', body: JSON.stringify({ studentId: sid1, score: 11 }) });
    expect(r.status).toBe(400);
  });
  it('xoá mềm học sinh: biến khỏi list, còn khi all=1', async () => {
    const r = await req(`/students/${sid2}`, { method: 'DELETE' });
    expect(r.status).toBe(200);
    const list = await j(await req('/students'));
    expect(list.items.some((x: any) => x.id === sid2)).toBe(false);
    const all = await j(await req('/students?all=1'));
    expect(all.items.some((x: any) => x.id === sid2)).toBe(true);
  });
});

describe('sync offline-first', () => {
  it('pull với since cũ → có dữ liệu + serverTime', async () => {
    const b = await j(await req('/sync?since=2000-01-01T00:00:00.000Z'));
    expect(b.students.length).toBeGreaterThan(0);
    expect(typeof b.serverTime).toBe('string');
  });

  it('push bản ghi client mới (uuid tự sinh) → xuất hiện trên server', async () => {
    const cid = crypto.randomUUID();
    const r = await req('/sync', {
      method: 'POST',
      body: JSON.stringify({ students: [{
        id: cid, name: 'Em Offline', rate: 120000, updatedAt: new Date().toISOString(),
        grade: '', subject: '', parentName: '', parentPhone: '', phone: '', note: '', status: 'active', startDate: '', deleted: false,
      }] }),
    });
    const b = await j(r);
    expect(b.applied.students).toBe(1);
    const list = await j(await req('/students'));
    expect(list.items.some((x: any) => x.id === cid)).toBe(true);
  });

  it('LWW: bản cũ hơn không đè bản mới', async () => {
    const old = new Date(Date.now() - 3600_000).toISOString();
    await req('/sync', {
      method: 'POST',
      body: JSON.stringify({ students: [{ id: sid1, name: 'Tên Cũ Kỹ', updatedAt: old }] }),
    });
    const list = await j(await req('/students'));
    const anh = list.items.find((x: any) => x.id === sid1);
    expect(anh.name).toBe('Nguyễn Minh Anh');
  });
});

describe('quản trị', () => {
  let adminAccess = '';
  let teacherId = '';

  it('email trong ADMIN_EMAILS đăng ký → role admin', async () => {
    process.env.ADMIN_EMAILS = 'boss@tedu.app';
    const r = await req('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email: 'boss@tedu.app', password: 'matkhau123', name: 'Boss' }),
    }, false);
    const b = await j(r);
    expect(b.user.role).toBe('admin');
    adminAccess = b.accessToken;
  });

  it('giáo viên thường bị chặn /admin (403)', async () => {
    const r = await req('/admin/users');
    expect(r.status).toBe(403);
  });

  it('admin xem danh sách tài khoản kèm số học sinh', async () => {
    const r = await app.request('/api/v1/admin/users', {
      headers: { Authorization: `Bearer ${adminAccess}` },
    });
    expect(r.status).toBe(200);
    const b = await j(r);
    expect(b.items.length).toBeGreaterThanOrEqual(2);
    const t = b.items.find((x: any) => x.email === 'giasu@example.com');
    teacherId = t.id;
    expect(t.studentCount).toBeGreaterThan(0);
  });

  it('khoá tài khoản → đăng nhập 403 → mở khoá → đăng nhập OK', async () => {
    const block = await app.request(`/api/v1/admin/users/${teacherId}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminAccess}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'blocked' }),
    });
    expect(block.status).toBe(200);
    const login = await req('/auth/login', {
      method: 'POST', body: JSON.stringify({ email: 'giasu@example.com', password: 'matkhau123' }),
    }, false);
    expect(login.status).toBe(403);
    await app.request(`/api/v1/admin/users/${teacherId}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminAccess}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'active' }),
    });
    const again = await req('/auth/login', {
      method: 'POST', body: JSON.stringify({ email: 'giasu@example.com', password: 'matkhau123' }),
    }, false);
    expect(again.status).toBe(200);
  });

  it('admin không tự khoá được chính mình', async () => {
    const me = await j(await app.request('/api/v1/me', { headers: { Authorization: `Bearer ${adminAccess}` } }));
    const r = await app.request(`/api/v1/admin/users/${me.user.id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminAccess}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'blocked' }),
    });
    expect(r.status).toBe(400);
  });
});

describe('realtime & files', () => {
  it('notifyChanged đẩy tới đúng socket của user', async () => {
    const { registerClient, notifyChanged, unregisterClient } = await import('../src/realtime.js');
    const got: string[] = [];
    const fake = { send: (s: string) => got.push(s), readyState: 1 };
    registerClient('user-x', fake);
    expect(notifyChanged('user-x')).toBe(1);
    expect(notifyChanged('user-khac')).toBe(0);
    expect(JSON.parse(got[0]).type).toBe('changed');
    unregisterClient('user-x', fake);
    expect(notifyChanged('user-x')).toBe(0);
  });

  let fileId = '';
  it('upload file base64 → nhận metadata', async () => {
    const data = Buffer.from('Xin chào TEdu — nội dung file thử').toString('base64');
    const r = await req('/files', {
      method: 'POST',
      body: JSON.stringify({ name: 'giao-an-thu.txt', mime: 'text/plain', dataBase64: data }),
    });
    expect(r.status).toBe(201);
    const b = await j(r);
    fileId = b.item.id;
    expect(b.item.size).toBeGreaterThan(10);
  });

  it('list metadata không lộ data; tải về đúng nội dung', async () => {
    const list = await j(await req('/files'));
    const meta = list.items.find((x: any) => x.id === fileId);
    expect(meta.name).toBe('giao-an-thu.txt');
    expect(meta.dataBase64).toBeUndefined();
    const one = await j(await req(`/files/${fileId}`));
    const text = Buffer.from(one.item.dataBase64, 'base64').toString();
    expect(text).toContain('Xin chào TEdu');
  });

  it('xoá file', async () => {
    expect((await req(`/files/${fileId}`, { method: 'DELETE' })).status).toBe(200);
    expect((await req(`/files/${fileId}`)).status).toBe(404);
  });
});
