# Budget Planning & Actual Tracking System — API Design

Base URL: `https://api.yourcompany.com/v1`  
Auth: `Authorization: Bearer <JWT_TOKEN>`  
Format: JSON (Content-Type: application/json)

---

## Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | เข้าสู่ระบบ รับ JWT token |
| POST | `/auth/refresh` | Refresh token |
| POST | `/auth/logout` | ออกจากระบบ |

### POST /auth/login
```json
// Request
{ "email": "user@company.com", "password": "..." }

// Response 200
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 3600,
  "user": { "id": "uuid", "name": "สุดาราตน์", "role": "finance_manager" }
}
```

---

## Revenue Budget (ประมาณการรายรับ)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/revenue-budgets` | ดูรายการทั้งหมด (filter: year, dept, month) |
| POST | `/revenue-budgets` | สร้างประมาณการใหม่ |
| GET | `/revenue-budgets/:id` | ดูรายละเอียด |
| PUT | `/revenue-budgets/:id` | แก้ไข |
| DELETE | `/revenue-budgets/:id` | ลบ (soft delete) |
| POST | `/revenue-budgets/:id/approve` | อนุมัติ (Finance Manager+) |
| GET | `/revenue-budgets/ytd` | ยอดสะสม YTD |

### GET /revenue-budgets?year=2569&month=5&dept_id=1
```json
{
  "data": [
    {
      "id": 42,
      "dept": { "id": 1, "name": "สำนักงานใหญ่" },
      "month": 5,
      "amount": 20500000,
      "status": "approved",
      "version": 1,
      "approved_by": "ประชา วงศ์สุวรรณ",
      "approved_at": "2026-04-25T09:00:00Z"
    }
  ],
  "meta": { "total": 12, "page": 1, "per_page": 50 }
}
```

---

## Expense Budget (งบประมาณรายจ่าย)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/expense-budgets` | ดูรายการ (filter: year, dept, category, month, status) |
| POST | `/expense-budgets` | สร้างงบประมาณ |
| PUT | `/expense-budgets/:id` | แก้ไข |
| POST | `/expense-budgets/:id/submit` | ส่งขออนุมัติ |
| POST | `/expense-budgets/:id/approve` | อนุมัติ |
| POST | `/expense-budgets/:id/reject` | ปฏิเสธพร้อมเหตุผล |
| GET | `/expense-budgets/summary` | สรุปงบทั้งหมดตามแผนก |

---

## Actual Transactions (ผลจริง)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/actuals` | ดูรายการจริง (filter: type, date_from, date_to, dept, category) |
| POST | `/actuals` | บันทึกรายการใหม่ (manual) |
| PUT | `/actuals/:id` | แก้ไข |
| DELETE | `/actuals/:id` | ลบ |
| POST | `/actuals/:id/verify` | ตรวจสอบความถูกต้อง |
| POST | `/actuals/import` | นำเข้าจาก Excel/CSV (multipart/form-data) |
| GET | `/actuals/import/:batch_id` | ตรวจสอบสถานะการนำเข้า |

### POST /actuals/import
```
Content-Type: multipart/form-data
file: <binary>
fiscal_year: 2569
type: expense
dept_id: 3
```
```json
// Response 202
{
  "batch_id": "uuid-xxxx",
  "status": "processing",
  "message": "นำเข้า 150 แถว กำลังประมวลผล..."
}
```

---

## Budget vs Actual (เปรียบเทียบ)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/compare/monthly` | เปรียบเทียบรายเดือน |
| GET | `/compare/quarterly` | เปรียบเทียบรายไตรมาส |
| GET | `/compare/by-dept` | เปรียบเทียบตามแผนก |
| GET | `/compare/by-category` | เปรียบเทียบตามหมวดค่าใช้จ่าย |

### GET /compare/monthly?year=2569&type=revenue
```json
{
  "data": [
    {
      "month": 1,
      "month_name": "มกราคม",
      "budget": 20500000,
      "actual": 19800000,
      "variance": -700000,
      "variance_pct": -3.41,
      "ytd_budget": 20500000,
      "ytd_actual": 19800000,
      "status": "below_target"
    }
  ],
  "summary": {
    "total_budget": 124500000,
    "total_actual": 118200000,
    "total_variance": -6300000,
    "variance_pct": -5.06,
    "accuracy": 94.94
  }
}
```

---

## Dashboard & KPIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/dashboard/summary` | Executive Summary cards |
| GET | `/dashboard/kpis` | KPI ทั้งหมด |
| GET | `/dashboard/trends` | Chart data สำหรับ trend |
| GET | `/dashboard/weekly` | Weekly performance |
| GET | `/dashboard/top-revenue` | Top 5 รายรับ |
| GET | `/dashboard/top-expenses` | Top 5 ค่าใช้จ่าย |
| GET | `/dashboard/dept-performance` | ผลงานแต่ละแผนก |

### GET /dashboard/summary?year=2569
```json
{
  "revenue": {
    "budget_ytd": 124500000,
    "actual_ytd": 118200000,
    "variance": -6300000,
    "variance_pct": -5.06
  },
  "expense": {
    "budget_ytd": 89300000,
    "actual_ytd": 84700000,
    "variance": 4600000,
    "variance_pct": 5.15
  },
  "net_profit": {
    "budget": 35200000,
    "actual": 33500000,
    "variance": -1700000
  },
  "achievement_pct": 94.94,
  "status": "near_target",
  "updated_at": "2026-06-03T09:15:00Z"
}
```

---

## Alerts (การแจ้งเตือน)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/alerts` | รายการแจ้งเตือนทั้งหมด |
| POST | `/alerts/configs` | ตั้งค่าการแจ้งเตือน |
| PUT | `/alerts/configs/:id` | แก้ไขการตั้งค่า |
| GET | `/alerts/active` | แจ้งเตือนที่กำลังแอคทีฟ |

---

## Reports

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/reports/weekly` | สร้าง Weekly Report |
| POST | `/reports/monthly` | สร้าง Monthly Report |
| POST | `/reports/quarterly` | สร้าง Quarterly Report |
| POST | `/reports/annual` | สร้าง Annual Report |
| GET | `/reports/:id/download` | ดาวน์โหลด (PDF/Excel) |
| GET | `/reports/schedules` | ดูตาราง Auto Report |
| POST | `/reports/schedules` | ตั้งค่า Auto Report |

### POST /reports/monthly
```json
// Request
{
  "year": 2569,
  "month": 5,
  "format": ["pdf", "excel"],
  "recipients": ["cfo@company.com"],
  "include_sections": ["summary","charts","variance_table","dept_breakdown"]
}

// Response 202
{ "report_id": "uuid", "status": "generating", "estimated_seconds": 15 }
```

---

## AI Analytics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/ai/forecast/revenue` | คาดการณ์รายรับ 3 เดือนถัดไป |
| GET | `/ai/forecast/expense` | คาดการณ์รายจ่าย |
| GET | `/ai/insights` | AI Insights สำหรับผู้บริหาร |
| GET | `/ai/anomalies` | ตรวจจับความผิดปกติ |

---

## Users & Permissions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users` | รายชื่อผู้ใช้ทั้งหมด (Admin only) |
| POST | `/users` | เพิ่มผู้ใช้ใหม่ |
| PUT | `/users/:id` | แก้ไขข้อมูลผู้ใช้ |
| DELETE | `/users/:id` | ปิดการใช้งาน |
| GET | `/users/:id/permissions` | ดูสิทธิ์ |
| PUT | `/users/:id/permissions` | แก้ไขสิทธิ์ |

---

## Error Responses
```json
// 400 Bad Request
{ "error": "VALIDATION_ERROR", "message": "amount ต้องมากกว่า 0", "field": "amount" }

// 401 Unauthorized
{ "error": "UNAUTHORIZED", "message": "Token หมดอายุ กรุณาเข้าสู่ระบบใหม่" }

// 403 Forbidden
{ "error": "FORBIDDEN", "message": "คุณไม่มีสิทธิ์อนุมัติงบประมาณ" }

// 404 Not Found
{ "error": "NOT_FOUND", "message": "ไม่พบข้อมูลที่ต้องการ" }

// 500 Internal Server Error
{ "error": "INTERNAL_ERROR", "message": "เกิดข้อผิดพลาด กรุณาติดต่อผู้ดูแลระบบ" }
```

---

## Role Permissions Matrix

| Feature | Admin | Finance Mgr | Dept Manager | Exec Viewer |
|---------|-------|-------------|--------------|-------------|
| ดูข้อมูลทุกแผนก | ✅ | ✅ | ❌ (แผนกตัวเอง) | ✅ (read-only) |
| สร้าง/แก้ไขงบประมาณ | ✅ | ✅ | ✅ (แผนกตัวเอง) | ❌ |
| อนุมัติงบประมาณ | ✅ | ✅ | ❌ | ❌ |
| นำเข้าข้อมูล Actual | ✅ | ✅ | ❌ | ❌ |
| ออกรายงาน | ✅ | ✅ | ✅ (แผนกตัวเอง) | ✅ |
| จัดการผู้ใช้งาน | ✅ | ❌ | ❌ | ❌ |
| ดู AI Analytics | ✅ | ✅ | ❌ | ✅ |
| ตั้งค่าการแจ้งเตือน | ✅ | ✅ | ✅ (แผนกตัวเอง) | ❌ |

---

## Tech Stack Recommendation

### Backend
- **Runtime**: Node.js 20 + Express.js หรือ Python 3.12 + FastAPI
- **ORM**: Prisma (Node) / SQLAlchemy (Python)
- **Auth**: JWT + bcrypt, Refresh token rotation
- **Queue**: Bull/BullMQ สำหรับ background jobs (report generation, email)
- **Cache**: Redis (dashboard data, 5-min TTL)

### Frontend
- **Framework**: Next.js 14 (App Router)
- **Styling**: Tailwind CSS
- **Charts**: Recharts หรือ ECharts
- **State**: Zustand + TanStack Query
- **Table**: TanStack Table

### Infrastructure
- **Database**: PostgreSQL 16 (AWS RDS / Supabase)
- **Storage**: S3 / Cloudflare R2 (สำหรับ Excel, PDF exports)
- **Email**: SendGrid / AWS SES
- **LINE Notify**: LINE Messaging API
- **Deploy**: Docker + Nginx, AWS ECS / Railway / Render

### Environment Variables
```env
DATABASE_URL=postgresql://user:pass@host:5432/budget_db
JWT_SECRET=your-super-secret-key-min-32-chars
JWT_EXPIRES_IN=1h
REFRESH_TOKEN_EXPIRES_IN=7d
REDIS_URL=redis://localhost:6379
AWS_S3_BUCKET=budget-reports
SENDGRID_API_KEY=SG.xxx
LINE_CHANNEL_TOKEN=xxx
OPENAI_API_KEY=sk-xxx  # สำหรับ AI Analytics
```
