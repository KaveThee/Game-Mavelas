import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../supabase/migrations/20261012171831_fix_lobby_state_and_phase2_audit.sql", import.meta.url),
  "utf8",
);
const controller = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");
const spectatorMigration = readFileSync(
  new URL("../supabase/migrations/20261013061345_exclude_spectators_from_active_turns.sql", import.meta.url),
  "utf8",
);
const spectatorStateMigration = readFileSync(
  new URL("../supabase/migrations/20261013063001_filter_spectators_from_player_state.sql", import.meta.url),
  "utf8",
);
const performanceMigration = readFileSync(
  new URL("../supabase/migrations/20261013073202_phase2_foreign_key_indexes.sql", import.meta.url),
  "utf8",
);

test("fresh lobbies use typed state rows that are safe before a round exists", () => {
  assert.match(migration, /v_round public\.game_rounds%rowtype/i);
  assert.match(migration, /v_question public\.questions%rowtype/i);
  assert.match(migration, /v_answer public\.player_answers%rowtype/i);
  assert.doesNotMatch(migration, /v_round record/i);
  assert.match(migration, /current_question[\s\S]*case when v_round\.id is null then null/i);
});

test("entry navigation clears stale reconnect warnings", () => {
  assert.match(controller, /openEntryScreen[\s\S]*setConnectionError\(""\)/);
  assert.doesNotMatch(controller, /Phase 3 Live/);
});

test("display QR completion updates related state in one async callback", () => {
  assert.match(display, /\.then\(\(dataUrl\) => \{[\s\S]*setJoinHost\(currentHost\)[\s\S]*setQrDataUrl\(dataUrl\)/);
});

test("display spectators cannot own or submit interactive turns", () => {
  assert.match(spectatorMigration, /assign_who_am_i_player[\s\S]*role in \('host', 'player'\)/i);
  assert.match(spectatorMigration, /setup_clue_heist_round[\s\S]*role in \('host', 'player'\)/i);
  assert.match(spectatorMigration, /require_interactive_player_on_answers/i);
  assert.match(spectatorMigration, /require_interactive_player_on_who_clues/i);
  assert.match(spectatorMigration, /require_interactive_player_on_heist_attempts/i);
});

test("display spectators stay out of player totals and leaderboards", () => {
  assert.match(spectatorStateMigration, /rp\.role in \('host', 'player'\)/i);
  assert.match(spectatorStateMigration, /\{total_players\}/i);
  assert.match(spectatorStateMigration, /\{leaderboard\}/i);
});

test("known foreign keys are covered by dedicated indexes", () => {
  assert.equal((performanceMigration.match(/create index if not exists/g) ?? []).length, 7);
});
