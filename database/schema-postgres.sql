CREATE TABLE IF NOT EXISTS stores (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  email TEXT NOT NULL UNIQUE,
  store_code_hash TEXT NOT NULL,
  admin_pin_hash TEXT NOT NULL,
  store_lat DOUBLE PRECISION NOT NULL DEFAULT 13.7563,
  store_lng DOUBLE PRECISION NOT NULL DEFAULT 100.5018,
  store_radius DOUBLE PRECISION NOT NULL DEFAULT 250 CHECK (store_radius > 0),
  late_grace INTEGER NOT NULL DEFAULT 10 CHECK (late_grace >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  employee_code TEXT NOT NULL,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  role TEXT NOT NULL CHECK (role IN ('admin', 'employee')),
  pin_hash TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  shift_start TEXT NOT NULL DEFAULT '09:00',
  shift_end TEXT NOT NULL DEFAULT '18:00',
  grace_minutes INTEGER NOT NULL DEFAULT 10 CHECK (grace_minutes >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT users_store_employee_code_unique UNIQUE (store_id, employee_code)
);

CREATE TABLE IF NOT EXISTS attendance_logs (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_role TEXT NOT NULL,
  clock_in_at TIMESTAMPTZ NOT NULL,
  clock_out_at TIMESTAMPTZ,
  in_lat DOUBLE PRECISION,
  in_lng DOUBLE PRECISION,
  out_lat DOUBLE PRECISION,
  out_lng DOUBLE PRECISION,
  geofence_distance_in INTEGER,
  geofence_distance_out INTEGER,
  source TEXT NOT NULL DEFAULT 'web',
  notes TEXT NOT NULL DEFAULT '',
  audit_trail JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT attendance_clock_out_after_clock_in
    CHECK (clock_out_at IS NULL OR clock_out_at >= clock_in_at),
  CONSTRAINT attendance_in_distance_non_negative
    CHECK (geofence_distance_in IS NULL OR geofence_distance_in >= 0),
  CONSTRAINT attendance_out_distance_non_negative
    CHECK (geofence_distance_out IS NULL OR geofence_distance_out >= 0)
);

CREATE TABLE IF NOT EXISTS login_logs (
  id TEXT PRIMARY KEY,
  store_id TEXT REFERENCES stores(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  account_type TEXT NOT NULL CHECK (account_type IN ('admin', 'employee')),
  success BOOLEAN NOT NULL,
  ip_address INET,
  user_agent TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  actor_type TEXT NOT NULL CHECK (actor_type IN ('admin', 'employee', 'system')),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_store_active ON users(store_id, active);
CREATE INDEX IF NOT EXISTS idx_users_store_role ON users(store_id, role);
CREATE INDEX IF NOT EXISTS idx_attendance_store_date ON attendance_logs(store_id, clock_in_at);
CREATE INDEX IF NOT EXISTS idx_attendance_user_open ON attendance_logs(user_id, clock_out_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_one_open_per_user
  ON attendance_logs(user_id)
  WHERE clock_out_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_login_logs_store_date ON login_logs(store_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_store_date ON audit_logs(store_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
