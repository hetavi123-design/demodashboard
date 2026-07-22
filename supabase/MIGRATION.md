# Migrating off localStorage — step by step

## Progress so far
- ✅ Schema + RLS designed (`supabase/schema.sql`)
- ✅ `src/lib/api.js` — granular mutation functions
- ✅ `src/lib/legacyShape.js` — reshapes Supabase data to match the existing UI's expected object shape, so most components don't need to change
- ✅ Root component (`KaizenPortal`) loads from Supabase when `VITE_SUPABASE_URL` + `VITE_CENTER_ID` are set, and falls back to the old localStorage demo otherwise
- ✅ **Homework verification** — parent PIN checked server-side, photo uploaded to Storage, write goes straight to the `homework` table
- ✅ **Daily logs** — batch or single-student publish writes to `daily_logs`
- ✅ **Homework assignment** — batch or single-student assign writes to `homework`
- ✅ **Scores** — adding a test score writes to `scores`
- ✅ **Fees** — setting total, recording a payment, and removing a payment all write through, with paid/due status recomputed correctly each time
- ✅ **Messages** — direct and batch text messages write through
- ✅ **Announcements** — publish and remove write through
- ⬜ Attendance marking (Present/Absent buttons) — still local-only
- ⬜ Student registration/leads workflow (approve, reject, lead status) — still local-only
- ⬜ Programs/sessions progress and certificates — still local-only
- ⬜ Faculty management (add/remove teacher accounts), custom batch create/rename — still local-only
- ⬜ Real authentication (currently plaintext password check) — see Auth section below
- ⬜ Load testing at 500-student volume

## Known gaps to decide on before this goes live with a real client
These aren't bugs so much as places where the schema and the old UI don't fully agree — worth a deliberate decision, not a silent workaround:
- **Fee "due by" label**: the old UI stores a free-text label like `"15 Aug"`; the schema's `fees_due_date` is a real `date` column. Currently the label isn't synced through Supabase at all. Either switch the UI to a real date picker, or widen the column to text.
- **Message reactions**: not in the schema. They still work in the old localStorage mode but silently don't persist in Supabase mode. Low priority — add a `reactions` jsonb column later if this matters to real users.
- **Message image attachments**: schema is text-only for now; `p.img` isn't uploaded/synced.
- **Batch-wide homework flag** (`batchWide`): used by the "batch completion tracker" UI to group homework assigned to a whole batch. Not tracked in the schema, so that tracker view will look empty/wrong once running on Supabase. Would need a `batch_wide` boolean + a shared `title` grouping key, or a separate `batch_homework` table.

## What you need to do to actually test this
1. Create the Supabase project and run `schema.sql`
2. Insert a `centers` row, copy its id
3. Fill in `.env`: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_CENTER_ID`
4. Migrate Arya/Mahi/Amey's seed data into the real tables (I can generate this insert script once you share the center id)
5. Run `npm run dev` — homework verification, daily logs, homework assignment, scores, fees, messages, and announcements will all be live end-to-end

## 1. Set up Supabase
1. Create a free project at supabase.com
2. In the SQL Editor, run `schema.sql` from this folder (top to bottom)
3. Create the storage bucket for verification photos (see note at bottom of schema.sql)
4. Copy your Project URL and anon key into a `.env` file:
   ```
   VITE_SUPABASE_URL=https://xxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=xxxx
   ```
5. Install the client: `npm install @supabase/supabase-js`

## 2. Create your first center + seed data
Run once in the SQL Editor to migrate Kaizen's existing demo data:
```sql
insert into centers (name, slug, plan) values ('Kaizen Academy', 'kaizen', 'growth')
returning id; -- copy this id, you'll need it below
```
Then insert Arya/Mahi/Amey as real rows using that `center_id` (I can generate this
seed script for you once the project is created — send me the center_id).

## 3. Swap the data layer in App.jsx
- Replace `loadData()` calls with `loadCenterData(centerId)` from `src/lib/api.js`
- Replace every place that currently mutates local state and calls `save(d)` with
  the specific mutation function (`addHomework`, `verifyHomework`, `addFeePayment`, etc.)
  This is the biggest structural change — instead of "save the whole blob," each
  user action now writes just what changed.
- Remove the `parentPin` field from student objects entirely — it now lives hashed
  in `student_parent_pins`, checked via `verifyParentPin()`.
- Replace the base64 photo capture in `VerifyModal` with `uploadVerificationPhoto()`.

## 4. Auth
Right now teacher/student login is a plaintext password check against localStorage.
Two options, in order of how much work they are:
- **Quick/pragmatic**: keep your own login table check, but hash passwords
  (bcrypt via an Edge Function) instead of storing them in plaintext.
- **Proper**: use Supabase Auth (`supabase.auth.signInWithPassword`) and link
  `auth_user_id` on the teacher/student rows — gets you password reset, sessions,
  and RLS enforcement "for free." Worth doing before your first paying client.

## 5. Testing at 500-student scale
Once real data is flowing through Supabase (not before — this step is meaningless
against localStorage):

1. **Seed realistic volume**: write a script to insert 500 fake students into one
   center, each with ~5 homework entries, ~10 scores, ~20 attendance days. I can
   generate this seeder for you.
2. **Check dashboard load time** with that volume — the teacher's "all students"
   view is the one most likely to slow down; make sure it's paginated or virtualized,
   not rendering 500 rows at once.
3. **Check query patterns**: Supabase free tier gives you a query performance
   view in the dashboard — watch for any query without an index hitting hundreds
   of rows (the indexes in schema.sql cover the obvious ones).
4. **Concurrency check**: 500 students doesn't mean 500 simultaneous users.
   Realistically test 15–30 concurrent connections (parents checking fee status
   around due dates is the likely peak) — a tool like `k6` or even multiple
   browser tabs is enough at this scale, you don't need serious load-testing
   infrastructure yet.
5. **Storage check**: verification photos at ~50KB each, 500 students, homework
   most days — estimate your Supabase Storage usage against the free tier (1GB)
   and know when you'll need to upgrade.

## What NOT to worry about yet
Supabase's free tier (500MB database, 1GB storage, 50k monthly active users)
comfortably handles a single 500-student center. You do not need to worry about
infrastructure cost or scaling architecture at this stage — the work now is
correctness (real sync, real security), not raw scale.
