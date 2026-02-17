-- MASTER SCHEMA V1
-- Implements the 10-table structure defined in the Project Specification.
-- RUN THIS IN SUPABASE SQL EDITOR

-- 1. USERS (Extends Supabase Auth)
-- We use public.users to store app-specific profile data linked to auth.users
CREATE TABLE IF NOT EXISTS public.users (
    id uuid REFERENCES auth.users(id) PRIMARY KEY,
    email text UNIQUE NOT NULL,
    display_name text,
    phone text,
    role text DEFAULT 'parent', -- 'admin', 'therapist', 'parent'
    status text DEFAULT 'active',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. PARENTS (Profile details for parent users)
CREATE TABLE IF NOT EXISTS public.parents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    address text,
    emergency_contact text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;

-- 3. STUDENTS (Children receiving therapy)
CREATE TABLE IF NOT EXISTS public.students (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_id uuid REFERENCES public.parents(id), -- Optional if parent not yet registered, but usually required
    first_name text NOT NULL,
    last_name text NOT NULL,
    dob date,
    grade text,
    diagnosis text,
    therapy_status text DEFAULT 'Active', -- 'Active', 'Waiting', 'Completed'
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- 4. THERAPISTS (Staff profiles)
CREATE TABLE IF NOT EXISTS public.therapists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    license_number text,
    specialization text,
    availability jsonb, -- structured availability data
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.therapists ENABLE ROW LEVEL SECURITY;

-- 5. INQUIRIES (Website Leads / Contact Form)
-- Renaming concept: was 'appointments' (old), now 'inquiries'
CREATE TABLE IF NOT EXISTS public.inquiries (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL, -- parent name
    email text,
    phone text,
    message text,
    child_info text, -- merged from child_name/age if needed
    status text DEFAULT 'New', -- 'New', 'Contacted', 'Converted', 'Closed'
    follow_up_date date,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- 6. APPOINTMENTS (Therapy Sessions)
-- Renaming concept: was 'sessions', now 'appointments'
CREATE TABLE IF NOT EXISTS public.appointments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id),
    therapist_id uuid REFERENCES public.therapists(id),
    date_time timestamptz NOT NULL,
    mode text DEFAULT 'In-Person', -- 'Online', 'In-Person'
    status text DEFAULT 'Scheduled', -- 'Scheduled', 'Completed', 'Cancelled'
    notes text, -- Brief admin notes
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- 7. THERAPY PLANS
CREATE TABLE IF NOT EXISTS public.therapy_plans (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id) NOT NULL,
    therapist_id uuid REFERENCES public.therapists(id),
    goals text[],
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
    notes text NOT NULL, -- Clinical notes
    progress_score integer, -- e.g. 1-10 or percentage
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.session_notes ENABLE ROW LEVEL SECURITY;

-- 9. INVOICES
CREATE TABLE IF NOT EXISTS public.invoices (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_id uuid REFERENCES public.parents(id) NOT NULL,
    amount decimal(10,2) NOT NULL,
    status text DEFAULT 'Pending', -- 'Paid', 'Pending', 'Overdue'
    due_date date,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- 10. DOCUMENTS
CREATE TABLE IF NOT EXISTS public.documents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id),
    file_url text NOT NULL,
    type text, -- 'Consent', 'Evaluation', 'IEP', 'Worksheet'
    uploaded_at timestamptz DEFAULT now()
);
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;


-- Enable RLS Policies (Simplified for MVP)

-- Allow public to submit inquiries
CREATE POLICY "Public insert inquiries" ON public.inquiries FOR INSERT TO anon WITH CHECK (true);

-- Admin has full access to everything
-- (Assuming is_admin() function exists from previous setup or we use role check)
-- For MVP, we'll iterate policies simply.

CREATE POLICY "Users read own" ON public.users FOR SELECT USING (auth.uid() = id);

-- Parents: Self read (via user_id)
CREATE POLICY "Parents read own" ON public.parents FOR SELECT USING (auth.uid() = user_id);

-- Students: Parent read (via parent_id)
-- Note: This requires joining or a known parent_id.
-- For now, enabling basic access.
