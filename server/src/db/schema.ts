/**
 * TEdu — lược đồ cơ sở dữ liệu (Drizzle ORM · PostgreSQL)
 * Mọi bảng dữ liệu nghiệp vụ đều: thuộc về một user (gia sư),
 * xoá mềm (deleted) và mang updatedAt phục vụ đồng bộ offline-first.
 */
import {
  pgTable, uuid, text, integer, real, boolean, timestamp, jsonb,
  primaryKey, uniqueIndex, index,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

/* ---------- Tài khoản ---------- */
export const users = pgTable('users', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  email: text('email').notNull(),
  name: text('name').notNull().default(''),
  passHash: text('pass_hash').notNull(),
  role: text('role').notNull().default('teacher'),      // teacher | admin
  status: text('status').notNull().default('active'),   // active | blocked
  settings: jsonb('settings').notNull().default(sql`'{}'::jsonb`),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [uniqueIndex('users_email_uq').on(t.email)]);

export const refreshTokens = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('refresh_user_idx').on(t.userId)]);

/* ---------- Học sinh ---------- */
export const students = pgTable('students', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  name: text('name').notNull(),
  grade: text('grade').notNull().default(''),        // "9A1 – THCS Lê Quý Đôn"
  subject: text('subject').notNull().default(''),
  rate: integer('rate').notNull().default(0),        // đ / buổi
  parentName: text('parent_name').notNull().default(''),
  parentPhone: text('parent_phone').notNull().default(''),
  phone: text('phone').notNull().default(''),
  note: text('note').notNull().default(''),
  status: text('status').notNull().default('active'), // active | paused | stopped
  startDate: text('start_date').notNull().default(''), // ISO yyyy-mm-dd
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('students_user_idx').on(t.userId)]);

/* ---------- Ca học ---------- */
export const classes = pgTable('classes', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  name: text('name').notNull(),
  subject: text('subject').notNull().default(''),
  days: jsonb('days').notNull().default(sql`'[]'::jsonb`), // [1..6,0] — 1=T2 … 0=CN
  startTime: text('start_time').notNull().default('18:00'),
  endTime: text('end_time').notNull().default('19:30'),
  color: text('color').notNull().default('#2F5D50'),
  startDate: text('start_date').notNull().default(''),
  endDate: text('end_date').notNull().default(''),
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('classes_user_idx').on(t.userId)]);

export const classStudents = pgTable('class_students', {
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  classId: uuid('class_id').notNull().references(() => classes.id, { onDelete: 'cascade' }),
  studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
}, (t) => [primaryKey({ columns: [t.classId, t.studentId] }), index('cs_user_idx').on(t.userId)]);

/* ---------- Điểm danh ---------- */
export const attendance = pgTable('attendance', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  date: text('date').notNull(),                       // ISO yyyy-mm-dd
  classId: uuid('class_id').notNull().references(() => classes.id, { onDelete: 'cascade' }),
  note: text('note').notNull().default(''),
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [
  uniqueIndex('att_user_date_class_uq').on(t.userId, t.date, t.classId),
  index('att_user_date_idx').on(t.userId, t.date),
]);

export const attendanceRecords = pgTable('attendance_records', {
  attendanceId: uuid('attendance_id').notNull().references(() => attendance.id, { onDelete: 'cascade' }),
  studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
  status: text('status').notNull(),                   // present | late | excused | absent
  note: text('note').notNull().default(''),
}, (t) => [primaryKey({ columns: [t.attendanceId, t.studentId] })]);

/* ---------- Thu học phí ---------- */
export const payments = pgTable('payments', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
  month: text('month').notNull(),                     // YYYY-MM
  amount: integer('amount').notNull(),
  paidAt: text('paid_at').notNull().default(''),      // ISO yyyy-mm-dd
  method: text('method').notNull().default('Chuyển khoản'),
  note: text('note').notNull().default(''),
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('pay_user_month_idx').on(t.userId, t.month)]);

/* ---------- Điểm kiểm tra ---------- */
export const scores = pgTable('scores', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  studentId: uuid('student_id').notNull().references(() => students.id, { onDelete: 'cascade' }),
  date: text('date').notNull().default(''),
  title: text('title').notNull().default('Kiểm tra'),
  score: real('score').notNull(),
  note: text('note').notNull().default(''),
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('scores_user_idx').on(t.userId)]);

/* ---------- Giáo án ---------- */
export const lessons = pgTable('lessons', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  date: text('date').notNull().default(''),
  classId: uuid('class_id'),
  title: text('title').notNull(),
  content: text('content').notNull().default(''),
  homework: text('homework').notNull().default(''),
  deleted: boolean('deleted').notNull().default(false),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('lessons_user_idx').on(t.userId)]);

/* ---------- File đính kèm (lưu base64 trong DB) ---------- */
export const files = pgTable('files', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  lessonId: uuid('lesson_id'),
  name: text('name').notNull(),
  mime: text('mime').notNull().default('application/octet-stream'),
  size: integer('size').notNull().default(0),
  data: text('data').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
}, (t) => [index('files_user_idx').on(t.userId), index('files_lesson_idx').on(t.lessonId)]);
