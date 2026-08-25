# TEdu API v1

Base URL: `http://localhost:8787/api/v1` · JSON · UTF-8
Xác thực: header `Authorization: Bearer <accessToken>` (trừ nhóm /auth).
Lỗi chuẩn: `{ "error": { "code": "...", "message": "..." } }`

## Auth
| Method | Path | Body | Trả về |
|---|---|---|---|
| POST | /auth/register | `{email, password(≥8), name?}` | `{user, accessToken, accessExpiresIn, refreshToken}` (201) |
| POST | /auth/login | `{email, password}` | như trên |
| POST | /auth/refresh | `{refreshToken}` | token mới (refresh cũ bị thu hồi) |
| POST | /auth/logout | `{refreshToken}` | `{ok:true}` |
| GET | /me | — | `{user}` |
| PATCH | /me | `{name?, settings?}` | `{user}` — `settings.chargeUnexcused: bool` ảnh hưởng cách tính phí |

## Học sinh `/students`
- `GET /` → `{items:[Student]}` (ẩn deleted; `?all=1` để lấy cả)
- `POST /` body `{id?, name*, grade, subject, rate, parentName, parentPhone, phone, note, status, startDate}` — có `id` = upsert
- `PATCH /:id` — sửa từng phần
- `DELETE /:id` — xoá mềm

`status`: `active | paused | stopped` · `rate`: đ/buổi (int)

## Ca học `/classes`
- `GET /` → items kèm `studentIds[]`
- `POST /` `{id?, name*, subject, days*[int 0..6, 1=T2…0=CN], startTime, endTime, color, startDate, endDate, studentIds[]}`
- `PATCH /:id` (gửi `studentIds` sẽ thay toàn bộ danh sách gán)
- `DELETE /:id`

## Điểm danh `/attendance`
- `GET /?from=YYYY-MM-DD&to=…&classId=…` → items kèm `records[]`
- `PUT /:date/:classId` `{records:[{studentId, status, note?}], note?}` — ghi đè nguyên buổi
- `DELETE /:date/:classId`

`status`: `present | late | excused | absent`

## Thu học phí `/payments`
- `POST /` `{id?, studentId*, month* "YYYY-MM", amount* >0, paidAt, method, note}`
- `GET /` · `PATCH /:id` · `DELETE /:id`

## Điểm `/scores` — `{studentId*, score* 0..10, title, date, note}`
## Giáo án `/lessons` — `{title*, classId?, date, content, homework}`

## Thống kê `/stats`
- `GET /stats/month/:ym` →
  ```json
  { "month":"2026-07", "chargeUnexcused":false,
    "rows":[{"studentId","name","rate","sessions","fee","paid","remaining"}],
    "totals":{"sessions","fee","paid","remaining"} }
  ```
- `GET /stats/today?date=YYYY-MM-DD` → `{date, items:[{classId,name,startTime,endTime,color,studentCount,attendanceTaken}]}`

## Đồng bộ `/sync`
- `GET /sync?since=ISO8601` → mọi bản ghi có `updatedAt > since` (kể cả `deleted:true`) cho
  students/classes/payments/scores/lessons + attendance (kèm records) + classStudents + `serverTime`.
  Client lưu `serverTime` làm con trỏ cho lần sau.
- `POST /sync` body `{students?[], classes?[], payments?[], scores?[], lessons?[]}` — mỗi phần tử
  bắt buộc `id` + `updatedAt` (ISO). Server áp dụng nếu `updatedAt` mới hơn bản đang có (LWW).
  Trả `{ok, applied:{...}, serverTime}`.

## Quản trị `/admin` (chỉ role=admin — email nằm trong env `ADMIN_EMAILS`)
- `GET /admin/users` → `{items:[{id,email,name,role,status,createdAt,studentCount}]}`
- `PATCH /admin/users/:id` `{status:"active"|"blocked"}` — tài khoản bị khoá không đăng nhập được (403); admin không tự khoá được mình (400)
