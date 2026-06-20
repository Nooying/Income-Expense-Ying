-- ============================================================
-- Budget Planning & Actual Tracking System
-- Database Schema (PostgreSQL)
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. USERS & ROLES
-- ============================================================
CREATE TABLE roles (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,  -- 'admin','finance_manager','dept_manager','exec_viewer'
    permissions JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    role_id     INTEGER REFERENCES roles(id),
    dept_id     INTEGER,  -- FK to departments (added below)
    is_active   BOOLEAN DEFAULT TRUE,
    last_login  TIMESTAMP,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 2. ORGANIZATION STRUCTURE
-- ============================================================
CREATE TABLE fiscal_years (
    id          SERIAL PRIMARY KEY,
    year        INTEGER NOT NULL UNIQUE,      -- e.g. 2569
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    is_active   BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE departments (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,  -- e.g. 'MKT','IT','OPS'
    name        VARCHAR(255) NOT NULL,
    parent_id   INTEGER REFERENCES departments(id),
    manager_id  UUID REFERENCES users(id),
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT NOW()
);

ALTER TABLE users ADD CONSTRAINT fk_user_dept
    FOREIGN KEY (dept_id) REFERENCES departments(id);

CREATE TABLE projects (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50) NOT NULL UNIQUE,
    name        VARCHAR(255) NOT NULL,
    dept_id     INTEGER REFERENCES departments(id),
    manager_id  UUID REFERENCES users(id),
    start_date  DATE,
    end_date    DATE,
    status      VARCHAR(30) DEFAULT 'active', -- active, completed, cancelled
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 3. EXPENSE CATEGORIES
-- ============================================================
CREATE TABLE expense_categories (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(30) NOT NULL UNIQUE, -- 'SALARY','RENT','UTIL','MKT','TRAVEL','OTHER'
    name        VARCHAR(255) NOT NULL,
    parent_id   INTEGER REFERENCES expense_categories(id),
    is_active   BOOLEAN DEFAULT TRUE
);

-- Seed data
INSERT INTO expense_categories (code, name) VALUES
    ('SALARY',  'เงินเดือนและสวัสดิการ'),
    ('RENT',    'ค่าเช่าและค่าใช้จ่ายสถานที่'),
    ('UTIL',    'ค่าสาธารณูปโภค'),
    ('MKT',     'ค่าการตลาดและโฆษณา'),
    ('TRAVEL',  'ค่าเดินทางและที่พัก'),
    ('IT',      'ค่าซอฟต์แวร์และไอที'),
    ('TRAINING','ค่าฝึกอบรมและพัฒนา'),
    ('OTHER',   'ค่าใช้จ่ายอื่นๆ');

-- ============================================================
-- 4. REVENUE BUDGET (ประมาณการรายรับ)
-- ============================================================
CREATE TABLE revenue_budgets (
    id              SERIAL PRIMARY KEY,
    fiscal_year_id  INTEGER NOT NULL REFERENCES fiscal_years(id),
    dept_id         INTEGER REFERENCES departments(id),
    project_id      INTEGER REFERENCES projects(id),
    month           INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    amount          NUMERIC(18,2) NOT NULL DEFAULT 0,
    version         INTEGER DEFAULT 1,           -- รองรับ revision
    status          VARCHAR(30) DEFAULT 'draft', -- draft, approved, locked
    approved_by     UUID REFERENCES users(id),
    approved_at     TIMESTAMP,
    notes           TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE (fiscal_year_id, dept_id, project_id, month, version)
);

-- ============================================================
-- 5. EXPENSE BUDGET (งบประมาณรายจ่าย)
-- ============================================================
CREATE TABLE expense_budgets (
    id              SERIAL PRIMARY KEY,
    fiscal_year_id  INTEGER NOT NULL REFERENCES fiscal_years(id),
    dept_id         INTEGER NOT NULL REFERENCES departments(id),
    category_id     INTEGER NOT NULL REFERENCES expense_categories(id),
    month           INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    amount          NUMERIC(18,2) NOT NULL DEFAULT 0,
    version         INTEGER DEFAULT 1,
    status          VARCHAR(30) DEFAULT 'draft', -- draft, submitted, approved, rejected, locked
    submitted_by    UUID REFERENCES users(id),
    approved_by     UUID REFERENCES users(id),
    approved_at     TIMESTAMP,
    rejection_note  TEXT,
    notes           TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE (fiscal_year_id, dept_id, category_id, month, version)
);

-- ============================================================
-- 6. ACTUAL TRANSACTIONS (ผลจริง)
-- ============================================================
CREATE TABLE actual_transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fiscal_year_id  INTEGER NOT NULL REFERENCES fiscal_years(id),
    transaction_date DATE NOT NULL,
    type            VARCHAR(10) NOT NULL CHECK (type IN ('revenue','expense')),
    dept_id         INTEGER REFERENCES departments(id),
    project_id      INTEGER REFERENCES projects(id),
    category_id     INTEGER REFERENCES expense_categories(id), -- for expenses
    description     VARCHAR(500),
    amount          NUMERIC(18,2) NOT NULL,
    reference_no    VARCHAR(100),                -- invoice/receipt number
    source          VARCHAR(30) DEFAULT 'manual', -- manual, excel_import, api
    import_batch_id UUID,                        -- FK to import_batches
    is_verified     BOOLEAN DEFAULT FALSE,
    verified_by     UUID REFERENCES users(id),
    verified_at     TIMESTAMP,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_actual_date ON actual_transactions(transaction_date);
CREATE INDEX idx_actual_dept ON actual_transactions(dept_id);
CREATE INDEX idx_actual_type ON actual_transactions(type);
CREATE INDEX idx_actual_fiscal ON actual_transactions(fiscal_year_id);

-- ============================================================
-- 7. IMPORT BATCHES (นำเข้า Excel/CSV)
-- ============================================================
CREATE TABLE import_batches (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    filename        VARCHAR(500) NOT NULL,
    file_type       VARCHAR(10),       -- xlsx, csv
    total_rows      INTEGER DEFAULT 0,
    success_rows    INTEGER DEFAULT 0,
    error_rows      INTEGER DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'processing', -- processing, completed, failed
    error_log       JSONB,
    uploaded_by     UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW()
);

ALTER TABLE actual_transactions ADD CONSTRAINT fk_import_batch
    FOREIGN KEY (import_batch_id) REFERENCES import_batches(id);

-- ============================================================
-- 8. BUDGET VS ACTUAL VIEW (Materialized for performance)
-- ============================================================
CREATE MATERIALIZED VIEW mv_budget_vs_actual AS
SELECT
    fy.year                                     AS fiscal_year,
    d.name                                      AS dept_name,
    d.code                                      AS dept_code,
    ec.name                                     AS category,
    eb.month,
    'expense'                                   AS type,
    eb.amount                                   AS budget,
    COALESCE(SUM(at.amount), 0)                 AS actual,
    eb.amount - COALESCE(SUM(at.amount), 0)     AS variance,
    CASE
        WHEN eb.amount = 0 THEN NULL
        ELSE ROUND((eb.amount - COALESCE(SUM(at.amount), 0)) / eb.amount * 100, 2)
    END                                         AS variance_pct
FROM expense_budgets eb
JOIN fiscal_years fy ON fy.id = eb.fiscal_year_id
JOIN departments d ON d.id = eb.dept_id
JOIN expense_categories ec ON ec.id = eb.category_id
LEFT JOIN actual_transactions at
    ON at.dept_id = eb.dept_id
    AND at.category_id = eb.category_id
    AND EXTRACT(MONTH FROM at.transaction_date) = eb.month
    AND at.fiscal_year_id = eb.fiscal_year_id
    AND at.type = 'expense'
WHERE eb.status = 'approved'
GROUP BY fy.year, d.name, d.code, ec.name, eb.month, eb.amount

UNION ALL

SELECT
    fy.year, d.name, d.code,
    'Revenue'                                   AS category,
    rb.month, 'revenue',
    rb.amount,
    COALESCE(SUM(at.amount), 0),
    COALESCE(SUM(at.amount), 0) - rb.amount,
    CASE
        WHEN rb.amount = 0 THEN NULL
        ELSE ROUND((COALESCE(SUM(at.amount), 0) - rb.amount) / rb.amount * 100, 2)
    END
FROM revenue_budgets rb
JOIN fiscal_years fy ON fy.id = rb.fiscal_year_id
LEFT JOIN departments d ON d.id = rb.dept_id
LEFT JOIN actual_transactions at
    ON at.dept_id = rb.dept_id
    AND EXTRACT(MONTH FROM at.transaction_date) = rb.month
    AND at.fiscal_year_id = rb.fiscal_year_id
    AND at.type = 'revenue'
WHERE rb.status = 'approved'
GROUP BY fy.year, d.name, d.code, rb.month, rb.amount;

CREATE UNIQUE INDEX ON mv_budget_vs_actual (fiscal_year, dept_code, category, month, type);

-- Refresh command (run via cron or trigger):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_budget_vs_actual;

-- ============================================================
-- 9. ALERTS CONFIG
-- ============================================================
CREATE TABLE alert_configs (
    id              SERIAL PRIMARY KEY,
    dept_id         INTEGER REFERENCES departments(id),  -- NULL = global
    category_id     INTEGER REFERENCES expense_categories(id),
    threshold_pct   NUMERIC(5,2) DEFAULT 90.00,  -- แจ้งเตือนเมื่อใช้ถึง %
    alert_channel   VARCHAR(30) DEFAULT 'email',  -- email, line, both
    recipients      JSONB,                         -- ["email@..."]
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE alert_logs (
    id              SERIAL PRIMARY KEY,
    config_id       INTEGER REFERENCES alert_configs(id),
    fiscal_year     INTEGER,
    month           INTEGER,
    dept_id         INTEGER REFERENCES departments(id),
    category_id     INTEGER REFERENCES expense_categories(id),
    usage_pct       NUMERIC(5,2),
    message         TEXT,
    sent_at         TIMESTAMP DEFAULT NOW(),
    sent_to         JSONB
);

-- ============================================================
-- 10. SCHEDULED REPORTS
-- ============================================================
CREATE TABLE report_schedules (
    id              SERIAL PRIMARY KEY,
    report_type     VARCHAR(30) NOT NULL, -- weekly, monthly, quarterly, annual
    cron_expression VARCHAR(100),         -- e.g. '0 8 * * 1' = every Monday 8am
    recipients      JSONB NOT NULL,
    format          VARCHAR(20) DEFAULT 'pdf', -- pdf, excel, both
    is_active       BOOLEAN DEFAULT TRUE,
    last_run        TIMESTAMP,
    next_run        TIMESTAMP,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 11. AUDIT LOG
-- ============================================================
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID REFERENCES users(id),
    action      VARCHAR(50),     -- INSERT, UPDATE, DELETE, LOGIN, EXPORT
    table_name  VARCHAR(100),
    record_id   TEXT,
    old_values  JSONB,
    new_values  JSONB,
    ip_address  INET,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at);

-- ============================================================
-- SAMPLE DATA
-- ============================================================
INSERT INTO fiscal_years (year, start_date, end_date, is_active)
VALUES (2569, '2026-01-01', '2026-12-31', TRUE);

INSERT INTO departments (code, name) VALUES
    ('HQ',   'สำนักงานใหญ่'),
    ('MKT',  'ฝ่ายการตลาด'),
    ('IT',   'ฝ่ายเทคโนโลยีสารสนเทศ'),
    ('OPS',  'ฝ่าย Operations'),
    ('HR',   'ฝ่ายทรัพยากรบุคคล'),
    ('FIN',  'ฝ่ายการเงินและบัญชี'),
    ('SALE', 'ฝ่ายขาย'),
    ('CNX',  'สาขาเชียงใหม่'),
    ('HKT',  'สาขาภูเก็ต');
