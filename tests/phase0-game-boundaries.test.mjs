import assert from "node:assert/strict";
import test from "node:test";

import {
  classicGames,
  expansionGames,
  gameCollections,
  getGameTitle,
  plannedGames,
  playableGames,
  triviaBranches,
} from "../lib/games/registry.ts";
import { assertPublicStateSafe } from "../lib/games/state-boundaries.ts";

const rejectedGameIds = new Set([
  "mafia-mayhem",
  "rhythm-rumble",
  "speed-racers",
  "zombie-survival",
  "stealth-heist",
  "dance-off",
  "laugh-out-loud",
  "spatial-stackers",
]);

test("registry contains the Classics, trivia branches, first expansion, and safe backlog", () => {
  assert.equal(classicGames.length, 5);
  assert.equal(triviaBranches.length, 3);
  assert.equal(expansionGames.length, 1);
  assert.equal(plannedGames.length, 11);
  assert.equal(expansionGames[0].id, "trivia-dash");
});

test("planned or rejected games cannot enter the current playable list", () => {
  assert.ok(playableGames.every((game) => game.availability === "live"));
  assert.ok(playableGames.every((game) => !plannedGames.some((planned) => planned.id === game.id)));
  assert.ok([...classicGames, ...triviaBranches, ...expansionGames, ...plannedGames].every((game) => !rejectedGameIds.has(game.id)));
});

test("game ids are unique and every collection references a registered game", () => {
  const registeredGames = [...classicGames, ...triviaBranches, ...expansionGames, ...plannedGames];
  const ids = registeredGames.map((game) => game.id);
  assert.equal(new Set(ids).size, ids.length);

  const registeredIds = new Set(ids);
  for (const collection of gameCollections) {
    for (const id of collection.gameIds) assert.ok(registeredIds.has(id), `${collection.id} references ${id}`);
  }
});

test("shared titles resolve consistently for player and display surfaces", () => {
  assert.equal(getGameTitle("flag_frenzy"), "Flag Frenzy");
  assert.equal(getGameTitle("trivia-kenya"), "Trivia Vault · Home Turf");
  assert.equal(getGameTitle("unknown"), "Game Mavelas");
});

test("public state rejects controller-only secrets at every phase", () => {
  assert.throws(
    () => assertPublicStateSafe({ round: { secret_identity: "Hidden person" } }, "revealed"),
    /round\.secret_identity/,
  );
});

test("public state rejects answers before reveal and allows them after reveal", () => {
  assert.throws(
    () => assertPublicStateSafe({ correct_option: "Nairobi" }, "playing"),
    /correct_option/,
  );
  assert.doesNotThrow(() => assertPublicStateSafe({ correct_option: "Nairobi" }, "revealed"));
});

test("null reveal fields remain safe before reveal", () => {
  assert.doesNotThrow(() =>
    assertPublicStateSafe({ players: [{ is_correct: null }], correct_option: null }, "playing"),
  );
});
