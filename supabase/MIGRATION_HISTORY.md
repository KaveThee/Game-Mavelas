# Database migration recovery

The hosted Game Mavelas database contains legacy migrations that were applied
before the repository adopted `supabase/migrations/`. Their SQL sources remain
in the parent `supabase/` directory. Do not run `supabase db push` against the
hosted project until the legacy history has been baselined with `supabase db
pull` and verified using a local `supabase db reset`.

## Known hosted history

The hosted migration ledger was audited on 2026-10-12. It contains 32 entries,
from `20260917080151_pre_phase_security_foundation` through
`20261007030012_trivia_dash_foundation`.

The named loose SQL sources cover the major schema changes:

- `pre_phase_security_foundation.sql`
- `display_first_rooms.sql`
- `flag_frenzy_difficulty_rounds.sql`
- `phase4_who_am_i.sql` and `who_am_i_common_faces.sql`
- `phase5_clue_heist.sql` and `clue_heist_expansion_and_svg_reveals.sql`
- `phase6_trivia_vault.sql` and `trivia_vault_branch_selection.sql`
- `fix_host_lobby_authority.sql` and `fix_display_host_handoff.sql`
- `gameplay_reveal_question_rotation.sql`
- `defer_points_until_reveal.sql`
- `fix_answer_shuffle_auto_reveal.sql`
- `all_game_modes_rotation_and_shuffle.sql`
- `game_mode_interaction_corrections.sql`
- `optimize_game_start_rotation.sql`
- `automatic_round_flow.sql`
- `balanced_answer_shuffle.sql`
- `include_host_in_answer_completion.sql`
- `results_replay_and_lobby.sql`
- `configurable_flag_rounds.sql`
- `who_am_i_clipboard_and_logo_rush.sql`

The base objects that predate the hosted ledger are in `schema.sql`,
`game_content.sql`, `seed_content.sql`, `game_engine.sql`,
`shared_screen_core.sql`, and `phase3_game_engine.sql`.

## Safe recovery procedure

1. Link the CLI to the hosted project.
2. Run `supabase migration list` and compare it to the hosted ledger.
3. Pull a reviewed remote schema baseline. Do not repair or delete hosted
   migration records merely to make the lists appear equal.
4. Start the local Supabase stack and run `supabase db reset`.
5. Verify room creation, every RPC signature, RLS grants, triggers, Realtime
   publication membership, and representative content.
6. Only after the reset succeeds should future migrations be pushed remotely.

The Phase 1 migration is intentionally additive and does not rewrite the
hosted migration ledger.
