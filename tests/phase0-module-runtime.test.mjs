import assert from "node:assert/strict";
import test from "node:test";

import { GameModuleLoader } from "../lib/games/module-loader.ts";
import { classicGames, plannedGames } from "../lib/games/registry.ts";
import {
  applyGameActionOnce,
  createVersionedGameSession,
  transitionGameSession,
} from "../lib/games/session-lifecycle.ts";

function createCounterModule(definition) {
  return {
    definition,
    prepare: () => ({ count: 0 }),
    start: (state) => ({ state }),
    handleAction: (state, action) => ({ state: { count: state.count + action.payload.amount } }),
    tick: (state) => ({ state }),
    getPublicState: (state) => ({ count: state.count }),
    getPrivateState: (state) => ({ count: state.count }),
    finish: (state) => ({ state, finished: true }),
    reset: () => ({ count: 0 }),
  };
}

const context = {
  roomId: "room-1",
  sessionId: "session-1",
  now: "2026-10-07T01:00:00.000Z",
};

test("module loader rejects definitions outside the canonical registry", () => {
  const loader = new GameModuleLoader();
  const unknownDefinition = { ...plannedGames[0], id: "unknown-game" };
  assert.throws(() => loader.register(createCounterModule(unknownDefinition)), /unknown game/);
});

test("module loader rejects duplicate registration and disabled planned games", () => {
  const loader = new GameModuleLoader();
  const gameModule = createCounterModule(plannedGames[0]);
  loader.register(gameModule);
  assert.throws(() => loader.register(gameModule), /already registered/);
  assert.throws(() => loader.requirePlayable(plannedGames[0].id), /not enabled/);
});

test("module loader requires an implementation even for a live registry entry", () => {
  const loader = new GameModuleLoader();
  assert.throws(() => loader.requirePlayable(classicGames[0].id), /not loaded/);
});

test("session lifecycle increments versions and rejects illegal transitions", () => {
  const session = createVersionedGameSession({
    roomId: context.roomId,
    sessionId: context.sessionId,
    gameId: plannedGames[0].id,
    state: { count: 0 },
  });
  const playing = transitionGameSession(session, "playing");
  assert.equal(playing.stateVersion, 1);
  assert.equal(playing.phase, "playing");
  assert.throws(() => transitionGameSession(playing, "lobby"), /Illegal game phase transition/);
});

test("duplicate, stale, and out-of-order actions never mutate session state", () => {
  const gameModule = createCounterModule(plannedGames[0]);
  const session = createVersionedGameSession({
    roomId: context.roomId,
    sessionId: context.sessionId,
    gameId: gameModule.definition.id,
    state: { count: 0 },
    phase: "playing",
  });
  const action = {
    id: "action-1",
    type: "increment",
    playerId: "player-1",
    sequence: 1,
    createdAt: context.now,
    payload: { amount: 2 },
  };

  const applied = applyGameActionOnce(session, gameModule, action, context);
  assert.equal(applied.outcome, "applied");
  assert.equal(applied.session.state.count, 2);
  assert.equal(applied.session.stateVersion, 1);

  const duplicate = applyGameActionOnce(applied.session, gameModule, action, context);
  assert.equal(duplicate.outcome, "duplicate");
  assert.equal(duplicate.session, applied.session);

  const stale = applyGameActionOnce(applied.session, gameModule, { ...action, id: "action-2" }, context);
  assert.equal(stale.outcome, "stale");
  assert.equal(stale.session, applied.session);

  const gap = applyGameActionOnce(
    applied.session,
    gameModule,
    { ...action, id: "action-3", sequence: 3 },
    context,
  );
  assert.equal(gap.outcome, "out_of_order");
  assert.equal(gap.session, applied.session);
});
