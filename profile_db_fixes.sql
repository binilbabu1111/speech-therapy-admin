-- ============================================================
-- PROFILE PAGE DATABASE FIXES
-- Run this in Supabase SQL Editor to enable all profile features
-- ============================================================

-- ──────────────────────────────────────────────
-- 1. MESSAGES TABLE (new)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id uuid REFERENCES auth.users(id) NOT NULL,
    recipient_id uuid REFERENCES auth.users(id) NOT NULL,
    content text NOT NULL,
    read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users can read their own messages (sent or received)
CREATE POLICY "Users read own messages" ON public.messages
    FOR SELECT TO authenticated
    USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Users can send messages (insert where they are the sender)
CREATE POLICY "Users send messages" ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = sender_id);

-- Users can mark their received messages as read
CREATE POLICY "Users update own messages" ON public.messages
    FOR UPDATE TO authenticated
    USING (auth.uid() = recipient_id);

-- Admins full access
CREATE POLICY "Admins full access messages" ON public.messages
    FOR ALL TO authenticated
    USING (public.is_admin());

-- ──────────────────────────────────────────────
-- 2. ADD invoice_number TO invoices
-- ──────────────────────────────────────────────
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS invoice_number text;

-- ──────────────────────────────────────────────
-- 3. AUTO-CREATE PARENT RECORD ON USER INSERT
-- ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.auto_create_parent()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create parent record for 'parent' role users
    IF NEW.role = 'parent' OR NEW.role IS NULL THEN
        INSERT INTO public.parents (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if any, then create
DROP TRIGGER IF EXISTS trigger_auto_create_parent ON public.users;
CREATE TRIGGER trigger_auto_create_parent
    AFTER INSERT ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_create_parent();

-- ──────────────────────────────────────────────
-- 4. BACKFILL: Create parent records for existing parent users who lack one
-- ──────────────────────────────────────────────
INSERT INTO public.parents (user_id)
SELECT u.id FROM public.users u
LEFT JOIN public.parents p ON p.user_id = u.id
WHERE p.id IS NULL
  AND (u.role = 'parent' OR u.role IS NULL OR u.role = 'user')
ON CONFLICT (user_id) DO NOTHING;

-- ──────────────────────────────────────────────
-- 5. RLS POLICIES FOR PARENT DATA ACCESS
-- ──────────────────────────────────────────────

-- Parents can read students linked to their parent record
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own students' AND tablename = 'students') THEN
        CREATE POLICY "Parents read own students" ON public.students
            FOR SELECT TO authenticated
            USING (
                parent_id IN (
                    SELECT id FROM public.parents WHERE user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Parents can read appointments for their children
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

-- Parents can read therapy plans for their children
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

-- Parents can read documents for their children
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

-- Parents can read their own invoices
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents read own invoices' AND tablename = 'invoices') THEN
        CREATE POLICY "Parents read own invoices" ON public.invoices
            FOR SELECT TO authenticated
            USING (
                parent_id IN (
                    SELECT id FROM public.parents WHERE user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Admins full access to all relevant tables (idempotent)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full students' AND tablename = 'students') THEN
        CREATE POLICY "Admins full students" ON public.students FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full appointments' AND tablename = 'appointments') THEN
        CREATE POLICY "Admins full appointments" ON public.appointments FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full therapy_plans' AND tablename = 'therapy_plans') THEN
        CREATE POLICY "Admins full therapy_plans" ON public.therapy_plans FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full documents' AND tablename = 'documents') THEN
        CREATE POLICY "Admins full documents" ON public.documents FOR ALL TO authenticated USING (public.is_admin());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins full invoices' AND tablename = 'invoices') THEN
        CREATE POLICY "Admins full invoices" ON public.invoices FOR ALL TO authenticated USING (public.is_admin());
    END IF;
END $$;

-- Parents can also insert into parents table (for self-registration)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Parents insert own' AND tablename = 'parents') THEN
        CREATE POLICY "Parents insert own" ON public.parents
            FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

-- ──────────────────────────────────────────────
-- DONE! All profile features should now work.
-- ──────────────────────────────────────────────
