-- MASTER DATA SYNCHRONIZATION & RLS REFINEMENT
-- Version 1.0 - Automatic Role-Based Table Syncing

-- 1. TRIGGER FUNCTION: Sync User Data to Specialized Tables
-- This function runs after INSERT or UPDATE on public.users.
-- It ensures that if a user's role is 'therapist' or 'parent', 
-- a skeleton record exists in the corresponding table and stays in sync.
CREATE OR REPLACE FUNCTION public.handle_user_sync()
RETURNS trigger AS $$
BEGIN
    -- Sync to THERAPISTS table
    IF NEW.role = 'therapist' THEN
        INSERT INTO public.therapists (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
        
        -- Copy basic info for consistency (implementing "copy" requirement)
        -- Note: therapists table currently doesn't have email/name columns in schema_full_v1.sql
        -- so we rely on the user_id link for the UI, or we can add them here if schema is extended.
    END IF;

    -- Sync to PARENTS table
    IF NEW.role = 'parent' OR NEW.role = 'user' THEN
        INSERT INTO public.parents (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ATTACH TRIGGER
DROP TRIGGER IF EXISTS on_user_change_sync ON public.users;
CREATE TRIGGER on_user_change_sync
    AFTER INSERT OR UPDATE OF role ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_sync();

-- 3. RLS BYPASS FOR ADMINS (UNIFIED)
-- Re-applying the recursion-safe admin check from emergency_rls_fix.sql
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. PERMISSIVE POLICIES FOR SYNCED TABLES
-- Since the trigger handles the "Insert", we just need to ensure 
-- the user can UPDATE their own clinical/profile details later.

DROP POLICY IF EXISTS "Therapists manage own" ON public.therapists;
CREATE POLICY "Therapists manage own" ON public.therapists 
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Parents manage own" ON public.parents;
CREATE POLICY "Parents manage own" ON public.parents 
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ensure Admin has full access to these tables too
DROP POLICY IF EXISTS "Admin full access therapists" ON public.therapists;
CREATE POLICY "Admin full access therapists" ON public.therapists FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Admin full access parents" ON public.parents;
CREATE POLICY "Admin full access parents" ON public.parents FOR ALL USING (public.check_is_admin());

-- 5. RUN INITIAL SYNC
-- For existing users, force the trigger logic
INSERT INTO public.therapists (user_id)
SELECT id FROM public.users WHERE role = 'therapist'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.parents (user_id)
SELECT id FROM public.users WHERE role IN ('parent', 'user')
ON CONFLICT (user_id) DO NOTHING;
