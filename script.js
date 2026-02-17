// script.js - Converted to Module
import { supabase } from './supabase-fetch-client.js';
import { submitAppointment } from './db-service.js';

document.addEventListener('DOMContentLoaded', () => {
    // Mobile Menu Toggle
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mobileMenu = document.getElementById('mobile-menu');

    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', () => {
            mobileMenu.classList.toggle('hidden');
        });
    }

    // Global Auth State Listener (Supabase)
    supabase.auth.onAuthStateChange((event, session) => {
        if (session) {
            // User is signed in
            // console.log("User is signed in:", session.user.email);

            // If on login page, redirect to profile
            if (window.location.pathname.includes('login.html')) {
                window.location.href = 'profile.html';
            }
        } else {
            // User is signed out
            // console.log("User is signed out");

            // Redirect to login if on protected page
            if (window.location.pathname.includes('profile.html')) {
                window.location.href = 'login.html';
            }
        }
    });

    // Logout Helper (Global)
    window.logout = async function () {
        try {
            await supabase.auth.signOut();
            window.location.href = 'index.html';
        } catch (error) {
            console.error("Logout Error:", error);
        }
    };
    // Appointment Form Logic

    // Inquiry Form Logic (Updated for 10-Table Schema)
    const appointmentForm = document.getElementById('modal-appointment-form'); // Use the modal form ID
    if (appointmentForm) {
        appointmentForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = appointmentForm.querySelector('button[type="submit"]');
            const originalText = btn.textContent;
            btn.textContent = 'Submitting...';
            btn.disabled = true;

            // Extract values
            const parentName = appointmentForm.querySelector('[name="parent_name"]').value;
            const childName = appointmentForm.querySelector('[name="child_name"]').value;
            const childAge = appointmentForm.querySelector('[name="child_age"]').value;
            const email = appointmentForm.querySelector('[name="email"]').value;
            const phone = appointmentForm.querySelector('[name="phone"]').value;
            const message = appointmentForm.querySelector('[name="message"]').value;

            const formData = {
                name: parentName, // Maps to 'name' in inquiries
                email: email,
                phone: phone,
                message: message,
                child_info: `Child: ${childName}, Age: ${childAge}` // Combine for DB
            };

            try {
                // Import dynamically to ensure module loading
                const { submitInquiry } = await import('./db-service.js');
                await submitInquiry(formData);

                alert('Request submitted successfully! We will contact you shortly.');
                appointmentForm.reset();
                toggleBookingModal(); // Close modal
            } catch (error) {
                console.error("Submission Error:", error);
                alert('Failed to submit request. Please try again.');
            } finally {
                btn.textContent = originalText;
                btn.disabled = false;
            }
        });
    }
});
