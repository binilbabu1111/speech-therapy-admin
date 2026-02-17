-- ============================================================
-- PROFILE PAGE DATABASE FIXES (v2 – works with actual deployed schema)
-- Run this in Supabase SQL Editor to enable all profile features
-- ============================================================

-- ──────────────────────────────────────────────
-- 1. CREATE MISSING TABLES (idempotent – won't break if they already exist)
-- ──────────────────────────────────────────────

-- Add display_name column to users if it doesn't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS display_name text;

-- PARENTS
CREATE TABLE IF NOT EXISTS public.parents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    address text,
    emergency_contact text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;

-- STUDENTS (Children)
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

-- THERAPISTS
CREATE TABLE IF NOT EXISTS public.therapists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) NOT NULL UNIQUE,
    license_number text,
    specialization text,
    availability jsonb,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.therapists ENABLE ROW LEVEL SECURITY;

-- INQUIRIES (supplement to old appointments/contact form)
CREATE TABLE IF NOT EXISTS public.inquiries (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    email text,
    phone text,
    message text,
    child_info text,
    status text DEFAULT 'New',
    follow_up_date date,
    admin_notes text,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- Add student_id and therapist_id to appointments if they don't exist
-- (Migrates the old contact-form table to also support scheduled therapy)
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS student_id uuid REFERENCES public.students(id);
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS therapist_id uuid REFERENCES public.therapists(id);
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS date_time timestamptz;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS mode text DEFAULT 'In-Person';
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS notes text;
-- Ensure status column exists (it does, but default might differ)
-- Normalize: old rows have status 'new', new ones use 'Scheduled'

-- THERAPY PLANS
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

-- SESSION NOTES
CREATE TABLE IF NOT EXISTS public.session_notes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    appointment_id uuid REFERENCES public.appointments(id) NOT NULL,
    therapist_id uuid REFERENCES public.therapists(id),
    notes text NOT NULL,
    progress_score integer,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.session_notes ENABLE ROW LEVEL SECURITY;

-- INVOICES
CREATE TABLE IF NOT EXISTS public.invoices (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_id uuid REFERENCES public.parents(id) NOT NULL,
    amount decimal(10,2) NOT NULL,
    status text DEFAULT 'Pending',
    due_date date,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS invoice_number text;

-- DOCUMENTS
CREATE TABLE IF NOT EXISTS public.documents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid REFERENCES public.students(id),
    file_url text NOT NULL,
    type text,
    uploaded_at timestamptz DEFAULT now()
);
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- MESSAGES
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id uuid REFERENCES auth.users(id) NOT NULL,
    recipient_id uuid REFERENCES auth.users(id) NOT NULL,
    content text NOT NULL,
    read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;


-- ──────────────────────────────────────────────
-- 2. AUTO-CREATE PARENT RECORD ON USER INSERT
-- ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.auto_create_parent()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.role = 'parent' OR NEW.role IS NULL OR NEW.role = 'user' THEN
        INSERT INTO public.parents (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_auto_create_parent ON public.users;
CREATE TRIGGER trigger_auto_create_parent
    AFTER INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_create_parent();

-- Backfill: create parent records for existing users who lack one
INSERT INTO public.parents (user_id)
SELECT u.id FROM public.users u
LEFT JOIN public.parents p ON p.user_id = u.id
WHERE p.id IS NULL
  AND (u.role = 'parent' OR u.role IS NULL OR u.role = 'user')
ON CONFLICT (user_id) DO NOTHING;


-- ──────────────────────────────────────────────
-- 3. RLS POLICIES (all idempotent)
-- ──────────────────────────────────────────────

-- === USERS TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users insert own' AND tablename = 'users') THEN
        CREATE POLICY "Users insert own" ON public.users
            FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users update own' AND tablename = 'users') THEN
        CREATE POLICY "Users update own" ON public.users
            FOR UPDATE TO authenticated USING (id = auth.uid());
    END IF;
END $$;

-- === PARENTS TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own' AND tablename = 'parents') THEN
        CREATE POLICY "Parents read own" ON public.parents
            FOR SELECT TO authenticated USING (user_id = auth.uid());
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents insert own' AND tablename = 'parents') THEN
        CREATE POLICY "Parents insert own" ON public.parents
            FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

-- === STUDENTS TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own students' AND tablename = 'students') THEN
        CREATE POLICY "Parents read own students" ON public.students
            FOR SELECT TO authenticated
            USING (parent_id IN (SELECT id FROM public.parents WHERE user_id = auth.uid()));
    END IF;
END $$;

-- === APPOINTMENTS TABLE (now has student_id after ALTER above) ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own appointments' AND tablename = 'appointments') THEN
        CREATE POLICY "Parents read own appointments" ON public.appointments
            FOR SELECT TO authenticated
            USING (
                student_id IN (
                    SELECT s.id FROM public.students s
                    JOIN public.parents p ON p.id = s.parent_id
                    WHERE p.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- === THERAPY PLANS TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own therapy plans' AND tablename = 'therapy_plans') THEN
        CREATE POLICY "Parents read own therapy plans" ON public.therapy_plans
            FOR SELECT TO authenticated
            USING (
                student_id IN (
                    SELECT s.id FROM public.students s
                    JOIN public.parents p ON p.id = s.parent_id
                    WHERE p.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- === DOCUMENTS TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own documents' AND tablename = 'documents') THEN
        CREATE POLICY "Parents read own documents" ON public.documents
            FOR SELECT TO authenticated
            USING (
                student_id IN (
                    SELECT s.id FROM public.students s
                    JOIN public.parents p ON p.id = s.parent_id
                    WHERE p.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- === SESSION NOTES TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own session notes' AND tablename = 'session_notes') THEN
        CREATE POLICY "Parents read own session notes" ON public.session_notes
            FOR SELECT TO authenticated
            USING (
                appointment_id IN (
                    SELECT a.id FROM public.appointments a
                    JOIN public.students s ON s.id = a.student_id
                    JOIN public.parents p ON p.id = s.parent_id
                    WHERE p.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- === INVOICES TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own invoices' AND tablename = 'invoices') THEN
        CREATE POLICY "Parents read own invoices" ON public.invoices
            FOR SELECT TO authenticated
            USING (parent_id IN (SELECT id FROM public.parents WHERE user_id = auth.uid()));
    END IF;
END $$;

-- === MESSAGES TABLE ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users read own messages' AND tablename = 'messages') THEN
        CREATE POLICY "Users read own messages" ON public.messages
            FOR SELECT TO authenticated
            USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users send messages' AND tablename = 'messages') THEN
        CREATE POLICY "Users send messages" ON public.messages
            FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users update own messages' AND tablename = 'messages') THEN
        CREATE POLICY "Users update own messages" ON public.messages
            FOR UPDATE TO authenticated USING (auth.uid() = recipient_id);
    END IF;
END $$;

-- === ADMIN FULL ACCESS (all tables) ===
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full parents' AND tablename = 'parents') THEN
        CREATE POLICY "Admins full parents" ON public.parents FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full students' AND tablename = 'students') THEN
        CREATE POLICY "Admins full students" ON public.students FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full therapy_plans' AND tablename = 'therapy_plans') THEN
        CREATE POLICY "Admins full therapy_plans" ON public.therapy_plans FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full session_notes' AND tablename = 'session_notes') THEN
        CREATE POLICY "Admins full session_notes" ON public.session_notes FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full documents' AND tablename = 'documents') THEN
        CREATE POLICY "Admins full documents" ON public.documents FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full invoices' AND tablename = 'invoices') THEN
        CREATE POLICY "Admins full invoices" ON public.invoices FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full messages' AND tablename = 'messages') THEN
        CREATE POLICY "Admins full messages" ON public.messages FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full inquiries' AND tablename = 'inquiries') THEN
        CREATE POLICY "Admins full inquiries" ON public.inquiries FOR ALL TO authenticated USING (public.is_admin());
    END IF;
END $$;

-- ──────────────────────────────────────────────
-- DONE! All profile features should now work.
-- Refresh profile.html after running this.
-- ──────────────────────────────────────────────
