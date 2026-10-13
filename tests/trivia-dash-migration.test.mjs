import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

const migrationDirectory = new URL("../supabase/migrations/", import.meta.url);

async function loadTriviaDashMigration() {
  const files = await readdir(migrationDirectory);
  const filename = files.find((file) => file.endsWith("_trivia_dash_foundation.sql"));
  assert.ok(filename, "Supabase CLI migration for Trivia Dash is missing");
  return readFile(new URL(filename, migrationDirectory), "utf8");
}

async function loadTriviaDashAnswerIsolationMigration() {
  const files = await readdir(migrationDirectory);
  const filename = files.find((file) => file.endsWith("_phase3_trivia_dash_answer_isolation.sql"));
  assert.ok(filename, "Phase 3 Trivia Dash answer isolation migration is missing");
  return readFile(new URL(filename, migrationDirectory), "utf8");
}

async function loadTriviaDashStartPerformanceMigration() {
  const files = await readdir(migrationDirectory);
  const filename = files.find((file) => file.endsWith("_phase3_trivia_dash_start_performance.sql"));
  assert.ok(filename, "Phase 3 Trivia Dash start performance migration is missing");
  return readFile(new URL(filename, migrationDirectory), "utf8");
}

async function loadTriviaDashDisplayFirstMigration() {
  const files = await readdir(migrationDirectory);
  const filename = files.find((file) => file.endsWith("_trivia_dash_display_first_sync.sql"));
  assert.ok(filename, "Trivia Dash display-first migration is missing");
  return readFile(new URL(filename, migrationDirectory), "utf8");
}

test("Trivia Dash migration is additive and leaves Classic RPC definitions untouched", async () => {
  const sql = await loadTriviaDashMigration();

  assert.doesNotMatch(sql, /create\s+or\s+replace\s+function\s+public\.start_game\s*\(/i);
  assert.doesNotMatch(sql, /create\s+or\s+replace\s+function\s+public\.auto_reveal_round\s*\(/i);
  assert.doesNotMatch(sql, /create\s+or\s+replace\s+function\s+public\.auto_advance_round\s*\(/i);
  assert.match(sql, /create\s+or\s+replace\s+function\s+public\.start_trivia_dash\s*\(/i);
  assert.match(sql, /create\s+or\s+replace\s+function\s+public\.reveal_trivia_dash_round\s*\(/i);
  assert.match(sql, /create\s+or\s+replace\s+function\s+public\.advance_trivia_dash_round\s*\(/i);
});

test("Trivia Dash private progress is protected by RLS and RPC-only grants", async () => {
  const sql = await loadTriviaDashMigration();

  assert.match(sql, /alter\s+table\s+public\.trivia_dash_player_state\s+enable\s+row\s+level\s+security/i);
  assert.match(sql, /revoke\s+all\s+on\s+table\s+public\.trivia_dash_player_state\s+from\s+anon,\s*authenticated/i);
  assert.match(sql, /revoke\s+all\s+on\s+function\s+public\.get_public_trivia_dash_state\(text\)\s+from\s+public,\s*anon/i);
  assert.match(sql, /grant\s+execute\s+on\s+function\s+public\.get_trivia_dash_player_state\(uuid\)\s+to\s+authenticated/i);
});

test("Trivia Dash scoring and round gates match the approved rules", async () => {
  const sql = await loadTriviaDashMigration();

  assert.match(sql, /dash\.position\s*\+\s*case[\s\S]*when\s+answer\.is_correct\s+then\s+2/i);
  assert.match(sql, /mod\(dash\.correct_streak\s*\+\s*1,\s*3\)\s*=\s*0\s+then\s+1/i);
  assert.match(sql, /last_scored_round\s*<\s*v_current_round\.position/i);
  assert.match(sql, /where\s+bucket_rank\s*<=\s*4/i);
  assert.match(sql, /if\s+v_position\s*<>\s*12/i);
  assert.doesNotMatch(sql, /speed[_\s-]*bonus/i);
});

test("public Trivia Dash state reveals answers only after the round is revealed", async () => {
  const sql = await loadTriviaDashMigration();
  const publicFunction = sql.match(
    /create\s+or\s+replace\s+function\s+public\.get_public_trivia_dash_state\(p_room_code text\)[\s\S]*?\n\$\$;/i,
  )?.[0];
  assert.ok(publicFunction, "Public Trivia Dash state RPC is missing");

  assert.match(publicFunction, /'is_correct',\s*case\s+when\s+round\.status\s*=\s*'revealed'/i);
  assert.match(publicFunction, /'correct_option',\s*case\s+when\s+round\.status\s*=\s*'revealed'/i);
  assert.doesNotMatch(publicFunction, /'correct_option_id'/i);
  assert.doesNotMatch(publicFunction, /'correct_streak'/i);
});

test("Trivia Dash answers use an isolated RPC with complete participant gating", async () => {
  const sql = await loadTriviaDashAnswerIsolationMigration();
  const controller = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");

  assert.match(sql, /create\s+or\s+replace\s+function\s+public\.submit_trivia_dash_answer\s*\(/i);
  assert.match(sql, /selected_game\s+is\s+distinct\s+from\s+'trivia_dash'/i);
  assert.match(sql, /rp\.role\s+in\s*\('host',\s*'player'\)/i);
  assert.match(sql, /dash\.player_id\s*=\s*v_user/i);
  assert.match(sql, /on\s+conflict\s*\(round_id,\s*player_id\)\s+do\s+nothing/i);
  assert.match(sql, /v_answer_count\s*>=\s*v_participant_count/i);
  assert.doesNotMatch(sql, /create\s+or\s+replace\s+function\s+public\.submit_game_answer\s*\(/i);
  assert.match(controller, /game_mode\s*===\s*"trivia_dash"[\s\S]*"submit_trivia_dash_answer"/i);
});

test("Trivia Dash start ranks narrow ids and validates only selected questions", async () => {
  const sql = await loadTriviaDashStartPerformanceMigration();
  const rankedQuery = sql.match(/with ranked_question_ids as \([\s\S]*?\n\s*loop/i)?.[0];
  assert.ok(rankedQuery, "Optimized Trivia Dash selection query is missing");

  assert.match(rankedQuery, /select\s+q\.id,/i);
  assert.match(rankedQuery, /row_number\(\)\s+over/i);
  assert.doesNotMatch(rankedQuery, /question_play_history/i);
  assert.doesNotMatch(rankedQuery, /select\s+count\(\*\)\s+from\s+public\.question_options/i);
  assert.match(sql, /if\s+v_option_count\s*<>\s*4\s+or\s+v_correct_count\s*<>\s*1/i);
  assert.match(sql, /if\s+v_position\s*<>\s*12/i);
});

test("Trivia Dash gives the display a server-authoritative lead on every round", async () => {
  const sql = await loadTriviaDashDisplayFirstMigration();
  const controller = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const display = await readFile(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");

  assert.match(sql, /alter function public\.start_trivia_dash\(uuid\) set schema private/i);
  assert.match(sql, /private\.start_trivia_dash_immediate\(p_room_id\)/i);
  assert.match(sql, /clock_timestamp\(\) \+ interval '4 seconds'/i);
  assert.match(sql, /v_closes_at := v_opens_at \+ interval '25 seconds'/i);
  assert.match(sql, /set round_ends_at = v_closes_at/i);
  assert.match(sql, /alter function public\.advance_trivia_dash_round\(uuid\) set schema private/i);
  assert.match(sql, /private\.advance_trivia_dash_round_immediate\(p_room_id\)/i);
  assert.match(sql, /alter function public\.submit_trivia_dash_answer\(uuid, uuid\) set schema private/i);
  assert.match(sql, /clock_timestamp\(\) < v_opens_at/i);
  assert.match(sql, /revoke all on function private\.start_trivia_dash_immediate\(uuid\) from public, anon, authenticated/i);
  assert.match(sql, /grant execute on function public\.submit_trivia_dash_answer\(uuid, uuid\) to authenticated/i);
  assert.match(controller, /isPreparingQuestion = isTriviaDash && secondsUntilOpen !== null && secondsUntilOpen > 0/);
  assert.match(controller, /Display gets the question first/);
  assert.match(display, /isQuestionPreview = isTriviaDash && secondsUntilOpen !== null && secondsUntilOpen > 0/);
  assert.match(display, /Players are looking up before their answer pads unlock/);
});
