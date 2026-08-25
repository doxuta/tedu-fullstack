# Kiến trúc TEdu

```
┌─────────────────────────────  CLIENT (Flutter · 1 codebase)  ─────────────────────────┐
│  iOS        Android        macOS        Windows        Linux        (Web)             │
│                                                                                        │
│  UI (Material 3 + theme vintage)                                                       │
│   └─ AppState (ChangeNotifier singleton)                                               │
│       ├─ ApiClient ── Bearer JWT ── tự refresh 401 ── lỗi chuẩn hoá                    │
│       ├─ Cache cục bộ (SharedPreferences JSON)  ← đọc khi offline                     │
│       └─ PendingOps queue  ← thao tác lúc offline, đẩy lại khi có mạng                │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │ HTTPS JSON
┌────────────────────────────────────────▼───────────────────────────────────────────────┐
│  SERVER — Node.js · Hono (web framework) · TypeScript strict                           │
│                                                                                        │
│  /api/v1                                                                               │
│   ├─ auth/       register · login · refresh (rotation) · logout                       │
│   ├─ students/   CRUD (upsert theo id client-gen — offline friendly)                  │
│   ├─ classes/    CRUD + gán học sinh (bảng nối class_students)                        │
│   ├─ attendance/ PUT nguyên buổi (date+classId) — idempotent                          │
│   ├─ payments/ scores/ lessons/   CRUD chung (crud.ts)                                │
│   ├─ stats/      month (học phí = buổi tính phí × đơn giá) · today (lịch theo thứ)    │
│   └─ sync/       GET ?since=… (delta) · POST (batch upsert, Last-Write-Wins)          │
│                                                                                        │
│  Drizzle ORM ── schema.ts là nguồn sự thật duy nhất                                    │
└────────────────────────────────────────┬───────────────────────────────────────────────┘
                                         │
                     ┌───────────────────┴──────────────────┐
                     │ PostgreSQL 16 (Docker local / Neon)  │
                     │ PGlite (WASM) khi chạy test          │
                     └──────────────────────────────────────┘
```

## Quyết định thiết kế

1. **ID sinh ở client (UUID v4)** — app tạo bản ghi khi offline mà không đợi server;
   POST là upsert (`onConflictDoUpdate`) nên đẩy lại nhiều lần vô hại.
2. **Xoá mềm mọi bảng** (`deleted=true`) — thiết bị khác nhận biết bản ghi biến mất qua `/sync`.
3. **Đồng bộ Last-Write-Wins theo `updatedAt`** — đơn giản, dự đoán được, đủ cho 1 gia sư
   nhiều thiết bị. Muốn nâng cấp: CRDT hoặc vector clock, thay ở `modules/sync.ts`.
4. **Điểm danh ghi nguyên buổi** — PUT `/attendance/:date/:classId` thay toàn bộ records:
   không bao giờ nhân đôi, sửa lại buổi cũ dễ dàng.
5. **Học phí tính ở server** (`stats.ts`) — client mọi nền tảng hiển thị cùng một con số;
   quy tắc: `present + late` (+ `absent` nếu bật `settings.chargeUnexcused`).
6. **PGlite cho test** — Postgres thật biên dịch WASM chạy trong Node: test hành vi SQL
   thật (unique index, jsonb, cascade) mà không cần Docker trong CI.
7. **Phiên đăng nhập**: access JWT ngắn hạn (15') + refresh dài hạn (30 ngày) *xoay vòng* —
   lộ refresh token cũ là vô dụng sau lần dùng đầu.

## Nâng cấp gợi ý theo tầng

| Tầng | Hiện tại | Bước sau |
|---|---|---|
| Cache client | SharedPreferences JSON | SQLite (drift) + reactive query |
| Realtime | pull khi mở màn | WebSocket /ws đẩy invalidation |
| Auth | email + mật khẩu | thêm Google/Apple OAuth (bảng identities) |
| File giáo án | (chưa) | S3-compatible (R2/MinIO) + presigned URL |
| Triển khai | thủ công | Dockerfile server + GitHub Actions CI (npm test + flutter analyze) |
