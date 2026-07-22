import { createClient } from "@supabase/supabase-js";

// These come from your Supabase project settings (Project Settings > API).
// Never hardcode the service_role key in frontend code — only the anon key belongs here.
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
