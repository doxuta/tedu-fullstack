/** Chạy: npm run db:migrate — khởi tạo schema trên DATABASE_URL hiện tại. */
import 'dotenv/config';
import { getDb } from './index.js';
import { ensureSchema } from './ddl.js';

const db = await getDb();
await ensureSchema(db);
console.log('✓ Đã khởi tạo / cập nhật schema cho', (process.env.DATABASE_URL ?? '(mặc định)').split('@').pop());
process.exit(0);
