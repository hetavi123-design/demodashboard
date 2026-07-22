import { supabase } from "./supabaseClient";

// ---------- Auth ----------
export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data.user; // has .id — match this against teachers/students authUserId
}

/* ============================================================
   Data access layer — mirrors the shape App.jsx already expects
   (teachers / students / announcements / messages / batchMessages),
   but reads and writes through Supabase instead of localStorage.

   Swap points in App.jsx:
     loadData()  -> loadCenterData(centerId)
     save(d)     -> individual mutation calls below, per action
   (Bulk "save the whole blob" doesn't map to a relational DB —
   each user action should call the specific mutation it needs.)
   ============================================================ */

// ---------- Load everything needed to render the dashboard for one center ----------
export async function loadCenterData(centerId) {
  const { data: students, error: studentsErr } = await supabase
    .from("students")
    .select(`
      *,
      fee_payments (*),
      daily_logs (*),
      homework (*),
      scores (*),
      session_progress (*),
      certificates (*),
      messages (*)
    `)
    .eq("center_id", centerId);
  if (studentsErr) throw studentsErr;

  const { data: announcements, error: annErr } = await supabase
    .from("announcements")
    .select("*")
    .eq("center_id", centerId)
    .order("announce_date", { ascending: false });
  if (annErr) throw annErr;

  const { data: batchMessages, error: bmErr } = await supabase
    .from("batch_messages")
    .select("*")
    .eq("center_id", centerId)
    .order("sent_at", { ascending: true });
  if (bmErr) throw bmErr;

  return { students, announcements, batchMessages };
}

// ---------- Students ----------
export async function addStudent(centerId, studentFields) {
  const { data, error } = await supabase
    .from("students")
    .insert([{ center_id: centerId, ...studentFields }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function updateStudent(studentId, fields) {
  const { data, error } = await supabase
    .from("students")
    .update(fields)
    .eq("id", studentId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Fees ----------
export async function addFeePayment(studentId, { amount, paid_on, note }) {
  const { data, error } = await supabase
    .from("fee_payments")
    .insert([{ student_id: studentId, amount, paid_on, note }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteFeePayment(paymentId) {
  const { error } = await supabase.from("fee_payments").delete().eq("id", paymentId);
  if (error) throw error;
}

// ---------- Homework ----------
export async function addHomework(studentId, { title, assigned_on, due_on }) {
  const { data, error } = await supabase
    .from("homework")
    .insert([{ student_id: studentId, title, assigned_on, due_on }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function verifyHomework(homeworkId, { verified_by, verify_photo_url }) {
  const { data, error } = await supabase
    .from("homework")
    .update({
      done: true,
      verified_by,
      verified_at: new Date().toISOString(),
      verify_photo_url,
    })
    .eq("id", homeworkId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Scores ----------
export async function addScore(studentId, { subject, test_name, test_date, marks, max_marks }) {
  const { data, error } = await supabase
    .from("scores")
    .insert([{ student_id: studentId, subject, test_name, test_date, marks, max_marks }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Daily logs ----------
export async function addDailyLog(studentId, { log_date, text }) {
  const { data, error } = await supabase
    .from("daily_logs")
    .insert([{ student_id: studentId, log_date, text }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Messages ----------
export async function sendMessage(studentId, { from_role, text }) {
  const { data, error } = await supabase
    .from("messages")
    .insert([{ student_id: studentId, from_role, text }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function sendBatchMessage(centerId, batch, { from_role, text }) {
  const { data, error } = await supabase
    .from("batch_messages")
    .insert([{ center_id: centerId, batch, from_role, text }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ---------- Announcements ----------
export async function addAnnouncement(centerId, { announce_date, text }) {
  const { data, error } = await supabase
    .from("announcements")
    .insert([{ center_id: centerId, announce_date, text }])
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteAnnouncement(announcementId) {
  const { error } = await supabase.from("announcements").delete().eq("id", announcementId);
  if (error) throw error;
}

// ---------- Parent PIN verification (never compare plaintext client-side) ----------
// Do the PIN check inside a Postgres RPC function (using pgcrypto's crypt())
// so the hash comparison happens server-side, not in the browser.
export async function verifyParentPin(studentId, pin) {
  const { data, error } = await supabase.rpc("check_parent_pin", {
    p_student_id: studentId,
    p_pin: pin,
  });
  if (error) throw error;
  return data === true;
}

// ---------- Photo upload (replaces base64 dataURL in localStorage) ----------
export async function uploadVerificationPhoto(studentId, blob) {
  const path = `verification/${studentId}/${Date.now()}.jpg`;
  const { error } = await supabase.storage.from("homework-photos").upload(path, blob, {
    contentType: "image/jpeg",
  });
  if (error) throw error;
  const { data } = supabase.storage.from("homework-photos").getPublicUrl(path);
  return data.publicUrl;
}
