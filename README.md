# CourtSide — Basketball Stats Tracker

Target Android emulator or physical device. Tested on Flutter 3.41.2.

## Demo accounts

The app seeds two accounts on first launch:

| Role | Email | Password |
|------|-------|----------|
| Super Admin | superadmin@courtside.app | SuperAdmin@2026 |
| Coach | coach@courtside.app | Coach@2026 |

Admin accounts are created by the Super Admin through the app.

## Architecture

- **Pattern:** MVVM with Repository
- **State management:** Riverpod (Notifier, AsyncNotifier, StreamProvider)
- **Routing:** go_router with role-based redirects
- **Database:** SQLite via drift ORM with streaming queries
- **Charts:** fl_chart for analytics visualizations
- **PDF:** pdf + printing for report generation
- **Sharing:** share_plus + screenshot for image-based social sharing
- **Auth:** SHA-256 + per-user 16-byte random salt with constant-time verify

## Roles & permissions

- **Coach** — Self-registers via signup. Full CRUD on their own teams, players, and games. Live stat tracking. Analytics and exports. Each coach only sees their own data.
- **Admin** — Created by Super Admin. View-only oversight of all coaches. Can disable/enable coach accounts and flag teams or games for Super Admin review.
- **Super Admin** — Single hardcoded account. Manages admins (create/reset/delete). Reviews flag queue (dismiss or delete-target). Can delete any coach, team, or game with cascade.

## Features

### Coach
- Reactive dashboard with live counts and recent activity feed
- Teams and players CRUD with cascade deletes
- Game creation with automatic stat row initialization for all roster players
- **Live game recording** — tap action buttons for 2pt/3pt/FT made/miss; separate opponent score strip; single-step undo
- End-game flow with auto-detected win/loss based on scores
- Game summary with computed FG%, 3P%, FT% per player
- Season analytics with W/L cards, points-per-game bar chart, leaderboard
- Player profile with shooting percentages and per-game history chart
- PDF export for game summary, season analytics, and player profile (save / print / share)
- Screenshot share for game summaries via system share sheet (social, messaging)

### Admin
- System overview dashboard with cross-coach counts
- Coach search and drill-down (read-only)
- Disable/enable coach accounts (reversible toggle)
- Flag teams or games for Super Admin review with required reason

### Super Admin
- Admin CRUD with manual or auto-generated passwords
- Coach delete (cascades all teams, players, games, stats)
- Flag queue with dismiss or delete-target actions
- Surgical delete of individual teams or games

## Tech notes

### Why drift + streaming queries

Every list and counter in the UI auto-updates when underlying data changes. Drift's `.watch()` returns a Stream that re-emits whenever queried tables change. Riverpod's StreamProvider consumes this and rebuilds dependent widgets. Net effect: no manual refresh, no pull-to-refresh, no stale UI anywhere in the app.

### Why plain Dart models alongside drift's generated rows

Drift generates row classes (`User`, `Team`, etc.). We additionally define plain Dart models (`AppUser`, `Team`) that the UI consumes. Repositories handle conversion. This keeps drift's schema concerns out of the UI layer — if we changed databases later, only repositories would need to change.

### Computed statistics

FG%, 3P%, FT%, total points, season averages — never persisted. Always computed at runtime from raw counts (2pt made/missed, 3pt made/missed, FT made/missed) by `StatsCalculator`. Single source of truth, no risk of stored derived data drifting from underlying counts.

### Password security

SHA-256 with per-user 16-byte random salt, stored as `salt$hash`. Constant-time comparison on verify. No plaintext storage anywhere — Super Admin's "reset password" generates a new hash, never reveals the old one.

### Disabled-account enforcement

Login query filters out disabled users at the SQL level — disabled coaches receive the same "no account found" error as a nonexistent email. Already-logged-in users have their session cleared on next app open via `loadSession`'s isDisabled check.

## Schema

Six tables with foreign-key cascades:

- `users` (id, name, email, password_hash, role, is_disabled, created_at)
- `teams` (id, name, season, coach_id → users)
- `players` (id, name, jersey_number, position, team_id → teams)
- `games` (id, opponent, date, home_away, is_finished, result, opponent_score, team_id → teams, created_at)
- `game_stats` (id, game_id → games, player_id → players, twoPtMade, twoPtMissed, threePtMade, threePtMissed, ftMade, ftMissed)
- `flags` (id, target_type, target_id, reason, flagged_by_admin_id → users, flagged_at, resolved, resolved_by_super_admin_id → users, resolved_at)

Stats rows are pre-initialized at game creation time so live game logging is always an UPDATE, never an INSERT.

## Known limitations

- Single-step undo on live game (intentional per spec)
- No offline cloud sync — fully local SQLite
- PDF charts rendered as text tables (better for print than embedded images)

## Course

CSE489 Mobile App Development, Spring 2026, BRAC University
