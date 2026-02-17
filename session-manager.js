import { supabase } from './supabase-fetch-client.js';

const INACTIVITY_LIMIT = 15 * 60 * 1000; // 15 minutes
let inactivityTimer;

/**
 * Initializes session management:
 * 1. Checks if user is blocked.
 * 2. Sets up auto-logout on inactivity.
 */
export async function initSessionManagement() {
    // 1. Check User Status & Auth State
    const { data: { session } } = await supabase.auth.getSession();

    if (session) {
        // Check if user is blocked
        const { data: userProfile, error } = await supabase
            .from('users')
            .select('status')
            .eq('id', session.user.id)
            .single();

        if (userProfile && userProfile.status === 'blocked') {
            await logout("Your session has been ended by an administrator.");
            return;
        }

        // 2. Setup Auto-Logout
        setupInactivityTimer();
    }
}

/**
 * Sets up listeners to reset the inactivity timer.
 */
function setupInactivityTimer() {
    window.onload = resetTimer;
    document.onmousemove = resetTimer;
    document.onkeypress = resetTimer;
    document.onclick = resetTimer;
    document.onscroll = resetTimer;
    resetTimer(); // Start timer
}

/**
 * Resets the inactivity timer.
 */
function resetTimer() {
    clearTimeout(inactivityTimer);
    inactivityTimer = setTimeout(async () => {
        await logout("You have been logged out due to inactivity. Please log in again.");
    }, INACTIVITY_LIMIT);
}

/**
 * Logs out the user and redirects to home.
 * @param {string} [message] - Optional message to show before redirect.
 */
export async function logout(message) {
    await supabase.auth.signOut();
    if (message) alert(message);
    window.location.href = 'index.html';
}

// Initialize on load
document.addEventListener('DOMContentLoaded', initSessionManagement);

// Expose logout globally for buttons
window.logout = () => logout();
