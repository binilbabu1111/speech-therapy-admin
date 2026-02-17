import { supabase, verifySupabaseConnection } from './supabase-fetch-client.js?v=5';
import { upsertUser, completeRegistrationProfile } from './db-service.js?v=5';


// Utility for Supabase library calls to prevent indefinite hangs
const withTimeout = (promise, ms = 10000) => {
    const timeout = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Connectivity Timeout: Please check your network or try again later.')), ms)
    );
    return Promise.race([promise, timeout]);
};

// State (kept if needed for internal logic, but largely unused now)
let isLogin = true;

// Utility to switch auth mode (pure logic if needed, or remove)
// Keeping it simple for now since login.html handles the UI toggling.


// Exported functions for use in other modules
export async function handleAuth(mode, email, password, name, additionalInfo = {}) {
    const role = additionalInfo.role || 'user';
    try {
        let error;
        let userData;

        if (mode === 'login') {
            // Pre-flight check
            const isConnected = await verifySupabaseConnection();
            if (!isConnected) throw new Error("Could not connect to Supabase. Check your internet connection.");

            const { data, error: signInError } = await withTimeout(supabase.auth.signInWithPassword({
                email,
                password
            }));
            error = signInError;
            userData = data.user;

            if (!error && userData) {
                // Determine if we need to upsert user on login? 
                await upsertUser(userData);
            }
        } else {
            // Pre-flight check
            const isConnected = await verifySupabaseConnection();
            if (!isConnected) throw new Error("Could not connect to Supabase. Check your internet connection.");

            const { data, error: signUpError } = await withTimeout(supabase.auth.signUp({
                email,
                password,
                options: {
                    data: {
                        full_name: name,
                        role: role,
                        ...additionalInfo // Store everything in metadata too
                    }
                }
            }));
            error = signUpError;
            userData = data.user;

            if (!error && userData) {
                // Pass all additionalInfo to upsertUser (sanitized inside)
                await upsertUser(userData, { role, ...additionalInfo });

                // If sign up, complete the profile with parent/child records
                await completeRegistrationProfile(userData.id, additionalInfo);

                alert("Registration successful! Please check your email to confirm your account.");
            }
        }

        if (error) throw error;

        // Redirect based on role or default
        if (role === 'admin' || email.includes('admin')) {
            window.location.href = 'admin.html';
        } else {
            window.location.href = 'profile.html';
        }

    } catch (error) {
        console.error("Auth Error:", error);
        throw error; // Re-throw for UI to handle
    }
}

export async function handleGoogleLogin() {
    try {
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: window.location.origin + '/profile.html'
            }
        });
        if (error) throw error;
    } catch (error) {
        console.error("Google Auth Error:", error);
        alert(error.message);
    }
}

// Global Auth State Listener (Supabase)
// We can keep this here or move it to a shared 'app.js'
supabase.auth.onAuthStateChange(async (event, session) => {
    if (session) {
        const { data: userProfile } = await supabase
            .from('users')
            .select('status')
            .eq('id', session.user.id)
            .single();

        if (userProfile && userProfile.status === 'blocked') {
            await supabase.auth.signOut();
            alert("Your session has been ended by an administrator.");
            window.location.href = 'login.html';
        }
    }
});
