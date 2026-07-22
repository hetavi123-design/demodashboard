import { supabase } from "./supabaseClient";

/* ============================================================
   LEGACY SHAPE BRIDGE
   The UI in App.jsx was built against one big nested object:
     { teachers: {username: {...}}, students: {id: {...}}, announcements: [...],
       messages: {studentId: [...]}, batchMessages: {batch: [...]} }
   Rather than rewrite every component that reads that shape, this file
   fetches from Supabase and reassembles the SAME shape. This lets us
   migrate the backend first and the UI call-sites incrementally after,
   instead of a risky big-bang rewrite of the whole file at once.
   ============================================================ */

export async function loadCenterDataAsLegacyShape(centerId) {
  const { data: students, error } = await supabase
    .from("students")
    .select(`*, fee_payments(*), daily_logs(*), homework(*), scores(*), session_progress(*), certificates(*), messages(*)`)
    .eq("center_id", centerId);
  if (error) throw error;

  const { data: teachers, error: tErr } = await supabase
    .from("teachers").select("*").eq("center_id", centerId);
  if (tErr) throw tErr;

  const { data: announcements, error: aErr } = await supabase
    .from("announcements").select("*").eq("center_id", centerId).order("announce_date", { ascending: false });
  if (aErr) throw aErr;

  const { data: batchMessages, error: bErr } = await supabase
    .from("batch_messages").select("*").eq("center_id", centerId).order("sent_at", { ascending: true });
  if (bErr) throw bErr;

  const { data: center, error: cErr } = await supabase
    .from("centers").select("custom_batches").eq("id", centerId).single();
  if (cErr) throw cErr;

  const studentsObj = {};
  const messagesObj = {};
  for (const s of students) {
    studentsObj[s.id] = {
      id: s.id, name: s.name, grade: s.grade, board: s.board, batch: s.batch,
      parentName: s.parent_name, phone: s.phone, school: s.school, source: s.source,
      registered: s.registered_on,
      fees: {
        status: s.fees_status, due: s.fees_due_date || "—", total: Number(s.fees_total),
        payments: (s.fee_payments || []).map((p) => ({ id: p.id, amount: Number(p.amount), date: p.paid_on, note: p.note })),
      },
      attendance: { present: s.attendance_present, total: s.attendance_total },
      dailyLogs: (s.daily_logs || []).map((l) => ({ date: l.log_date, text: l.text })),
      authUserId: s.auth_user_id,
      approved: s.approved,
      leadStatus: s.lead_status,
      leadNote: s.lead_note,
      homework: (s.homework || []).map((h) => ({
        id: h.id, title: h.title, assigned: h.assigned_on, due: h.due_on, done: h.done,
        verify: h.verified_by ? { by: h.verified_by, ts: new Date(h.verified_at).getTime(), photo: h.verify_photo_url } : null,
      })),
      scores: (s.scores || []).map((sc) => ({ id: sc.id, subject: sc.subject, test: sc.test_name, date: sc.test_date, marks: Number(sc.marks), max: Number(sc.max_marks) })),
      sessions: Object.fromEntries((s.session_progress || []).map((sp) => [sp.session_id, { progress: sp.progress, completed: sp.completed }])),
      certificates: (s.certificates || []).map((c) => ({ id: c.id, program: c.program, date: c.issued_on })),
    };
    messagesObj[s.id] = (s.messages || [])
      .sort((a, b) => new Date(a.sent_at) - new Date(b.sent_at))
      .map((m) => ({ from: m.from_role, text: m.text, ts: new Date(m.sent_at).getTime() }));
  }

  const teachersObj = {};
  for (const t of teachers) teachersObj[t.username] = { username: t.username, name: t.name, admin: t.is_admin, _id: t.id, authUserId: t.auth_user_id };

  const batchMessagesObj = {};
  for (const bm of batchMessages) {
    (batchMessagesObj[bm.batch] = batchMessagesObj[bm.batch] || []).push({ from: bm.from_role, text: bm.text, ts: new Date(bm.sent_at).getTime() });
  }

  return {
    teachers: teachersObj,
    students: studentsObj,
    announcements: (announcements || []).map((a) => ({ id: a.id, date: a.announce_date, text: a.text })),
    messages: messagesObj,
    batchMessages: batchMessagesObj,
    customBatches: center?.custom_batches || [],
  };
}
