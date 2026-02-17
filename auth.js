import { supabase } from './supabase-config.js';
import { upsertUser } from './db-service.js';

// State (kept if needed for internal logic, but largely unused now)
let isLogin = true;

// Utility to switch auth mode (pure logic if needed, or remove)
// Keeping it simple for now since login.html handles the UI toggling.


// Exported functions for use in other modules
export async function handleAuth(mode, email, password, name, role = 'user') {
    try {
        let error;
        let userData;

        if (mode === 'login') {
            const { data, error: signInError } = await supabase.auth.signInWithPassword({
                email,
                password
            });
            error = signInError;
            userData = data.user;

            if (!error && userData) {
                // Determine if we need to upsert user on login? 
                // Usually only needed if data changed, but good for 'last_login'
                await upsertUser(userData);
            }
        } else {
            const { data, error: signUpError } = await supabase.auth.signUp({
                email,
                password,
                options: {
                    data: {
                        full_name: name,
                        role: role // Pass role to metadata
                    }
                }
            });
            error = signUpError;
            userData = data.user;

            if (!error && userData) {
                // Pass role to upsertUser
                await upsertUser(userData, { role: role });
                alert("Registration successful! Please check your email to confirm your account.");
                // return; // Stop here if email confirmation is enabled
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
