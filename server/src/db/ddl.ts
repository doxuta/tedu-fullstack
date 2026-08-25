/**
 * DDL khởi tạo — dùng cho PGlite (test/dev) và lần chạy đầu với Postgres.
 * Với Postgres production, dùng migrations trong ./migrations (drizzle-kit generate).
 * Viết idempotent (IF NOT EXISTS) để gọi an toàn nhiều lần.
 */
import { sql } from 'drizzle-orm';
import type { DB } from './index.js';

export async function ensureSchema(db: DB) {
  const stmts = [
    `CREATE TABLE IF NOT EXISTS users (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      email text NOT NULL,
      name text NOT NULL DEFAULT '',
      pass_hash text NOT NULL,
      role text NOT NULL DEFAULT 'teacher',
      status text NOT NULL DEFAULT 'active',
      settings jsonb NOT NULL DEFAULT '{}'::jsonb,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE UNIQUE INDEX IF NOT EXISTS users_email_uq ON users(email)`,
    `CREATE TABLE IF NOT EXISTS refresh_tokens (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash text NOT NULL,
      expires_at timestamptz NOT NULL,
      revoked_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS refresh_user_idx ON refresh_tokens(user_id)`,
    `CREATE TABLE IF NOT EXISTS students (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name text NOT NULL,
      grade text NOT NULL DEFAULT '',
      subject text NOT NULL DEFAULT '',
      rate integer NOT NULL DEFAULT 0,
      parent_name text NOT NULL DEFAULT '',
      parent_phone text NOT NULL DEFAULT '',
      phone text NOT NULL DEFAULT '',
      note text NOT NULL DEFAULT '',
      status text NOT NULL DEFAULT 'active',
      start_date text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS students_user_idx ON students(user_id)`,
    `CREATE TABLE IF NOT EXISTS classes (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name text NOT NULL,
      subject text NOT NULL DEFAULT '',
      days jsonb NOT NULL DEFAULT '[]'::jsonb,
      start_time text NOT NULL DEFAULT '18:00',
      end_time text NOT NULL DEFAULT '19:30',
      color text NOT NULL DEFAULT '#2F5D50',
      start_date text NOT NULL DEFAULT '',
      end_date text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS classes_user_idx ON classes(user_id)`,
    `CREATE TABLE IF NOT EXISTS class_students (
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      PRIMARY KEY (class_id, student_id)
    )`,
    `CREATE INDEX IF NOT EXISTS cs_user_idx ON class_students(user_id)`,
    `CREATE TABLE IF NOT EXISTS attendance (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      date text NOT NULL,
      class_id uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
      note text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE UNIQUE INDEX IF NOT EXISTS att_user_date_class_uq ON attendance(user_id, date, class_id)`,
    `CREATE INDEX IF NOT EXISTS att_user_date_idx ON attendance(user_id, date)`,
    `CREATE TABLE IF NOT EXISTS attendance_records (
      attendance_id uuid NOT NULL REFERENCES attendance(id) ON DELETE CASCADE,
      student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      status text NOT NULL,
      note text NOT NULL DEFAULT '',
      PRIMARY KEY (attendance_id, student_id)
    )`,
    `CREATE TABLE IF NOT EXISTS payments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      month text NOT NULL,
      amount integer NOT NULL,
      paid_at text NOT NULL DEFAULT '',
      method text NOT NULL DEFAULT 'Chuyển khoản',
      note text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS pay_user_month_idx ON payments(user_id, month)`,
    `CREATE TABLE IF NOT EXISTS scores (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      date text NOT NULL DEFAULT '',
      title text NOT NULL DEFAULT 'Kiểm tra',
      score real NOT NULL,
      note text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS scores_user_idx ON scores(user_id)`,
    `CREATE TABLE IF NOT EXISTS lessons (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      date text NOT NULL DEFAULT '',
      class_id uuid,
      title text NOT NULL,
      content text NOT NULL DEFAULT '',
      homework text NOT NULL DEFAULT '',
      deleted boolean NOT NULL DEFAULT false,
      updated_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS lessons_user_idx ON lessons(user_id)`,
    `CREATE TABLE IF NOT EXISTS files (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      lesson_id uuid,
      name text NOT NULL,
      mime text NOT NULL DEFAULT 'application/octet-stream',
      size integer NOT NULL DEFAULT 0,
      data text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )`,
    `CREATE INDEX IF NOT EXISTS files_user_idx ON files(user_id)`,
    `CREATE INDEX IF NOT EXISTS files_lesson_idx ON files(lesson_id)`,
  ];
  for (const s of stmts) await db.execute(sql.raw(s));
}
