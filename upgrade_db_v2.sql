-- PHASE 2: ADMIN PANEL EXPANSION DB UPGRADE

-- 1. ENHANCE EXISTING 'appointments' TABLE (Serving as INQUIRIES)
-- We treat these as "Leads" or "Inquiries"
ALTER TABLE public.appointments 
ADD COLUMN IF NOT EXISTS admin_notes text,
ADD COLUMN IF NOT EXISTS follow_up_date date,
ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS inquiry_type text DEFAULT 'General'; -- e.g. 'Speech', 'Stuttering'

-- 2. CREATE NEW 'sessions' TABLE (For Scheduled Therapy)
-- This corresponds to Module 4: Appointment Management (Calendar)
CREATE TABLE IF NOT EXISTS public.sessions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    
    student_id uuid REFERENCES public.users(id), -- If student is registered
    therapist_id uuid REFERENCES public.users(id),
    
    start_time timestamptz NOT NULL,
    end_time timestamptz NOT NULL,
    
    title text NOT NULL, -- e.g. "Speech Therapy - John Doe"
    session_type text DEFAULT 'In-Person', -- or 'Online'
    status text DEFAULT 'scheduled', -- scheduled, completed, cancelled, no-show
    
    notes text -- Private session notes
);

-- 3. RLS FOR SESSIONS
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins full access to sessions"
ON public.sessions
FOR ALL
TO authenticated
USING (public.is_admin());

-- Therapists can view/edit their own sessions
-- (Assuming we will have an is_therapist check later, for now just use ID match)
CREATE POLICY "Therapists view assigned sessions"
ON public.sessions
FOR SELECT
TO authenticated
USING (auth.uid() = therapist_id OR public.is_admin());

-- Parents (Users) can view their own child's sessions
CREATE POLICY "Parents view own sessions"
ON public.sessions
FOR SELECT
TO authenticated
USING (auth.uid() = student_id OR public.is_admin());
