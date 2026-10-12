import assert from "node:assert/strict";
import test from "node:test";

import { bluffAndDrawModule } from "../lib/games/bluff-and-draw/module.ts";
import { gameModuleCatalog } from "../lib/games/module-catalog.ts";
import { memeFactoryModule } from "../lib/games/meme-factory/module.ts";
import { wordSabotageModule } from "../lib/games/word-sabotage/module.ts";
import { wordSearchRaceModule } from "../lib/games/word-search-race/module.ts";

const context = {
  roomId: "phase-two-room",
  sessionId: "phase-two-session",
  now: "2026-10-12T17:20:00.000Z",
  players: [
    { id: "p1", name: "Amina" },
    { id: "p2", name: "Brian" },
    { id: "p3", name: "Chebet" },
  ],
};

function action(id, playerId, sequence, payload) {
  return { id, playerId, sequence, payload, type: payload.kind, createdAt: context.now };
}

test("all Phase 2 modules are registered but none can enter a live room", () => {
  for (const gameId of ["meme-factory", "bluff-and-draw", "word-sabotage", "word-search-race"]) {
    assert.equal(gameModuleCatalog.has(gameId), true);
    assert.throws(() => gameModuleCatalog.requirePlayable(gameId), /not enabled/);
  }
});

test("Meme Factory keeps captions private, blocks self-votes, and scores revealed votes", async () => {
  let state = memeFactoryModule.start(await memeFactoryModule.prepare(context), context).state;
  state = memeFactoryModule.handleAction(state, action("m1", "p1", 1, { kind: "submit", text: "Caption one" }), context).state;
  state = memeFactoryModule.handleAction(state, action("m2", "p2", 1, { kind: "submit", text: "Caption two" }), context).state;

  assert.equal(JSON.stringify(memeFactoryModule.getPublicState(state)).includes("Caption one"), false);
  state = memeFactoryModule.handleAction(state, action("mv", "system", 1, { kind: "begin_voting" }), context).state;
  assert.throws(
    () => memeFactoryModule.handleAction(state, action("bad", "p1", 2, { kind: "vote", submissionId: "entry-1" }), context),
    /cannot vote for their own/,
  );
  state = memeFactoryModule.handleAction(state, action("vote", "p3", 1, { kind: "vote", submissionId: "entry-1" }), context).state;
  state = memeFactoryModule.handleAction(state, action("result", "system", 2, { kind: "reveal_results" }), context).state;
  assert.equal(state.players.p1.score, 1);
});

test("Bluff & Draw only reveals the prompt to the artist before results", async () => {
  let state = bluffAndDrawModule.start(await bluffAndDrawModule.prepare(context), context).state;
  const artistId = state.artistId;
  const nonArtists = context.players.map((player) => player.id).filter((id) => id !== artistId);
  assert.ok(bluffAndDrawModule.getPrivateState(state, artistId).secretPrompt);
  assert.equal(bluffAndDrawModule.getPrivateState(state, nonArtists[0]).secretPrompt, null);
  assert.equal(JSON.stringify(bluffAndDrawModule.getPublicState(state)).includes(state.secretPrompt), false);

  state = bluffAndDrawModule.handleAction(state, action("draw", artistId, 1, {
    kind: "submit_drawing",
    strokes: [[{ x: 0.1, y: 0.1 }, { x: 0.8, y: 0.8 }]],
  }), context).state;
  state = bluffAndDrawModule.handleAction(state, action("b1", nonArtists[0], 1, { kind: "submit_bluff", text: "A dancing bus" }), context).state;
  state = bluffAndDrawModule.handleAction(state, action("b2", nonArtists[1], 1, { kind: "submit_bluff", text: "A flying cow" }), context).state;
  state = bluffAndDrawModule.handleAction(state, action("begin", "system", 1, { kind: "begin_voting" }), context).state;

  const votingState = bluffAndDrawModule.getPublicState(state);
  assert.equal(votingState.choices.some((choice) => "authorName" in choice), false);
  assert.throws(
    () => bluffAndDrawModule.handleAction(state, action("self", nonArtists[0], 2, { kind: "vote", choiceId: "bluff-1" }), context),
    /cannot vote for their own bluff/,
  );
});

test("Bluff & Draw rejects unbounded or off-canvas drawing payloads", async () => {
  const state = bluffAndDrawModule.start(await bluffAndDrawModule.prepare(context), context).state;
  assert.throws(
    () => bluffAndDrawModule.handleAction(state, action("bad-draw", state.artistId, 1, {
      kind: "submit_drawing",
      strokes: [[{ x: -1, y: 0 }, { x: 2, y: 1 }]],
    }), context),
    /outside the canvas/,
  );
});

test("Word Search Race validates paths and Word Sabotage exposes only its active modifier", async () => {
  let race = wordSearchRaceModule.start(await wordSearchRaceModule.prepare(context), context).state;
  race = wordSearchRaceModule.handleAction(race, action("word", "p1", 1, {
    kind: "claim_word",
    word: "CAT",
    path: [{ row: 0, column: 0 }, { row: 0, column: 1 }, { row: 0, column: 2 }],
  }), context).state;
  assert.equal(race.players.p1.score, 3);

  const sabotage = wordSabotageModule.start(await wordSabotageModule.prepare(context), context).state;
  const publicState = wordSabotageModule.getPublicState(sabotage);
  assert.equal(publicState.blockedLetter, "Z");
  assert.equal("validWords" in publicState, false);
});
