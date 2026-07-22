-- ============================================================
-- KAIZEN PORTAL — Supabase schema (multi-tenant)
-- Every table that holds center-specific data carries center_id
-- so this same schema serves Kaizen AND every white-labeled client.
-- ============================================================

create extension if not exists "pgcrypto"; -- for gen_random_uuid()

-- ---------- CENTERS (one row per coaching center you sell to) ----------
create table centers (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  slug         text unique not null,         -- e.g. 'kaizen', 'sudhir-tutorials'
  plan         text not null default 'starter', -- starter | growth | scale
  created_at   timestamptz not null default now()
);

-- ---------- TEACHERS / STAFF ----------
create table teachers (
  id           uuid primary key default gen_random_uuid(),
  center_id    uuid not null references centers(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null, -- links to Supabase Auth
  username     text not null,
  name         text not null,
  is_admin     boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (center_id, username)
);

-- ---------- STUDENTS ----------
create table students (
  id             uuid primary key default gen_random_uuid(),
  center_id      uuid not null references centers(id) on delete cascade,
  auth_user_id   uuid references auth.users(id) on delete set null,
  name           text not null,
  grade          text,
  board          text,             -- SSC / CBSE / ICSE / IGCSE
  batch          text,
  parent_name    text,
  phone          text,
  school         text,
  source         text,             -- how they found the center
  registered_on  date not null default current_date,
  -- fees summary (payments themselves are in fee_payments)
  fees_status    text not null default 'Due', -- Paid | Due
  fees_due_date  date,
  fees_total     numeric(10,2) not null default 0,
  -- attendance summary
  attendance_present int not null default 0,
  attendance_total   int not null default 0,
  created_at     timestamptz not null default now()
);
create index idx_students_center on students(center_id);
create index idx_students_batch  on students(center_id, batch);

-- Parent PIN stored separately and hashed at the app layer before insert —
-- never store PINs in plaintext (the localStorage version did; don't carry that over).
create table student_parent_pins (
  student_id   uuid primary key references students(id) on delete cascade,
  pin_hash     text not null
);

-- ---------- FEE PAYMENTS ----------
create table fee_payments (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  amount       numeric(10,2) not null,
  paid_on      date not null default current_date,
  note         text,
  created_at   timestamptz not null default now()
);
create index idx_fee_payments_student on fee_payments(student_id);

-- ---------- DAILY LOGS (what was taught) ----------
create table daily_logs (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  log_date     date not null default current_date,
  text         text not null,
  created_at   timestamptz not null default now()
);
create index idx_daily_logs_student on daily_logs(student_id, log_date);

-- ---------- HOMEWORK ----------
create table homework (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references students(id) on delete cascade,
  title          text not null,
  assigned_on    date not null default current_date,
  due_on         date,
  done           boolean not null default false,
  verified_by    text,            -- 'Parent PIN' | 'Parent PIN + Photo'
  verified_at    timestamptz,
  verify_photo_url text,          -- Supabase Storage URL, not base64 blob
  created_at     timestamptz not null default now()
);
create index idx_homework_student on homework(student_id, due_on);

-- ---------- SCORES ----------
create table scores (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  subject      text not null,
  test_name    text not null,
  test_date    date not null,
  marks        numeric(6,2) not null,
  max_marks    numeric(6,2) not null default 100,
  created_at   timestamptz not null default now()
);
create index idx_scores_student on scores(student_id, test_date);

-- ---------- SESSION / SYLLABUS PROGRESS ----------
create table session_progress (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  session_id   text not null,     -- matches SESSIONS[].id from the app
  progress     int not null default 0,   -- 0-100
  completed    boolean not null default false,
  unique (student_id, session_id)
);

-- ---------- CERTIFICATES ----------
create table certificates (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  program      text not null,
  issued_on    date not null default current_date
);

-- ---------- ANNOUNCEMENTS (center-wide) ----------
create table announcements (
  id           uuid primary key default gen_random_uuid(),
  center_id    uuid not null references centers(id) on delete cascade,
  announce_date date not null default current_date,
  text         text not null,
  created_at   timestamptz not null default now()
);
create index idx_announcements_center on announcements(center_id, announce_date desc);

-- ---------- MESSAGES (per-student, teacher <-> parent) ----------
create table messages (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  from_role    text not null,      -- 'teacher' | 'parent'
  text         text not null,
  sent_at      timestamptz not null default now()
);
create index idx_messages_student on messages(student_id, sent_at);

-- ---------- BATCH MESSAGES (broadcast to a whole batch) ----------
create table batch_messages (
  id           uuid primary key default gen_random_uuid(),
  center_id    uuid not null references centers(id) on delete cascade,
  batch        text not null,
  from_role    text not null default 'teacher',
  text         text not null,
  sent_at      timestamptz not null default now()
);
create index idx_batch_messages_center on batch_messages(center_id, batch, sent_at);

-- ============================================================
-- ROW LEVEL SECURITY
-- Every center's data is isolated from every other center's.
-- This is what makes white-labeling to multiple clients SAFE —
-- without this, one center could accidentally query another's students.
-- ============================================================

alter table centers            enable row level security;
alter table teachers           enable row level security;
alter table students           enable row level security;
alter table student_parent_pins enable row level security;
alter table fee_payments       enable row level security;
alter table daily_logs         enable row level security;
alter table homework           enable row level security;
alter table scores             enable row level security;
alter table session_progress   enable row level security;
alter table certificates       enable row level security;
alter table announcements      enable row level security;
alter table messages           enable row level security;
alter table batch_messages     enable row level security;

-- Helper: get the center_id of the currently logged-in teacher
create or replace function auth_center_id() returns uuid as $$
  select center_id from teachers where auth_user_id = auth.uid()
$$ language sql stable security definer;

-- Teachers can only see/manage their own center's data
create policy teacher_self_access on teachers
  for select using (auth_user_id = auth.uid());

create policy teacher_center_isolation on teachers
  for all using (center_id = auth_center_id());

create policy teacher_center_isolation on students
  for all using (center_id = auth_center_id());

create policy teacher_center_isolation on announcements
  for all using (center_id = auth_center_id());

create policy teacher_center_isolation on batch_messages
  for all using (center_id = auth_center_id());

-- Child tables inherit isolation via their parent student/center
create policy teacher_via_student on fee_payments
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on daily_logs
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on homework
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on scores
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on session_progress
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on certificates
  for all using (student_id in (select id from students where center_id = auth_center_id()));

create policy teacher_via_student on messages
  for all using (student_id in (select id from students where center_id = auth_center_id()));

-- A student/parent can only see their own student record
create policy student_self_access on students
  for select using (auth_user_id = auth.uid());

create policy student_self_fee_payments on fee_payments
  for select using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_daily_logs on daily_logs
  for select using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_homework on homework
  for all using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_scores on scores
  for select using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_sessions on session_progress
  for select using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_certificates on certificates
  for select using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_messages on messages
  for all using (student_id in (select id from students where auth_user_id = auth.uid()));

create policy student_self_announcements on announcements
  for select using (center_id in (select center_id from students where auth_user_id = auth.uid()));

create policy student_self_batch_messages on batch_messages
  for select using (
    batch in (select batch from students where auth_user_id = auth.uid())
    and center_id in (select center_id from students where auth_user_id = auth.uid())
  );

-- ============================================================
-- PARENT PIN — hashed check, runs server-side so the plaintext
-- PIN never needs to be compared in browser JS.
-- ============================================================
create extension if not exists "pgcrypto";

create or replace function check_parent_pin(p_student_id uuid, p_pin text)
returns boolean as $$
  select pin_hash = crypt(p_pin, pin_hash)
  from student_parent_pins
  where student_id = p_student_id
$$ language sql security definer;

-- Insert/update a parent PIN (call this from a secure admin action, e.g. via
-- an Edge Function, never directly from the browser with the anon key):
--   insert into student_parent_pins (student_id, pin_hash)
--   values (p_student_id, crypt(p_pin, gen_salt('bf')))
--   on conflict (student_id) do update set pin_hash = excluded.pin_hash;

-- ============================================================
-- GRANTS
-- Supabase's Table Editor adds these automatically when you create
-- tables through the UI. Since this schema was run as raw SQL, they
-- need to be explicit — without them, Postgres denies access to the
-- anon/authenticated roles entirely, before RLS policies even run.
-- ============================================================
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to anon, authenticated;
grant execute on function auth_center_id() to anon, authenticated;
grant execute on function check_parent_pin(uuid, text) to anon, authenticated;

-- ============================================================
-- STORAGE — bucket for homework verification photos
-- ON CONFLICT DO NOTHING makes this safe to re-run — without it,
-- Supabase's SQL Editor runs the whole script as one transaction,
-- so a duplicate-key error here rolls back every table above too.
-- ============================================================
insert into storage.buckets (id, name, public) values ('homework-photos', 'homework-photos', true)
on conflict (id) do nothing;
