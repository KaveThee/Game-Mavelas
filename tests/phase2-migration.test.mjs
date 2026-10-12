import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

const migrationDirectory = new URL("../supabase/migrations/", import.meta.url);

async function loadPhase2Migration() {
  const files = await readdir(migrationDirectory);
  const filename = files.find((file) => file.endsWith("_phase2_private_action_foundation.sql"));
  assert.ok(filename, "Supabase CLI Phase 2 migration is missing");
  return readFile(new URL(filename, migrationDirectory), "utf8");
}

test("Phase 2 data stays in the private schema with RLS and no direct client grants", async () => {
  const sql = await loadPhase2Migration();
  for (const table of [
    "phase2_sessions",
    "phase2_submissions",
    "phase2_votes",
    "phase2_word_claims",
    "phase2_action_ledger",
  ]) {
    assert.match(sql, new RegExp(`create\\s+table\\s+private\\.${table}`, "i"));
    assert.match(sql, new RegExp(`alter\\s+table\\s+private\\.${table}\\s+enable\\s+row\\s+level\\s+security`, "i"));
    assert.match(sql, new RegExp(`revoke\\s+all\\s+on\\s+table\\s+private\\.${table}\\s+from\\s+public,\\s*anon,\\s*authenticated`, "i"));
  }
  assert.doesNotMatch(sql, /grant\s+(select|insert|update|delete|all)[\s\S]*phase2_/i);
});

test("Phase 2 action ledger enforces membership, exact sequencing, idempotency, and rate limits", async () => {
  const sql = await loadPhase2Migration();
  const actionFunction = sql.match(
    /create\s+or\s+replace\s+function\s+private\.claim_phase2_action[\s\S]*?\n\$\$;/i,
  )?.[0];
  assert.ok(actionFunction, "Private action claim helper is missing");
  assert.match(actionFunction, /role\s+in\s*\('host',\s*'player'\)/i);
  assert.match(actionFunction, /p_client_sequence\s*<>\s*v_previous_sequence\s*\+\s*1/i);
  assert.match(actionFunction, /when\s+unique_violation/i);
  assert.match(actionFunction, /interval\s+'10 seconds'/i);
  assert.match(actionFunction, /v_recent_actions\s*>=\s*12/i);
});

test("public Phase 2 state excludes secret state and player state is scoped to auth uid", async () => {
  const sql = await loadPhase2Migration();
  const publicFunction = sql.match(
    /create\s+or\s+replace\s+function\s+public\.get_public_phase2_state[\s\S]*?\n\$\$;/i,
  )?.[0];
  const playerFunction = sql.match(
    /create\s+or\s+replace\s+function\s+public\.get_phase2_player_state[\s\S]*?\n\$\$;/i,
  )?.[0];
  assert.ok(publicFunction);
  assert.ok(playerFunction);
  assert.doesNotMatch(publicFunction, /secret_state/);
  assert.doesNotMatch(publicFunction, /phase2_submissions/);
  assert.match(playerFunction, /v_user\s+uuid\s*:=\s*auth\.uid\(\)/i);
  assert.match(playerFunction, /submission\.author_id\s*=\s*v_user/i);
  assert.match(playerFunction, /vote\.voter_id\s*=\s*v_user/i);
  assert.match(playerFunction, /claim\.player_id\s*=\s*v_user/i);
});

test("only sanitized Phase 2 read RPCs are granted to authenticated clients", async () => {
  const sql = await loadPhase2Migration();
  assert.match(sql, /revoke\s+all\s+on\s+function\s+private\.claim_phase2_action\(uuid,\s*uuid,\s*bigint,\s*text\)\s+from\s+public,\s*anon,\s*authenticated/i);
  assert.match(sql, /grant\s+execute\s+on\s+function\s+public\.get_public_phase2_state\(text\)\s+to\s+authenticated/i);
  assert.match(sql, /grant\s+execute\s+on\s+function\s+public\.get_phase2_player_state\(uuid\)\s+to\s+authenticated/i);
});
