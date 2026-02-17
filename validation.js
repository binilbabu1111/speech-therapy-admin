/**
 * Centralized Validation Service for JisWorld
 * Provides reusable validation logic and UI helpers
 */

const validators = {
    isRequired: (val) => val !== null && val !== undefined && val.toString().trim().length > 0,
    isEmail: (val) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val),
    isPhone: (val) => !val || /^\+?[\d\s\-()]{7,20}$/.test(val),
    isDate: (val) => !isNaN(Date.parse(val)),
    isMinLength: (val, min) => val.length >= min,
    isMaxLength: (val, max) => val.length <= max,
    passwordsMatch: (p1, p2) => p1 === p2,
    passwordStrength: (val) => val.length >= 8 // Basic check, can be expanded
};

/**
 * UI Helper: Show or clear error for a specific field
 */
const toggleError = (fieldId, message, isValid) => {
    const field = document.getElementById(fieldId);
    const errorArea = document.getElementById(`err-${fieldId}`);

    if (!field) return;

    if (isValid) {
        field.classList.remove('input-error');
        if (errorArea) {
            errorArea.textContent = '';
            errorArea.classList.remove('visible');
        }
    } else {
        field.classList.add('input-error');
        if (errorArea) {
            errorArea.textContent = message;
            errorArea.classList.add('visible');
        }
    }
    return isValid;
};

/**
 * Reset all errors in a container
 */
const clearAllErrors = (containerSelector = 'body') => {
    const container = document.querySelector(containerSelector);
    if (!container) return;

    container.querySelectorAll('.field-error').forEach(el => {
        el.textContent = '';
        el.classList.remove('visible');
    });
    container.querySelectorAll('.input-error').forEach(el => {
        el.classList.remove('input-error');
    });
    const mainError = container.querySelector('.auth-error, .form-error');
    if (mainError) mainError.classList.remove('visible');
};

/**
 * Initialize real-time error clearing on input
 */
const initRealTimeValidation = (containerSelector = 'body') => {
    const container = document.querySelector(containerSelector);
    if (!container) return;

    container.querySelectorAll('input, textarea, select').forEach(input => {
        input.addEventListener('input', () => {
            toggleError(input.id, '', true);
        });
    });
};

export { validators, toggleError, clearAllErrors, initRealTimeValidation };
