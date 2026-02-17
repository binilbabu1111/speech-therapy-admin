-- ============================================================
-- SAMPLE TEST DATA for Profile Page
-- Run this in Supabase SQL Editor AFTER running profile_db_fixes.sql
-- ============================================================

-- Insert test children for the FIRST parent in the system
-- (This dynamically finds your parent record)
INSERT INTO public.students (parent_id, first_name, last_name, dob, grade, diagnosis, therapy_status)
SELECT 
    p.id,
    'Aarav',
    'John',
    '2018-06-15',
    'Grade 1',
    'Speech Sound Disorder – Articulation',
    'Active'
FROM public.parents p
LIMIT 1;

INSERT INTO public.students (parent_id, first_name, last_name, dob, grade, diagnosis, therapy_status)
SELECT 
    p.id,
    'Meera',
    'John',
    '2020-11-22',
    'Pre-K',
    'Expressive Language Delay',
    'Waiting'
FROM public.parents p
LIMIT 1;

-- Add a sample therapist (linked to admin or standalone)
INSERT INTO public.therapists (user_id, specialization, license_number)
SELECT id, 'Speech-Language Pathology', 'SLP-2024-001'
FROM public.users
WHERE role = 'admin'
LIMIT 1
ON CONFLICT (user_id) DO NOTHING;

-- Add sample appointments for the first child
INSERT INTO public.appointments (student_id, therapist_id, date_time, mode, status)
SELECT 
    s.id,
    t.id,
    NOW() + interval '3 days',
    'In-Person',
    'Scheduled'
FROM public.students s
JOIN public.parents p ON p.id = s.parent_id
CROSS JOIN public.therapists t
WHERE s.first_name = 'Aarav'
LIMIT 1;

INSERT INTO public.appointments (student_id, therapist_id, date_time, mode, status)
SELECT 
    s.id,
    t.id,
    NOW() - interval '7 days',
    'Online',
    'Completed'
FROM public.students s
JOIN public.parents p ON p.id = s.parent_id
CROSS JOIN public.therapists t
WHERE s.first_name = 'Aarav'
LIMIT 1;

INSERT INTO public.appointments (student_id, therapist_id, date_time, mode, status)
SELECT 
    s.id,
    t.id,
    NOW() + interval '10 days',
    'In-Person',
    'Scheduled'
FROM public.students s
JOIN public.parents p ON p.id = s.parent_id
CROSS JOIN public.therapists t
WHERE s.first_name = 'Meera'
LIMIT 1;

-- Add a therapy plan for the first child
INSERT INTO public.therapy_plans (student_id, therapist_id, goals, start_date, status)
SELECT 
    s.id,
    t.id,
    ARRAY['Improve /r/ sound production', 'Increase sentence length to 5+ words', 'Reduce phonological processes'],
    CURRENT_DATE - interval '30 days',
    'Active'
FROM public.students s
JOIN public.parents p ON p.id = s.parent_id
CROSS JOIN public.therapists t
WHERE s.first_name = 'Aarav'
LIMIT 1;

-- Add a sample invoice
INSERT INTO public.invoices (parent_id, amount, status, due_date, invoice_number)
SELECT 
    p.id,
    150.00,
    'Pending',
    CURRENT_DATE + interval '14 days',
    'INV-2026-001'
FROM public.parents p
LIMIT 1;

INSERT INTO public.invoices (parent_id, amount, status, due_date, invoice_number)
SELECT 
    p.id,
    150.00,
    'Paid',
    CURRENT_DATE - interval '16 days',
    'INV-2026-002'
FROM public.parents p
LIMIT 1;

-- Add a sample document
INSERT INTO public.documents (student_id, file_url, type)
SELECT 
    s.id,
    'https://example.com/consent-form.pdf',
    'Consent'
FROM public.students s
WHERE s.first_name = 'Aarav'
LIMIT 1;

-- ──────────────────────────────────────────────
-- DONE! Refresh profile.html to see the test data.
-- ──────────────────────────────────────────────
