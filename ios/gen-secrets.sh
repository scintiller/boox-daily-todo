#!/usr/bin/env bash
# Generate ios/DailyTodo/Secrets.swift from the repo-root .env (client keys only).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
set -a; . "$ROOT/.env"; set +a
cat > "$DIR/DailyTodo/Secrets.swift" <<EOF
// AUTO-GENERATED from ../.env by gen-secrets.sh — do not edit, do not commit.
enum Secrets {
    static let supabaseURL = "${SUPABASE_URL}"
    static let supabaseAnonKey = "${SUPABASE_ANON_KEY}"
}
EOF
echo "wrote $DIR/DailyTodo/Secrets.swift"
