import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../supabase/migrations/20261012164739_phase1_runtime_stabilization.sql", import.meta.url),
  "utf8",
);
const controller = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");

test("new participants are rejected after a game starts while reconnects stay possible", () => {
  assert.match(migration, /if v_existing_role is null[\s\S]*v_room\.status <> 'lobby'/i);
  assert.match(migration, /game has already started/i);
  assert.match(migration, /if v_existing_role is not null then[\s\S]*is_connected = true/i);
});

test("display rooms include a non-scoring spectator lifecycle member", () => {
  assert.match(migration, /'Shared display', 'spectator'/i);
  assert.match(migration, /role <> 'spectator'/i);
  assert.match(display, /auto_reveal_round/);
  assert.match(display, /auto_advance_round/);
  assert.match(display, /room\?\.game_mode === "trivia_dash"/);
});

test("room status and phase combinations are normalized", () => {
  assert.match(migration, /normalize_room_lifecycle_before_write/i);
  assert.match(migration, /new\.status = 'results'[\s\S]*new\.phase := 'results'/i);
  assert.match(migration, /new\.status = 'playing'[\s\S]*new\.phase := 'playing'/i);
});

test("controllers poll for recovery and no longer hide Clue Heist countdowns", () => {
  assert.match(controller, /recoveryPoll/);
  assert.match(controller, /Connection interrupted\. Reconnecting/);
  assert.doesNotMatch(controller, /secondsRemaining !== null && !isRevealed && !isClueHeist/);
  assert.doesNotMatch(display, /!isLobby && !isResults && !isClueHeist/);
});
