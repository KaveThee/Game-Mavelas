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
