-- ============================================================
-- PATCH 2 — supports migrating attendance, the leads/registration
-- workflow, and faculty management to Supabase.
-- Safe to run on your real Kaizen project; only adds things, never drops.
-- ============================================================

-- Registration/leads workflow fields (previously only in localStorage)
alter table students add column if not exists approved boolean not null default true;
alter table students add column if not exists lead_status text;
alter table students add column if not exists lead_note text;

-- Custom batches that exist but have no students yet
alter table centers add column if not exists custom_batches text[] not null default '{}';

-- ============================================================
-- MISSING POLICY — same bug class as the teachers-table issue:
-- RLS was enabled on centers but no policy was ever attached,
-- meaning nobody (not even a correctly-linked teacher) could
-- read their own center's info. Fixing that here.
-- ============================================================
create policy teacher_own_center on centers
  for select using (id = auth_center_id());
