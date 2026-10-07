import assert from "node:assert/strict";
import test from "node:test";

import { gameModuleCatalog } from "../lib/games/module-catalog.ts";
import { applyGameActionOnce, createVersionedGameSession } from "../lib/games/session-lifecycle.ts";
import {
  TRIVIA_DASH_CORRECT_MOVE,
  TRIVIA_DASH_STREAK_BONUS_MOVE,
  triviaDashModule,
} from "../lib/games/trivia-dash/module.ts";

const context = {
  roomId: "room-dash",
  sessionId: "session-dash",
  now: "2026-10-07T01:30:00.000Z",
  players: [
    { id: "p1", name: "Amina" },
    { id: "p2", name: "Brian" },
  ],
};

function action(id, playerId, sequence, payload) {
  return { id, playerId, sequence, payload, type: payload.kind, createdAt: context.now };
}

test("Trivia Dash is registered for development but remains unavailable to live rooms", () => {
  assert.equal(gameModuleCatalog.has("trivia-dash"), true);
  assert.throws(() => gameModuleCatalog.requirePlayable("trivia-dash"), /not enabled/);
});

test("Trivia Dash prepares a recoverable board and starts all players together", async () => {
  const prepared = await triviaDashModule.prepare(context);
  assert.equal(prepared.status, "prepared");
  assert.equal(prepared.players.p1.position, 0);
  assert.equal(prepared.players.p2.position, 0);

  const started = triviaDashModule.start(prepared, context).state;
  assert.equal(started.status, "playing");
  assert.equal(started.currentRound, 1);
});

test("correct answers move after server scoring without speed bonuses", async () => {
  const started = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  const session = createVersionedGameSession({
    roomId: context.roomId,
    sessionId: context.sessionId,
    gameId: triviaDashModule.definition.id,
    state: started,
    phase: "playing",
  });

  const result = applyGameActionOnce(
    session,
    triviaDashModule,
    action("p1-r1", "p1", 1, { kind: "score_answer", round: 1, correct: true, points: 100 }),
    context,
  );
  assert.equal(result.outcome, "applied");
  assert.equal(result.session.state.players.p1.position, TRIVIA_DASH_CORRECT_MOVE);
  assert.equal(result.session.state.players.p1.score, 100);
});

test("a player cannot receive two results in the same round", async () => {
  const started = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  const first = triviaDashModule.handleAction(
    started,
    action("p1-r1", "p1", 1, { kind: "score_answer", round: 1, correct: true, points: 100 }),
    context,
  ).state;

  assert.throws(
    () => triviaDashModule.handleAction(
      first,
      action("p1-r1-retry", "p1", 2, { kind: "score_answer", round: 1, correct: true, points: 100 }),
      context,
    ),
    /already has a result/,
  );
});

test("round advancement waits for every active player and only the server can trigger it", async () => {
  let state = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  state = triviaDashModule.handleAction(
    state,
    action("p1-r1", "p1", 1, { kind: "score_answer", round: 1, correct: true, points: 100 }),
    context,
  ).state;

  assert.throws(
    () => triviaDashModule.handleAction(state, action("advance-1", "system", 1, { kind: "advance_round" }), context),
    /every active player/,
  );
  assert.throws(
    () => triviaDashModule.handleAction(state, action("advance-player", "p1", 2, { kind: "advance_round" }), context),
    /Only the server/,
  );
});

test("three consecutive correct answers earn one fixed comeback-safe bonus step", async () => {
  let state = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  for (let round = 1; round <= 3; round += 1) {
    state = triviaDashModule.handleAction(
      state,
      action(`p1-r${round}`, "p1", round, { kind: "score_answer", round, correct: true, points: 100 }),
      context,
    ).state;
    state = triviaDashModule.handleAction(
      state,
      action(`p2-r${round}`, "p2", round, { kind: "score_answer", round, correct: false, points: 0 }),
      context,
    ).state;
    if (round < 3) {
      state = triviaDashModule.handleAction(
        state,
        action(`advance-${round}`, "system", round, { kind: "advance_round" }),
        context,
      ).state;
    }
  }

  assert.equal(state.players.p1.position, TRIVIA_DASH_CORRECT_MOVE * 3 + TRIVIA_DASH_STREAK_BONUS_MOVE);
});

test("public state excludes answer and private sequencing details", async () => {
  const state = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  const publicState = triviaDashModule.getPublicState(state);
  const serialized = JSON.stringify(publicState);

  assert.equal(serialized.includes("lastScoredRound"), false);
  assert.equal(serialized.includes("correctAnswers"), false);
  assert.equal(serialized.includes("correct"), false);

  const privateState = triviaDashModule.getPrivateState(state, "p1");
  assert.equal(privateState.hasAnsweredCurrentRound, false);
});

test("reset preserves the roster while clearing positions, scores, and streaks", async () => {
  let state = triviaDashModule.start(await triviaDashModule.prepare(context), context).state;
  state = triviaDashModule.handleAction(
    state,
    action("p1-r1", "p1", 1, { kind: "score_answer", round: 1, correct: true, points: 100 }),
    context,
  ).state;

  const reset = await triviaDashModule.reset(state, context);
  assert.deepEqual(Object.keys(reset.players).sort(), ["p1", "p2"]);
  assert.equal(reset.players.p1.position, 0);
  assert.equal(reset.players.p1.score, 0);
  assert.equal(reset.players.p1.streak, 0);
});
