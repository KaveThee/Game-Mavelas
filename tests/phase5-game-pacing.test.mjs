import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../supabase/migrations/20261013232126_phase5_game_pacing.sql", import.meta.url),
  "utf8",
);
const controller = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");
const timing = readFileSync(new URL("../lib/games/timing.ts", import.meta.url), "utf8");
const styles = readFileSync(new URL("../app/globals.css", import.meta.url), "utf8");

test("shared-screen quiz modes receive a server-authoritative display lead", () => {
  assert.match(migration, /p_game_mode in \('trivia', 'flag_frenzy', 'logo_quiz'\) then 3/i);
  assert.match(migration, /v_first_opens_at := now\(\) \+ make_interval/i);
  assert.match(migration, /v_first_closes_at := v_first_opens_at \+ make_interval\(secs => v_first_duration\)/i);
  assert.match(migration, /v_closes_at := v_opens_at \+ make_interval\(secs => v_duration\)/i);
});

test("the database rejects answers before controllers are open", () => {
  assert.match(migration, /v_round\.opens_at is not null and now\(\) < v_round\.opens_at/i);
  assert.match(migration, /raise exception 'Answer pads are not open yet'/i);
});

test("round durations follow template pacing instead of question defaults", () => {
  assert.match(migration, /create or replace function private\.effective_round_duration/i);
  assert.match(migration, /sum\(rts\.question_count\) over \(order by rts\.position\)/i);
  assert.match(migration, /when 1 then 22[\s\S]*when 2 then 20[\s\S]*when 3 then 18/i);
  assert.match(migration, /v_duration := private\.effective_round_duration/i);
});

test("Trivia Vault scoring is normalized to its advertised tiers", () => {
  assert.match(migration, /q\.game_mode = 'trivia'[\s\S]*q\.difficulty <= 1 then 100[\s\S]*q\.difficulty = 2 then 150[\s\S]*else 200/i);
  assert.match(migration, /if not v_correct then v_points := 0/i);
});

test("controller and display share timing constants and preview every screen-first quiz", () => {
  assert.match(timing, /allAnswersHoldMs: 3_100/);
  assert.match(timing, /revealHoldMs: 6_200/);
  assert.match(timing, /"trivia"[\s\S]*"flag_frenzy"[\s\S]*"logo_quiz"[\s\S]*"trivia_dash"/);
  assert.match(controller, /hasDisplayFirstLead\(question\?\.game_mode\)/);
  assert.match(controller, /hasDisplayFirstLead\(serverState\.current_question\.game_mode\)/);
  assert.match(display, /hasDisplayFirstLead\(round\?\.game_mode\)/);
  assert.doesNotMatch(controller, /allInReady \? 3100 : 250/);
  assert.doesNotMatch(display, /room\.phase === "all_answered" \? 3100 : 250/);
});

test("game selection is serialized before Start can run", () => {
  assert.match(controller, /const \[isSelectingGame, setIsSelectingGame\] = useState\(false\)/);
  assert.match(controller, /if \(isSelectingGame \|\| isSubmitting\) return/);
  assert.match(controller, /disabled=\{isPlaying \|\| isSelectingGame \|\| !isGameEnabled\(chosenGame\)\}/);
});

test("phase transitions animate while respecting reduced-motion preferences", () => {
  assert.match(styles, /@keyframes phase-enter/);
  assert.match(styles, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(controller, /className="phase-enter rounded/);
  assert.match(display, /className="phase-enter min-h-0"/);
});
