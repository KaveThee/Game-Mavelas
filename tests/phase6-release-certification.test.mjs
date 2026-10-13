import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const controller = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");
const supabaseClient = readFileSync(new URL("../lib/supabase.ts", import.meta.url), "utf8");
const releaseHardening = readFileSync(
  new URL("../supabase/migrations/20261013234913_phase6_release_hardening.sql", import.meta.url),
  "utf8",
);
const migrations = readdirSync(new URL("../supabase/migrations", import.meta.url));

test("Phase 5 pacing migration is aligned to the hosted migration ledger", () => {
  assert.ok(migrations.includes("20261013234725_phase5_game_pacing.sql"));
  assert.ok(!migrations.includes("20261013232126_phase5_game_pacing.sql"));
});

test("option ordering remains RPC-only at the table boundary", () => {
  assert.match(
    releaseHardening,
    /revoke all on table public\.round_option_orders from public, anon, authenticated/i,
  );
});

test("host room updates cache the authenticated identity for RLS", () => {
  assert.match(releaseHardening, /drop policy if exists "host updates room"/i);
  assert.match(releaseHardening, /using \(\(select auth\.uid\(\)\) = host_id\)/i);
  assert.match(releaseHardening, /with check \(\(select auth\.uid\(\)\) = host_id\)/i);
});

test("public entry uses anonymous Supabase identity without a Vercel login", () => {
  assert.match(supabaseClient, /supabase\.auth\.signInAnonymously\(\)/);
  assert.doesNotMatch(controller, /signInWithOAuth|vercel.*login/i);
  assert.doesNotMatch(display, /signInWithOAuth|vercel.*login/i);
});

test("QR and copied invites use the public code entry point", () => {
  assert.match(display, /const joinUrl = `\$\{window\.location\.origin\}\/\?code=\$\{code\}`/);
  assert.match(controller, /const url = `\$\{window\.location\.origin\}\/\?code=\$\{room\}`/);
});

test("a historical End Game signal cannot eject a newly reopened display", () => {
  assert.match(display, /endGameSignalRef\.current !== undefined/);
  assert.doesNotMatch(display, /endGameSignalRef\.current === undefined\s*\|\|/);
});
