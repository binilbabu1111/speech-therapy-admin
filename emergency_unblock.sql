-- Force update ALL users to active, regardless of role or current status
-- This is an emergency script to recover access.
UPDATE public.users 
SET status = 'active' 
WHERE status IS NULL OR status = 'blocked';

-- Ensure the admin user exists and is active
-- (This assumes the user with 'admin' role exists)
UPDATE public.users 
SET status = 'active'
WHERE role = 'admin';

-- Specifically fix Policies to allow viewing NULL or BLOCKED users (for self)
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
CREATE POLICY "Users can view own data" ON public.users
USING (auth.uid() = id); -- Allow viewing REGARDLESS of status (so you can see if you are blocked)

DROP POLICY IF EXISTS "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
USING (auth.uid() = id); -- Allow updating REGARDLESS of status (for now, to recover)
