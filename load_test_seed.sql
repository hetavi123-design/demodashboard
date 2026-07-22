-- ============================================================
-- LOAD TEST SEED — generates ~500 fake students under your real
-- center, each with realistic homework/scores/fees/logs volume.
-- Safe to run once; re-running will create duplicates, so only
-- run this in a scratch/test center, not your real Kaizen data.
-- ============================================================

-- Create a dedicated test center so this never touches your real Kaizen data
insert into centers (id, name, slug, plan)
values ('99999999-9999-9999-9999-999999999999', 'Load Test Center', 'load-test', 'scale')
on conflict (id) do nothing;

do $$
declare
  test_center_id uuid := '99999999-9999-9999-9999-999999999999';
  boards text[] := array['SSC', 'CBSE', 'ICSE', 'IGCSE'];
  grades text[] := array['5', '6', '7', '8', '9', '10'];
  subjects text[] := array['Maths', 'Science', 'English', 'History', 'Social Science'];
  first_names text[] := array['Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Reyansh','Ayaan','Krishna','Ishaan',
                               'Ananya','Diya','Saanvi','Aadhya','Kiara','Myra','Sara','Aanya','Pari','Riya'];
  last_names text[] := array['Shah','Patel','Kulkarni','Sharma','Mehta','Iyer','Nair','Reddy','Joshi','Desai'];
  new_student_id uuid;
  i int;
  j int;
  batch_name text;
begin
  for i in 1..500 loop
    batch_name := boards[1 + (i % 4)] || '-' || grades[1 + (i % 6)];

    insert into students (
      center_id, name, grade, board, batch, parent_name, phone, school, source,
      registered_on, fees_status, fees_total, attendance_present, attendance_total
    ) values (
      test_center_id,
      first_names[1 + (i % 20)] || ' ' || last_names[1 + (i % 10)],
      grades[1 + (i % 6)],
      boards[1 + (i % 4)],
      batch_name,
      'Parent of ' || first_names[1 + (i % 20)],
      '9' || lpad((800000000 + i)::text, 9, '0'),
      'School ' || (1 + (i % 15)),
      (array['Referral','Instagram','Walk-in','Google'])[1 + (i % 4)],
      current_date - (random() * 60)::int,
      (array['Paid','Due'])[1 + (i % 2)],
      20000 + (i % 5) * 3000,
      15 + (i % 10),
      24
    ) returning id into new_student_id;

    -- ~2 fee payments per student
    for j in 1..2 loop
      insert into fee_payments (student_id, amount, paid_on, note)
      values (new_student_id, 10000 + (j * 5000), current_date - (j * 20), 'Installment ' || j);
    end loop;

    -- ~10 daily logs
    for j in 1..10 loop
      insert into daily_logs (student_id, log_date, text)
      values (new_student_id, current_date - j, 'Class covered topic ' || j || ' for ' || batch_name);
    end loop;

    -- ~5 homework items
    for j in 1..5 loop
      insert into homework (student_id, title, assigned_on, due_on, done)
      values (new_student_id, 'Homework item ' || j, current_date - j, current_date - j + 3, (j % 2 = 0));
    end loop;

    -- ~8 scores
    for j in 1..8 loop
      insert into scores (student_id, subject, test_name, test_date, marks, max_marks)
      values (new_student_id, subjects[1 + (j % 5)], 'Unit Test ' || j, current_date - (j * 10), 40 + (random() * 55)::int, 100);
    end loop;

    -- ~3 messages
    for j in 1..3 loop
      insert into messages (student_id, from_role, text, sent_at)
      values (new_student_id, (array['teacher','parent'])[1 + (j % 2)], 'Message ' || j, now() - (j || ' days')::interval);
    end loop;
  end loop;
end $$;

-- Quick sanity check on volume created
select
  (select count(*) from students where center_id = '99999999-9999-9999-9999-999999999999') as students,
  (select count(*) from fee_payments fp join students s on s.id = fp.student_id where s.center_id = '99999999-9999-9999-9999-999999999999') as fee_payments,
  (select count(*) from daily_logs dl join students s on s.id = dl.student_id where s.center_id = '99999999-9999-9999-9999-999999999999') as daily_logs,
  (select count(*) from homework h join students s on s.id = h.student_id where s.center_id = '99999999-9999-9999-9999-999999999999') as homework,
  (select count(*) from scores sc join students s on s.id = sc.student_id where s.center_id = '99999999-9999-9999-9999-999999999999') as scores,
  (select count(*) from messages m join students s on s.id = m.student_id where s.center_id = '99999999-9999-9999-9999-999999999999') as messages;
