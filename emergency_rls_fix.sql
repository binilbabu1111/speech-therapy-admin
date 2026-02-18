-- EMERGENCY RLS BYPASS & FIX (VERSION 3.5 - IDEMPOTENCY FIX)
-- Run this in Supabase SQL Editor

-- 1. CLEANUP: Drop all problematic policies to start fresh
DROP POLICY IF EXISTS "Admins can manage everything" ON public.users;
DROP POLICY IF EXISTS "Admins can view all data" ON public.users;
DROP POLICY IF EXISTS "Admins can update users" ON public.users;
DROP POLICY IF EXISTS "Admins can delete users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users can promote themselves" ON public.users;

-- 2. ROBUST ADMIN CHECK FUNCTION (Avoids Recursion)
-- SECURITY DEFINER means it runs with the privileges of the function creator (postgres)
-- and thus bypasses RLS when querying the 'users' table.
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. CHICKEN-AND-EGG FIX: Allow users to insert their initial profile
DROP POLICY IF EXISTS "Allow self-registration" ON public.users;
CREATE POLICY "Allow self-registration" ON public.users 
  FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. SELF-PROMOTION FIX: Allow users to update their own record
-- This is needed so that the Admin Key in the UI can promote the user.
DROP POLICY IF EXISTS "Allow self-update" ON public.users;
CREATE POLICY "Allow self-update" ON public.users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 5. ADMIN CONTROL: Use the safe function to grant full access
DROP POLICY IF EXISTS "Admin full access" ON public.users;
CREATE POLICY "Admin full access" ON public.users
  FOR ALL USING (public.check_is_admin());

-- 6. APPLY TO RELATED TABLES
DROP POLICY IF EXISTS "Admins can manage everything" ON public.parents;
CREATE POLICY "Admins can manage everything" ON public.parents FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Admins can manage everything" ON public.students;
CREATE POLICY "Admins can manage everything" ON public.students FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Admins can manage everything" ON public.therapists;
CREATE POLICY "Admins can manage everything" ON public.therapists FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Therapists manage own profile" ON public.therapists;
DROP POLICY IF EXISTS "Therapists view own profile" ON public.therapists;
DROP POLICY IF EXISTS "Therapists insert own profile" ON public.therapists;
DROP POLICY IF EXISTS "Therapists update own profile" ON public.therapists;
DROP POLICY IF EXISTS "Therapists manage own" ON public.therapists;
CREATE POLICY "Therapists manage own" ON public.therapists 
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage everything" ON public.appointments;
CREATE POLICY "Admins can manage everything" ON public.appointments FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Admins can manage everything" ON public.therapy_plans;
CREATE POLICY "Admins can manage everything" ON public.therapy_plans FOR ALL USING (public.check_is_admin());

DROP POLICY IF EXISTS "Admins can manage everything" ON public.session_notes;
CREATE POLICY "Admins can manage everything" ON public.session_notes FOR ALL USING (public.check_is_admin());

-- 7. Ensure all users are 'active' so selectors work
UPDATE public.users SET status = 'active' WHERE status IS NULL;
