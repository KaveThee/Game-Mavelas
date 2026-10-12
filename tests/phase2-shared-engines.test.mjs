import assert from "node:assert/strict";
import test from "node:test";

import {
  getSubmissionVotePrivateState,
  getSubmissionVotePublicState,
  handleSubmissionVoteAction,
  prepareSubmissionVote,
} from "../lib/games/submission-vote/core.ts";
import {
  claimWord,
  getWordGridPrivateState,
  getWordGridPublicState,
  prepareWordGrid,
} from "../lib/games/word-grid/core.ts";

const players = [
  { id: "p1", name: "Amina" },
  { id: "p2", name: "Brian" },
  { id: "p3", name: "Chebet" },
];

test("private captions stay off the display until voting begins", () => {
  let state = prepareSubmissionVote(players, "When the Wi-Fi returns...");
  state = { ...state, phase: "submitting" };
  state = handleSubmissionVoteAction(state, "p1", { kind: "submit", text: "  Everybody   becomes IT support  " });

  const publicState = getSubmissionVotePublicState(state);
  assert.equal(publicState.submittedCount, 1);
  assert.equal(publicState.entries[0].text, null);
  assert.equal(JSON.stringify(publicState).includes("p1"), true);
  assert.equal(JSON.stringify(publicState).includes("Everybody becomes IT support"), false);

  const privateState = getSubmissionVotePrivateState(state, "p1");
  assert.equal(privateState.ownSubmission, "Everybody becomes IT support");
});

test("voting is anonymous and rejects self-votes and repeat votes", () => {
  let state = { ...prepareSubmissionVote(players, "Caption this"), phase: "submitting" };
  state = handleSubmissionVoteAction(state, "p1", { kind: "submit", text: "Caption one" });
  state = handleSubmissionVoteAction(state, "p2", { kind: "submit", text: "Caption two" });
  state = handleSubmissionVoteAction(state, "system", { kind: "begin_voting" });

  const publicVote = getSubmissionVotePublicState(state);
  assert.deepEqual(publicVote.entries.map((entry) => entry.authorName), [null, null]);
  assert.throws(
    () => handleSubmissionVoteAction(state, "p1", { kind: "vote", submissionId: "entry-1" }),
    /cannot vote for their own/,
  );

  state = handleSubmissionVoteAction(state, "p1", { kind: "vote", submissionId: "entry-2" });
  assert.throws(
    () => handleSubmissionVoteAction(state, "p1", { kind: "vote", submissionId: "entry-2" }),
    /already voted/,
  );
});

test("only the server changes submission phases and results restore safely", () => {
  let state = { ...prepareSubmissionVote(players, "Caption this"), phase: "submitting" };
  state = handleSubmissionVoteAction(state, "p1", { kind: "submit", text: "Caption one" });
  state = handleSubmissionVoteAction(state, "p2", { kind: "submit", text: "Caption two" });
  assert.throws(
    () => handleSubmissionVoteAction(state, "p1", { kind: "begin_voting" }),
    /Only the server/,
  );
  state = handleSubmissionVoteAction(state, "system", { kind: "begin_voting" });
  state = handleSubmissionVoteAction(state, "p3", { kind: "vote", submissionId: "entry-1" });
  state = handleSubmissionVoteAction(state, "system", { kind: "reveal_results" });

  const restored = structuredClone(state);
  assert.equal(getSubmissionVotePublicState(restored).entries[0].authorName, "Amina");
  assert.equal(getSubmissionVotePrivateState(restored, "p3").hasVoted, true);
  assert.equal(restored.players.p1.score, 1);
});

test("word claims are validated against the server list and exact grid path", () => {
  let state = prepareWordGrid(players, [
    ["C", "A", "T", "S"],
    ["R", "A", "I", "N"],
    ["B", "O", "A", "T"],
    ["S", "U", "N", "Y"],
  ], ["CAT", "RAIN", "BOAT", "SUN"]);
  state = { ...state, phase: "playing" };

  assert.throws(
    () => claimWord(state, "p1", "FAKE", [{ row: 0, column: 0 }]),
    /server-approved/,
  );
  assert.throws(
    () => claimWord(state, "p1", "CAT", [
      { row: 0, column: 0 },
      { row: 0, column: 1 },
      { row: 2, column: 3 },
    ]),
    /must touch/,
  );

  state = claimWord(state, "p1", "CAT", [
    { row: 0, column: 0 },
    { row: 0, column: 1 },
    { row: 0, column: 2 },
  ]);
  assert.equal(state.players.p1.score, 3);
  assert.throws(
    () => claimWord(state, "p2", "CAT", [
      { row: 0, column: 0 },
      { row: 0, column: 1 },
      { row: 0, column: 2 },
    ]),
    /already been claimed/,
  );
});

test("public word state never exposes the hidden answer list or claim paths", () => {
  const state = { ...prepareWordGrid(players, [
    ["C", "A", "T"],
    ["A", "R", "E"],
    ["T", "E", "N"],
  ], ["CAT", "TEN"]), phase: "playing" };

  const publicState = getWordGridPublicState(state);
  assert.equal("validWords" in publicState, false);
  assert.equal(JSON.stringify(publicState).includes("path"), false);
  assert.deepEqual(getWordGridPrivateState(state, "p1").claimedWords, []);
});
