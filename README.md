# Kaizen Academy Portal

A student / parent / teacher portal for Kaizen Academy. Per-student dashboards, daily class logs, homework with parent PIN + photo verification, score tracking with charts, six compulsory Kaizen programs, auto-issued certificates, direct and batch-wise messaging, batch-wise homework, attendance, fees and announcements.

## What's inside

```
kaizen-portal-app/
├── index.html          # entry page
├── package.json        # dependencies & scripts
├── vite.config.js      # build config
└── src/
    ├── main.jsx        # boots React
    └── App.jsx         # the ENTIRE portal (edit this file)
```

## Step 1 — Run it on your laptop

Requirements: Node.js 18+ (download from nodejs.org — LTS version).

```bash
cd kaizen-portal-app
npm install       # one time, downloads dependencies (~1 min)
npm run dev       # starts the app
```

Open the printed URL (usually http://localhost:5173). Demo logins are shown on the login screen.

## Step 2 — Put in your real students

All data lives in the `seed()` function near the top of `src/App.jsx`. Each student looks like:

```js
arya: {
  id: "arya", name: "Arya Shah", grade: "10", board: "SSC", batch: "SSC-10",
  password: "arya123", parentPin: "1111", parentName: "Mrs. Shah",
  ...
}
```

Copy the block, change the id/name/password/PIN/batch, and add one per student. Also add an empty `[]` entry for them in `messages`, and their batch in `batchMessages` if it's new.

Important: if you change seed data after running once, the browser keeps the OLD data (it's saved in localStorage). To reset, open the browser console and run:
```js
localStorage.removeItem("kaizen-portal-v1"); location.reload();
```

## Step 3 — Deploy it to the internet (free, ~10 minutes)

You already have Vercel set up for kaizenacademy.co.in, so:

1. Push this folder to a GitHub repository.
2. On vercel.com → Add New Project → import that repo. Vercel auto-detects Vite; just click Deploy.
3. In the project's Settings → Domains, add `portal.kaizenacademy.co.in`.
4. In your DNS (where kaizenacademy.co.in is managed), add a CNAME record: `portal` → `cname.vercel-dns.com`.

Done — parents visit portal.kaizenacademy.co.in.

## Step 4 — Understand the current limitation (read this!)

Right now data is stored in the **browser's localStorage**. That means:

- Everything works perfectly on ONE device (e.g., a tablet kept at the center, or for demos).
- But a parent's phone and your teacher's laptop each have their OWN copy — they don't sync.

This version is ideal for: demoing to parents, running at the center on a shared device, and validating that people actually use it — before investing in a backend.

## Step 5 — Upgrade to real multi-device logins (when ready)

When parents should use it from their own phones, add a free backend. Recommended: **Supabase** (free tier is plenty for a coaching center).

The upgrade path, in order:

1. Create a Supabase project → get the URL + anon key.
2. `npm install @supabase/supabase-js`
3. Create tables mirroring the data model: `students`, `homework`, `scores`, `daily_logs`, `messages`, `certificates`, `announcements`.
4. Replace the two storage functions in `App.jsx` (`loadData` and `save`) with Supabase reads/writes — they are deliberately the ONLY two places that touch storage, so the rest of the app doesn't change.
5. Use Supabase Auth for logins instead of the in-file passwords, and turn on Row Level Security so each parent can only read their own child's rows.

Rough effort: a weekend. Do it only after 10+ families are actively using the demo version — validate first, build infrastructure second.

## Security notes for real deployment

- Change all demo passwords and PINs before sharing the link.
- Passwords in `App.jsx` are visible to anyone who opens dev tools — fine for a demo, NOT fine for real use. Supabase Auth (Step 5) fixes this.
- Verification photos of parents are stored with homework check-offs; get parents' consent and avoid storing children's photos.

## Everyday operations cheat-sheet

| Task | Where |
|---|---|
| Post what was taught today | Teacher → Daily Log → Publish |
| Give homework to one student | Teacher → Homework → "Only [name]" |
| Give homework to a whole batch | Teacher → Homework → "Entire batch" |
| See who hasn't done homework | Teacher → Homework → completion tracker |
| Enter test marks | Teacher → Scores |
| Update program progress / give certificate | Teacher → Programs & Certs |
| Message one parent | Teacher → Messages → Direct |
| Message a whole batch | Teacher → Messages → Batch channels |
| Parent confirms homework | Student login → Homework → "Parent: mark done" (PIN + photo) |
