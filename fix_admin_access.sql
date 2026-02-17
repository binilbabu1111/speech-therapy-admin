-- Make 'active' the default for RLS policies (treating NULL as active)
ALTER POLICY "Users can view own data" ON public.users
USING (auth.uid() = id AND (status = 'active' OR status IS NULL));

ALTER POLICY "Users can update own data" ON public.users
USING (auth.uid() = id AND (status = 'active' OR status IS NULL));

-- Update the admin check function to allow NULL status
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() 
    AND role = 'admin' 
    AND (status = 'active' OR status IS NULL)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Explicitly set the admin user to 'active' just in case
UPDATE public.users 
SET status = 'active' 
WHERE role = 'admin' AND (status IS NULL OR status = 'blocked');
