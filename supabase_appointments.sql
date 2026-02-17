-- Create appointments table
CREATE TABLE public.appointments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamptz DEFAULT now(),
    parent_name text NOT NULL,
    child_name text,
    email text NOT NULL,
    phone text,
    child_age text,
    message text,
    status text DEFAULT 'new'
);

-- Enable RLS
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (for the contact form)
CREATE POLICY "Allow public insert to appointments"
ON public.appointments
FOR INSERT
TO anon
WITH CHECK (true);

-- Allow admins to view all appointments
CREATE POLICY "Allow admins to view appointments"
ON public.appointments
FOR SELECT
TO authenticated
USING (public.is_admin());

-- Allow admins to update appointments (e.g., mark as read)
CREATE POLICY "Allow admins to update appointments"
ON public.appointments
FOR UPDATE
TO authenticated
USING (public.is_admin());
