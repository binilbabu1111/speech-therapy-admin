import { supabase } from './supabase-config.js';
import { upsertUser } from './db-service.js';

// DOM Elements
const userNameDisp = document.getElementById('user-name');
const settingsName = document.getElementById('settings-name');
const settingsEmail = document.getElementById('settings-email');
const profileAvatar = document.getElementById('profile-avatar');

function init() {
    // Auth State Listener
    supabase.auth.onAuthStateChange(async (event, session) => {
        if (event === 'SIGNED_IN' || session) {
            const user = session.user;

            // Populate data
            const displayName = user.user_metadata.full_name || user.email.split('@')[0];
            userNameDisp.textContent = displayName;
            settingsName.value = displayName;
            settingsEmail.value = user.email;

            if (user.user_metadata.avatar_url) {
                profileAvatar.src = user.user_metadata.avatar_url;
            }

            // Sync with DB
            upsertUser(user);

            // Simulate Stats
            document.getElementById('days-streak').textContent = '3';
            document.getElementById('games-played').textContent = '12';
            document.getElementById('stories-read').textContent = '8';
        } else if (event === 'SIGNED_OUT') {
            window.location.href = 'login.html';
        }
    });

    // Check initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
        if (!session) {
            window.location.href = 'login.html';
        }
    });

    // Expose global functions
    window.switchTab = switchTab;
    window.handleAvatarUpload = handleAvatarUpload;
    window.updateProfile = updateProfileHandler;
    window.logout = logout;
}

function switchTab(tabId) {
    document.querySelectorAll('.nav-tab').forEach(btn => btn.classList.remove('active'));
    const clickedBtn = Array.from(document.querySelectorAll('.nav-tab')).find(btn => btn.getAttribute('onclick').includes(tabId));
    if (clickedBtn) clickedBtn.classList.add('active');

    document.querySelectorAll('.tab-content').forEach(content => content.classList.add('hidden'));
    document.getElementById('tab-' + tabId).classList.remove('hidden');
}

function handleAvatarUpload(event) {
    alert("Avatar upload requires Supabase Storage bucket setup. Feature coming soon.");
}

async function updateProfileHandler(e) {
    e.preventDefault();
    const newName = settingsName.value;

    try {
        const { data: { user } } = await supabase.auth.getUser();

        if (user) {
            const { error } = await supabase.auth.updateUser({
                data: { full_name: newName }
            });

            if (error) throw error;

            // Update UI
            userNameDisp.textContent = newName;

            // Sync to DB
            upsertUser(user, { display_name: newName });

            alert('Profile updated successfully!');
        }
    } catch (error) {
        console.error("Update Error:", error);
        alert(error.message);
    }
}

async function logout() {
    try {
        await supabase.auth.signOut();
        window.location.href = 'index.html';
    } catch (error) {
        console.error("Logout Error:", error);
    }
}

document.addEventListener('DOMContentLoaded', init);
