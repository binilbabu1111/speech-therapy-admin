
/**
 * SUPABASE FETCH CLIENT (Workaround for library hangs)
 * This mock implements the essential methods of the Supabase client
 * using direct fetch calls to ensure performance and reliability.
 */

console.log("Supabase config module loading (Fetch Mock)...");

const supabaseUrl = 'https://hhrqjolqkuzwylypekhr.supabase.co';
const supabaseKey = 'sb_publishable_2WZKcFYxtVP8qtdsoLj82w_Jc551SaB';

class SupabaseFetchClient {
    constructor() {
        this.url = supabaseUrl;
        this.key = supabaseKey;
        this.authListeners = [];
        this.session = null;

        // Try to recover session from storage
        const stored = window.sessionStorage.getItem('supabase.auth.token');
        if (stored) {
            try { this.session = JSON.parse(stored); } catch (e) { }
        }

        this.auth = {
            signInWithPassword: async ({ email, password }) => {
                console.log("Mock Auth: signInWithPassword", email);
                const res = await fetch(`${this.url}/auth/v1/token?grant_type=password`, {
                    method: 'POST',
                    headers: { 'apikey': this.key, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });

                const text = await res.text();
                let data = {};
                if (text) {
                    try { data = JSON.parse(text); } catch (e) { console.error("Auth Parse Error", e); }
                }

                if (!res.ok) {
                    const errorMsg = data.message || data.msg || data.error_description || "Authentication failed";
                    return { data: { user: null }, error: { message: errorMsg, ...data } };
                }

                this._setSession(data);
                return { data: { user: data.user }, error: null };
            },

            signUp: async ({ email, password, options }) => {
                console.log("Mock Auth: signUp", email);
                const res = await fetch(`${this.url}/auth/v1/signup`, {
                    method: 'POST',
                    headers: { 'apikey': this.key, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password, data: options?.data || {} })
                });

                const text = await res.text();
                let data = {};
                if (text) {
                    try { data = JSON.parse(text); } catch (e) { console.error("Signup Parse Error", e); }
                }

                if (!res.ok) {
                    const errorMsg = data.message || data.msg || data.error_description || "Registration failed";
                    return { data: { user: null }, error: { message: errorMsg, ...data } };
                }

                this._setSession(data);
                return { data: { user: data.user }, error: null };
            },

            signOut: async () => {
                this._setSession(null);
                return { error: null };
            },

            getSession: async () => {
                return { data: { session: this.session }, error: null };
            },

            onAuthStateChange: (callback) => {
                this.authListeners.push(callback);
                // Initial call
                callback(this.session ? 'SIGNED_IN' : 'SIGNED_OUT', this.session);
                return {
                    data: {
                        subscription: {
                            unsubscribe: () => {
                                this.authListeners = this.authListeners.filter(l => l !== callback);
                            }
                        }
                    }
                };
            },

            getUser: async () => {
                if (!this.session) return { data: { user: null }, error: null };
                return { data: { user: this.session.user }, error: null };
            }
        };
    }

    _setSession(session) {
        this.session = session;
        if (session) {
            window.sessionStorage.setItem('supabase.auth.token', JSON.stringify(session));
        } else {
            window.sessionStorage.removeItem('supabase.auth.token');
        }
        this.authListeners.forEach(l => l(session ? 'SIGNED_IN' : 'SIGNED_OUT', session));
    }

    from(table) {
        const _this = this;

        // Internal state for the current query chain
        const query = {
            table: table,
            select: '*',
            filters: [],
            order: null,
            isSingle: false
        };

        const builder = {
            select: (columns = '*') => {
                query.select = columns;
                return builder;
            },
            eq: (column, value) => {
                query.filters.push(`${column}=eq.${value}`);
                return builder;
            },
            order: (column, { ascending = true } = {}) => {
                query.order = `${column}.${ascending ? 'asc' : 'desc'}`;
                return builder;
            },
            single: () => {
                query.isSingle = true;
                // Since this is a terminal call in Supabase, we execute it
                return builder.execute();
            },
            // Terminal method to actually run the fetch
            execute: async () => {
                let path = `${_this.url}/rest/v1/${query.table}?select=${query.select}`;
                if (query.filters.length > 0) {
                    path += `&${query.filters.join('&')}`;
                }
                if (query.order) {
                    path += `&order=${query.order}`;
                }

                const headers = {};
                if (query.isSingle) {
                    headers['Accept'] = 'application/vnd.pgrst.object+json';
                }

                return _this._dbRequest('GET', path, null, headers);
            },
            // Logic for INSERT/UPDATE/DELETE
            insert: (values) => {
                let path = `${_this.url}/rest/v1/${table}`;
                return _this._dbRequest('POST', path, values);
            },
            upsert: (values, options = {}) => {
                let path = `${_this.url}/rest/v1/${table}`;
                return _this._dbRequest('POST', path, values, { 'Prefer': 'resolution=merge-duplicates' });
            },
            update: (values) => {
                return {
                    eq: (column, value) => {
                        let path = `${_this.url}/rest/v1/${table}?${column}=eq.${value}`;
                        return _this._dbRequest('PATCH', path, values);
                    }
                };
            },
            delete: () => {
                return {
                    eq: (column, value) => {
                        let path = `${_this.url}/rest/v1/${table}?${column}=eq.${value}`;
                        return _this._dbRequest('DELETE', path);
                    }
                };
            }
        };

        // If we await the builder itself (e.g. `const {data} = await supabase.from('x').select('*')`)
        // we should make the builder thenable
        builder.then = (onFulfilled) => builder.execute().then(onFulfilled);

        return builder;
    }

    async _dbRequest(method, url, body = null, extraHeaders = {}) {
        const headers = {
            'apikey': this.key,
            'Authorization': `Bearer ${this.session?.access_token || this.key}`,
            'Content-Type': 'application/json',
            ...extraHeaders
        };

        try {
            const res = await fetch(url, {
                method,
                headers,
                body: body ? JSON.stringify(body) : null
            });

            if (res.status === 204) return { data: null, error: null };

            let data = null;
            const text = await res.text();
            if (text) {
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    console.error("Supabase Mock JSON Parse Error:", e, "Raw text:", text);
                    return { data: null, error: { message: "Invalid JSON response from server" } };
                }
            }

            if (!res.ok) return { data: null, error: data || { message: "Request failed" } };
            return { data, error: null };
        } catch (e) {
            console.error("Supabase Mock DB Error:", e);
            return { data: null, error: e };
        }
    }
}

export const supabase = new SupabaseFetchClient();

export async function verifySupabaseConnection() {
    try {
        const response = await fetch(`${supabaseUrl}/rest/v1/`, {
            headers: { 'apikey': supabaseKey }
        });
        console.log("Supabase Pre-flight Status:", response.status);
        // If we get a response (even 401), the server is reachable.
        // A 401 often happens if the project requires specific headers or has RLS.
        if (response.status === 401 || response.ok) return true;

        return false;
    } catch (e) {
        console.error("Supabase Pre-flight Fetch Error:", e);
        return false;
    }
}

console.log("Supabase config: Fetch Mock initialized.");
