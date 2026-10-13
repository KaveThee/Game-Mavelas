import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync(
  new URL("../supabase/migrations/20261013122934_phase4_room_lifecycle_controls.sql", import.meta.url),
  "utf8",
);
const privacyMigration = readFileSync(
  new URL("../supabase/migrations/20261013123838_phase4_room_lifecycle_privacy_hardening.sql", import.meta.url),
  "utf8",
);
const controller = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");
const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");

test("explicit leave is authenticated and locks the room before changing membership", () => {
  assert.match(migration, /function public\.leave_game_room\(p_room_id uuid\)/i);
  assert.match(migration, /v_user uuid := \(select auth\.uid\(\)\)/i);
  assert.match(migration, /from public\.rooms[\s\S]*where id = p_room_id[\s\S]*for update/i);
  assert.match(migration, /role in \('host', 'player'\)[\s\S]*for update/i);
});

test("host departure promotes the earliest remaining active participant deterministically", () => {
  assert.match(migration, /where rp\.room_id = p_room_id and rp\.role in \('host', 'player'\)[\s\S]*order by rp\.joined_at, rp\.user_id[\s\S]*limit 1/i);
  assert.match(migration, /set role = case when user_id = v_successor then 'host' else 'player' end/i);
  assert.match(migration, /set host_id = v_successor/i);
});

test("leave repairs active turns, answer quorum, and empty rooms", () => {
  assert.match(migration, /set active_player_id = v_turn_successor/i);
  assert.match(migration, /delete from public\.player_answers[\s\S]*player_id = v_user/i);
  assert.match(migration, /v_answer_count >= v_remaining_players/i);
  assert.match(migration, /set phase = 'all_answered'/i);
  assert.match(migration, /v_remaining_players = 0[\s\S]*status = 'closed'[\s\S]*phase = 'closed'/i);
});

test("host end game closes rounds and resets the existing room to a lobby", () => {
  assert.match(migration, /function public\.host_end_game\(p_room_id uuid\)/i);
  assert.match(migration, /v_room\.host_id <> v_user[\s\S]*Only the room host can end the game/i);
  assert.match(migration, /update public\.game_rounds[\s\S]*set status = 'closed'/i);
  assert.match(migration, /delete from public\.player_answers where room_id = p_room_id/i);
  assert.match(migration, /delete from public\.trivia_dash_player_state where room_id = p_room_id/i);
  assert.match(migration, /update public\.room_players set score = 0/i);
  assert.match(migration, /set status = 'lobby',[\s\S]*phase = 'lobby'/i);
  assert.match(migration, /'end_game_signal', v_signal/i);
});

test("new lifecycle RPCs are not executable by public or anon", () => {
  assert.match(migration, /revoke all on function public\.leave_game_room\(uuid\) from public, anon/i);
  assert.match(migration, /revoke all on function public\.host_end_game\(uuid\) from public, anon/i);
  assert.match(migration, /grant execute on function public\.leave_game_room\(uuid\) to authenticated/i);
  assert.match(migration, /grant execute on function public\.host_end_game\(uuid\) to authenticated/i);
});

test("leave response does not expose the successor auth user id", () => {
  assert.match(privacyMigration, /alter function public\.leave_game_room\(uuid\) set schema private/i);
  assert.match(privacyMigration, /v_result - 'new_host_id'/i);
  assert.match(privacyMigration, /'host_transferred'/i);
  assert.match(privacyMigration, /revoke all on function private\.leave_game_room\(uuid\) from public, anon, authenticated/i);
});

test("controller surfaces call lifecycle RPCs and gate End Game to the host", () => {
  assert.match(controller, /supabase\.rpc\("leave_game_room"/);
  assert.match(controller, /supabase\.rpc\("host_end_game"/);
  assert.match(controller, /onEndGame=\{serverState\.is_host \? handleEndGame : undefined\}/);
  assert.match(controller, /Host controls will pass to the next player/);
  assert.match(controller, /The room will close because no players remain/);
  assert.match(controller, /End Game · Return Everyone to Lobby/);
});

test("controller logo is inert in room views while display logo returns home", () => {
  assert.match(controller, /\{onHome \? \([\s\S]*<button[\s\S]*\) : \([\s\S]*<div className="flex items-center gap-3 text-left"/);
  assert.match(controller, /<Topbar compact \/>/);
  assert.match(display, /aria-label="Return display to main menu"/);
  assert.match(display, /onClick=\{\(\) => window\.location\.assign\("\/"\)\}/);
});

test("display returns home for an ended lobby on initial load or a new host signal", () => {
  assert.match(migration, /'end_game_signal', r\.state ->> 'end_game_signal'/i);
  assert.match(display, /endGameSignalRef = useRef<string \| null \| undefined>\(undefined\)/);
  assert.match(display, /endGameSignalRef\.current === undefined/);
  assert.match(display, /nextEndGameSignal !== endGameSignalRef\.current/);
  assert.match(display, /nextRoom\.status === "lobby"/);
});
