-- Database Constraints to match client-side validation logic

-- 1. Users Table: Ensure email format
ALTER TABLE public.users
ADD CONSTRAINT users_email_check 
CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- 2. Inquiries Table: Ensure email and phone formats
ALTER TABLE public.inquiries
ADD CONSTRAINT inquiries_email_check 
CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$');

ALTER TABLE public.inquiries
ADD CONSTRAINT inquiries_phone_check
CHECK (phone IS NULL OR phone ~* '^\+?[\d\s\-()]{7,20}$');

-- 3. Students Table: Ensure DOB is not in the future
ALTER TABLE public.students
ADD CONSTRAINT students_dob_check
CHECK (dob IS NULL OR dob <= CURRENT_DATE);

-- 4. Invoices Table: Ensure amount is positive and due date is reasonable
ALTER TABLE public.invoices
ADD CONSTRAINT invoices_amount_check
CHECK (amount > 0);

ALTER TABLE public.invoices
ADD CONSTRAINT invoices_due_date_check
CHECK (due_date IS NULL OR due_date >= DATE(created_at));
