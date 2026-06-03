// Template. The real Secrets.swift is gitignored and generated from the repo-root
// .env by ios/gen-secrets.sh (also run automatically as a build phase).
//
//   cd ios && ./gen-secrets.sh
//
enum Secrets {
    static let supabaseURL = "https://YOUR-REF.supabase.co"
    static let supabaseAnonKey = "sb_publishable_XXXXXXXX"   // client publishable/anon key
}
