-- RLS Fixes for Admin Panel and Seeding
-- Run this in the Supabase SQL Editor

-- 1. Allow Admins to insert into 'users' table 
-- (Necessary for seeding and managing team members)
DROP POLICY IF EXISTS "Admins can insert users" ON public.users;
CREATE POLICY "Admins can insert users" ON public.users
  FOR INSERT WITH CHECK (public.is_admin());

-- 2. Allow users to insert their own profile even if they aren't 'active' yet
-- (The existing policy might be blocked by other constraints or missing WITH CHECK)
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. Ensure Admins can view and update everything in 'parents', 'students', 'appointments'
-- (This ensures the admin dashboard can actually see and link the seeded data)

-- PARENTS
DROP POLICY IF EXISTS "Admins can manage parents" ON public.parents;
CREATE POLICY "Admins can manage parents" ON public.parents
  FOR ALL USING (public.is_admin());

-- STUDENTS
DROP POLICY IF EXISTS "Admins can manage students" ON public.students;
CREATE POLICY "Admins can manage students" ON public.students
  FOR ALL USING (public.is_admin());

-- APPOINTMENTS
DROP POLICY IF EXISTS "Admins can manage appointments" ON public.appointments;
CREATE POLICY "Admins can manage appointments" ON public.appointments
  FOR ALL USING (public.is_admin());

-- INVOICES
DROP POLICY IF EXISTS "Admins can manage invoices" ON public.invoices;
CREATE POLICY "Admins can manage invoices" ON public.invoices
  FOR ALL USING (public.is_admin());

-- 4. Special Seeding Policy (TEMPORARY - Disable after use if preferred)
-- Allows anonymous seeding of the 'users' table if the ID follows a specific pattern
-- or just allow it for now to let the agent work.
-- CREATE POLICY "Seeding policy" ON public.users FOR INSERT WITH CHECK (true);
-- To be safe, let's just make the user an admin first then they can seed.
