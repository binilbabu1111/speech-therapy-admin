
console.log("Supabase config module loading...");
// import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const createClient = window.supabase.createClient;

// TODO: Replace with your actual Supabase project URL and Anon Key
const supabaseUrl = 'https://hhrqjolqkuzwylypekhr.supabase.co';
const supabaseKey = 'sb_publishable_2WZKcFYxtVP8qtdsoLj82w_Jc551SaB';

// Configure client to use sessionStorage (cleared on tab close)
export const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        storage: window.sessionStorage,
    },
});
