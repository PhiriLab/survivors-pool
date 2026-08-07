# Phiri Product Intelligence Layer (PPIL) v1

Survivors Pool should use privacy-minimal product telemetry through PPIL rather than direct vendor calls.

Initial useful events: `pool.session_started`, `pool.pick_viewed`, `pool.pick_submitted`, `pool.pick_changed`, `pool.round_viewed`, `pool.leaderboard_viewed`, `pool.error`.

Do not send names, email addresses, authentication tokens, Supabase identifiers, or free text to analytics. Use an anonymous/pseudonymous PPIL identifier where measurement requires continuity. Session replay remains off until masking and consent are explicitly configured.

Architecture: `UI -> PPIL -> consent/redaction -> PostHog adapter`.
