import { supabase } from './supabase-fetch-client.js?v=3';

/**
 * Creates or updates a user record in the 'users' table.
 * @param {object} user - The Supabase auth user object.
 * @param {object} additionalData - Additional data like role.
 */
export async function upsertUser(user, additionalData = {}) {
    if (!user) return;

    // Sanitize updates: only include valid columns for the 'users' table
    const validColumns = ['id', 'email', 'display_name', 'phone', 'role', 'status', 'avatar_url'];
    const sanitizedUpdates = {
        id: user.id,
        email: user.email,
        display_name: user.user_metadata?.full_name || user.display_name || user.email.split('@')[0],
        updated_at: new Date()
    };

    // Only copy valid columns from additionalData
    Object.keys(additionalData).forEach(key => {
        if (validColumns.includes(key)) {
            sanitizedUpdates[key] = additionalData[key];
        }
    });

    const { error } = await supabase
        .from('users')
        .upsert(sanitizedUpdates);

    if (error) {
        console.error('Error upserting user:', error);
        throw error;
    }
}

/**
 * Completes the registration profile by creating parent and student records.
 * @param {string} userId - The user ID from auth.
 * @param {object} additionalInfo - Form data.
 */
export async function completeRegistrationProfile(userId, additionalInfo) {
    try {
        // 1. Ensure user is in 'users' table (upsertUser handled this, but we use its results)

        // 2. Create Parent Record
        const { data: parentData, error: parentError } = await supabase
            .from('parents')
            .upsert({
                user_id: userId,
                address: additionalInfo.address || null,
                emergency_contact: additionalInfo.phone || null // Using phone as emergency contact for now
            })
            .select()
            .single();

        if (parentError) throw parentError;

        // 3. Create Student Record if child info provided
        if (additionalInfo.child_name) {
            const [firstName, ...lastNames] = additionalInfo.child_name.split(' ');
            const { error: studentError } = await supabase
                .from('students')
                .insert({
                    parent_id: parentData.id,
                    first_name: firstName || 'Child',
                    last_name: lastNames.join(' ') || 'User',
                    dob: additionalInfo.child_dob || null,
                    diagnosis: additionalInfo.therapy_needs || null,
                    therapy_status: 'Active'
                });

            if (studentError) throw studentError;
        }
    } catch (error) {
        console.error('Error completing profile registration:', error);
        throw error;
    }
}

/**
 * Fetches all users from Supabase (for Admin Dashboard).
 * @returns {Promise<Array>} List of user objects.
 */
export async function getAllUsers() {
    const { data, error } = await supabase
        .from('users')
        .select('*')
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching users:', error);
        return [];
    }
    return data;
}

/**
 * Checks if a user has admin privileges.
 * @param {string} userId - The user's ID.
 * @returns {Promise<boolean>} True if admin.
 */
export async function checkAdminStatus(userId) {
    if (!userId) return false;

    // Check 'users' table regarding role
    const { data: users, error } = await supabase
        .from('users')
        .select('role')
        .eq('id', userId);

    if (error) {
        console.error("Check Admin Error:", error);
        return { isAdmin: false, error: error.message };
    }

    // Handle case where duplicate rows might exist (resiliency)
    const data = users && users.length > 0 ? users[0] : null;

    if (!data) {
        // Emergency: User might be logged in via Auth but not in 'users' table yet
        console.warn("User profile not found. Attempting to create one now...");
        const { data: { user } } = await supabase.auth.getUser();
        if (user && user.id === userId) {
            try {
                await upsertUser(user);
                // Retry fetch
                const { data: newUsers } = await supabase.from('users').select('role').eq('id', userId);
                if (newUsers && newUsers.length > 0) {
                    return { isAdmin: newUsers[0].role === 'admin', role: newUsers[0].role };
                }
            } catch (err) {
                console.error("Profile creation error details:", err);
                return { isAdmin: false, error: "Profile creation failed: " + err.message };
            }
        }
        console.error("User profile not found. User ID:", userId, "Auth User:", user);
        return { isAdmin: false, error: "User profile not found in database (creation failed or RLS blocked view)." };
    }
    return { isAdmin: data.role === 'admin', role: data.role };
}

/**
 * Deletes a user profile (Admin only).
 * @param {string} userId - The ID of the user to delete.
 */
export async function deleteUserById(userId) {
    const { error } = await supabase
        .from('users')
        .delete()
        .eq('id', userId);

    if (error) {
        console.error('Error deleting user:', error);
        throw error;
    }
}

/**
 * Updates a user's status (e.g., 'active' or 'blocked').
 * @param {string} userId - The user ID.
 * @param {string} status - The new status.
 */
export async function updateUserStatus(userId, status) {
    const { error } = await supabase
        .from('users')
        .update({ status: status })
        .eq('id', userId);

    if (error) {
        console.error('Error updating user status:', error);
        throw error;
    }
}

/**
 * Submits a new inquiry (Contact Form).
 * @param {object} inquiryData - The form data.
 */
export async function submitInquiry(inquiryData) {
    const { error } = await supabase
        .from('inquiries')
        .insert([inquiryData]);

    if (error) {
        console.error('Error submitting inquiry:', error);
        throw error;
    }
}

/**
 * Fetches all inquiries (Website Leads).
 * @returns {Promise<Array>} List of inquiries.
 */
export async function getInquiries() {
    const { data, error } = await supabase
        .from('inquiries')
        .select('*')
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching inquiries:', error);
        return [];
    }
    return data;
}

/**
 * Updates an inquiry status.
 * @param {string} id - Inquiry ID.
 * @param {object} updates - Status/Notes.
 */
export async function updateInquiry(id, updates) {
    const { error } = await supabase
        .from('inquiries')
        .update(updates)
        .eq('id', id);

    if (error) {
        console.error('Error updating inquiry:', error);
        throw error;
    }
}

/**
 * Fetches all therapy appointments (Sessions).
 * @returns {Promise<Array>} List of appointments.
 */
export async function getAppointments() {
    const { data, error } = await supabase
        .from('appointments')
        .select(`
            *,
            student:student_id (first_name, last_name),
            therapist:therapist_id (specialization)
        `)
        .order('date_time', { ascending: true });

    if (error) {
        console.warn('Error fetching appointments:', error);
        return [];
    }
    return data;
}

/**
 * Creates a new therapy appointment.
 * @param {object} appointmentData - Session details.
 */
export async function createAppointment(appointmentData) {
    const { error } = await supabase
        .from('appointments')
        .insert([appointmentData]);

    if (error) {
        console.error('Error creating appointment:', error);
        throw error;
    }
}

/**
 * Fetches all registered students.
 * @returns {Promise<Array>} List of students with parent info.
 */
export async function getStudents() {
    const { data, error } = await supabase
        .from('students')
        .select(`
            *,
            parent:parent_id (
                address,
                emergency_contact,
                user:user_id (name, email, phone)
            )
        `)
        .order('created_at', { ascending: false });

    if (error) {
        console.warn('Error fetching students:', error);
        return [];
    }
    return data;
}

/**
 * Creates a new student record.
 * @param {object} studentData - Student details.
 */
export async function createStudent(studentData) {
    const { error } = await supabase
        .from('students')
        .insert([studentData]);

    if (error) {
        console.error('Error creating student:', error);
        throw error;
    }
}

/**
 * Fetches all registered parents (for dropdowns).
 */
export async function getParents() {
    const { data, error } = await supabase
        .from('parents')
        .select(`
            id,
            user:user_id (name, email)
        `);

    if (error) {
        console.warn('Error fetching parents:', error);
        return [];
    }
    // Flatten result for easier use
    return data.map(p => ({
        id: p.id,
        name: p.user?.name || 'Unknown',
        email: p.user?.email
    }));
}

/**
 * Fetches all invoices.
 * @returns {Promise<Array>} List of invoices with parent details.
 */
export async function getInvoices() {
    const { data, error } = await supabase
        .from('invoices')
        .select(`
            *,
            parent:parent_id (
                user:user_id (name, email)
            )
        `)
        .order('due_date', { ascending: true });

    if (error) {
        console.warn('Error fetching invoices:', error);
        return [];
    }
    return data;
}

/**
 * Creates a new invoice.
 * @param {object} invoiceData - Invoice details.
 */
export async function createInvoice(invoiceData) {
    const { error } = await supabase
        .from('invoices')
        .insert([invoiceData]);

    if (error) {
        console.error('Error creating invoice:', error);
        throw error;
    }
}

/**
 * Updates an invoice status.
 * @param {string} id - Invoice ID.
 * @param {string} status - New status (Paid/Pending).
 */
export async function updateInvoiceStatus(id, status) {
    const { error } = await supabase
        .from('invoices')
        .update({ status: status })
        .eq('id', id);

    if (error) {
        console.error('Error updating invoice:', error);
        throw error;
    }
}

// ---------------------------------------------------------
// PHASE 2 MODULES (Therapy Plans, Notes, Documents)
// ---------------------------------------------------------

/**
 * Creates a therapy plan.
 */
export async function createTherapyPlan(planData) {
    const { error } = await supabase.from('therapy_plans').insert([planData]);
    if (error) throw error;
}

/**
 * Fetches therapy plans for a student.
 */
export async function getTherapyPlans(studentId) {
    const { data, error } = await supabase
        .from('therapy_plans')
        .select('*')
        .eq('student_id', studentId);
    if (error) return [];
    return data;
}

/**
 * Creates a session note.
 */
export async function createSessionNote(noteData) {
    const { error } = await supabase.from('session_notes').insert([noteData]);
    if (error) throw error;
}

/**
 * Fetches notes for an appointment.
 */
export async function getSessionNotes(appointmentId) {
    const { data, error } = await supabase
        .from('session_notes')
        .select('*')
        .eq('appointment_id', appointmentId);
    if (error) return [];
    return data;
}

/**
 * Uploads a document record (metadata only).
 * Actual file upload handled separately via storage.
 */
export async function createDocumentRecord(docData) {
    const { error } = await supabase.from('documents').insert([docData]);
    if (error) throw error;
}
