-- 🔴 RESET AND INITIALIZE DATABASE (v1)
-- This script will DROP existing tables to ensure a clean slate for the new 10-table architecture.
-- WARNING: This deletes existing data in these tables.

-- 1. DROP OLD TABLES (to resolve naming conflicts)
DROP TABLE IF EXISTS public.session_notes CASCADE;
DROP TABLE IF EXISTS public.therapy_plans CASCADE;
DROP TABLE IF EXISTS public.assignments CASCADE; -- cleanup if exists
DROP TABLE IF EXISTS public.sessions CASCADE;     -- cleanup previous v2
DROP TABLE IF EXISTS public.appointments CASCADE; -- cleanup old contact form table
DROP TABLE IF EXISTS public.inquiries CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.documents CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.parents CASCADE;
DROP TABLE IF EXISTS public.therapists CASCADE;
-- We do NOT drop public.users to preserve Admin access links, 
-- but we ensure the table structure is correct below.

-- 2. CREATE NEW SCHEMA (10 Tables)

-- 10. DOCUMENTS (Moved up to avoid dependency issues if referenced later? No, usually last)
-- (Standard Order)

-- 1. USERS (Extends Supabase Auth)
CREATE TABLE IF NOT EXISTS public.users (
    id uuid REFERENCES auth.users(id) PRIMARY KEY,
    name text, -- Full name (synced from Auth)
    email text UNIQUE NOT NULL,
    phone text,
    role text DEFAULT 'parent', -- 'admin', 'therapist', 'parent', 'reception'
    status text DEFAULT 'active',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. PARENTS
CREATE TABLE IF NOT EXISTS public.parents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    address text,
    emergency_contact text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;

-- 3. STUDENTS
CREATE TABLE IF NOT EXISTS public.students (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_id uuid REFERENCES public.parents(id),
    first_name text NOT NULL,
    last_name text NOT NULL,
    dob date,
    grade text,
    diagnosis text,
    therapy_status text DEFAULT 'Active', 
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- 4. THERAPISTS
CREATE TABLE IF NOT EXISTS public.therapists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    license_number text,
    specialization text,
    availability jsonb,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.therapists ENABLE ROW LEVEL SECURITY;

-- 5. INQUIRIES (New home for Contact Form data)
CREATE TABLE IF NOT EXISTS public.inquiries (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    email text,
    phone text,
    message text,
    child_info text,
    status text DEFAULT 'New', -- New, Contacted, Converted, Closed
    follow_up_date date,
    admin_notes text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- 6. APPOINTMENTS (New home for Therapy Sessions)
CREATE TABLE IF NOT EXISTS public.appointments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id),
    therapist_id uuid REFERENCES public.therapists(id),
    date_time timestamptz NOT NULL,
    mode text DEFAULT 'In-Person',
    status text DEFAULT 'Scheduled',
    notes text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- 7. THERAPY PLANS
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id) NOT NULL,
    therapist_id uuid REFERENCES public.therapists(id),
    goals text, -- Changed from array to text per user spec
    start_date date,
    end_date date,
    status text DEFAULT 'Active',
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.therapy_plans ENABLE ROW LEVEL SECURITY;

-- 8. SESSION NOTES
CREATE TABLE IF NOT EXISTS public.session_notes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    appointment_id uuid REFERENCES public.appointments(id) NOT NULL,
    therapist_id uuid REFERENCES public.therapists(id),
    notes text NOT NULL,
    progress_score integer,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.session_notes ENABLE ROW LEVEL SECURITY;

-- 9. INVOICES
CREATE TABLE IF NOT EXISTS public.invoices (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_id uuid REFERENCES public.parents(id) NOT NULL,
    amount decimal(10,2) NOT NULL,
    status text DEFAULT 'Pending',
    due_date date,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- 10. DOCUMENTS
CREATE TABLE IF NOT EXISTS public.documents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id),
    file_url text NOT NULL,
    type text, -- 'Assessment', 'IEP', 'Evaluation', 'Consent', 'Worksheet'
    uploaded_at timestamptz DEFAULT now()
);
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- 3. RLS POLICIES
-- Re-apply basic policies
CREATE POLICY "Public insert inquiries" ON public.inquiries FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Admins all inquiries" ON public.inquiries FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Users read own" ON public.users FOR SELECT USING (auth.uid() = id);
-- Add Admin override policy for Users if not exists
DROP POLICY IF EXISTS "Admins all users" ON public.users;
CREATE POLICY "Admins all users" ON public.users FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- Appointments Policies
CREATE POLICY "Admins all appointments" ON public.appointments FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);
