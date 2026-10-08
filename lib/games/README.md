# Mavelas game modules

This directory is the Phase 0 boundary between the persistent Mavelas room shell and individual games.

## Invariants

- The laptop route remains display-only.
- The first phone claims the host role atomically.
- Only the host selects and starts games.
- Public display state never contains answer keys, secret identities, private media, or player-only payloads.
- Supabase remains authoritative for phases, timestamps, scores, reconnect snapshots, Replay, and End Game.
- New games stay `planned` until their module, database rules, recovery behavior, and multi-device tests are complete.

## Module rule

Expansion games implement `GameModule` from `types.ts`. Classics remain on their existing RPCs until each mode has regression coverage and can be migrated without changing behavior.

`state-boundaries.ts` defines separate display and controller envelopes. The display also rejects controller-only keys and answer data that appears before the reveal phase. This is a client-side fail-closed check layered on top of the sanitized public RPCs and RLS.

Run `pnpm test:phase0` after changing the registry, collections, game availability, or state boundary rules.

`module-loader.ts` refuses unknown, duplicate, disabled, or unloaded modules. `session-lifecycle.ts` defines legal coarse phase changes, monotonic state versions, and action sequencing. Its in-memory action ledger is the module contract used by tests; production persistence must enforce the same rules transactionally with unique client action IDs in Postgres.

## Trivia Dash

`trivia-dash/module.ts` is the first expansion module. It uses simultaneous answers, fixed movement for correct answers, and a small every-third-correct streak bonus. Response speed never changes movement. All players receive a result before the server advances the round, and reaching the final tile early does not end the shared question set.

The eight rejected concepts are intentionally absent from the registry: Mafia Mayhem, Rhythm Rumble, Speed Racers, Zombie Survival, Stealth Heist, Dance Off, Laugh Out Loud, and Spatial Stackers.
