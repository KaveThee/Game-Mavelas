import { findRegisteredGame } from "../registry.ts";
import type { GameModule } from "../types.ts";

type Point = { x: number; y: number };
type Stroke = Point[];

export type BluffDrawState = {
  phase: "prepared" | "drawing" | "bluffing" | "voting" | "results" | "finished";
  artistId: string;
  secretPrompt: string;
  drawing: Stroke[] | null;
  players: Record<string, { id: string; name: string; score: number }>;
  bluffs: Record<string, { id: string; authorId: string; text: string }>;
  choices: Array<{ id: string; text: string; authorId: string | null }>;
  votes: Record<string, string>;
};

export type BluffDrawAction =
  | { kind: "submit_drawing"; strokes: Stroke[] }
  | { kind: "submit_bluff"; text: string }
  | { kind: "begin_voting" }
  | { kind: "vote"; choiceId: string }
  | { kind: "reveal_results" };

const prompts = ["A goat using a laptop", "A matatu on the moon", "A football referee dancing"];
const definition = findRegisteredGame("bluff-and-draw");
if (!definition) throw new Error("Bluff & Draw is missing from the game registry");

function requireSystem(playerId: string) {
  if (playerId !== "system") throw new Error("Only the server can change Bluff & Draw phases");
}

function validateDrawing(strokes: Stroke[]) {
  if (strokes.length < 1 || strokes.length > 24) throw new Error("Drawing must contain between 1 and 24 strokes");
  let pointCount = 0;
  for (const stroke of strokes) {
    if (stroke.length < 2 || stroke.length > 200) throw new Error("Drawing stroke is invalid");
    pointCount += stroke.length;
    for (const point of stroke) {
      if (!Number.isFinite(point.x) || !Number.isFinite(point.y) || point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1) {
        throw new Error("Drawing point is outside the canvas");
      }
    }
  }
  if (pointCount > 1200) throw new Error("Drawing contains too many points");
}

function normalizeText(text: string) {
  return text.replace(/\s+/g, " ").trim();
}

export const bluffAndDrawModule: GameModule<BluffDrawState, BluffDrawAction, unknown, unknown> = {
  definition,
  prepare(context) {
    const players = context.players ?? [];
    if (players.length < 3) throw new Error("Bluff & Draw needs at least three active players");
    const artistIndex = [...context.roomId].reduce((total, character) => total + character.charCodeAt(0), 0) % players.length;
    return {
      phase: "prepared",
      artistId: players[artistIndex].id,
      secretPrompt: prompts[artistIndex % prompts.length],
      drawing: null,
      players: Object.fromEntries(players.map((player) => [player.id, { ...player, score: 0 }])),
      bluffs: {},
      choices: [],
      votes: {},
    };
  },
  start(state) {
    if (state.phase !== "prepared") throw new Error("Bluff & Draw can only start from prepared state");
    return { state: { ...state, phase: "drawing" }, phaseChanged: true };
  },
  handleAction(state, action) {
    if (action.payload.kind === "submit_drawing") {
      if (state.phase !== "drawing") throw new Error("Drawing is closed");
      if (action.playerId !== state.artistId) throw new Error("Only the round artist can submit the drawing");
      if (state.drawing) throw new Error("The drawing was already submitted");
      validateDrawing(action.payload.strokes);
      return { state: { ...state, drawing: action.payload.strokes, phase: "bluffing" }, phaseChanged: true };
    }

    if (action.payload.kind === "submit_bluff") {
      if (state.phase !== "bluffing") throw new Error("Bluffs are closed");
      if (!state.players[action.playerId] || action.playerId === state.artistId) throw new Error("Player cannot submit a bluff");
      if (state.bluffs[action.playerId]) throw new Error("Player already submitted a bluff");
      const text = normalizeText(action.payload.text);
      if (text.length < 2 || text.length > 120) throw new Error("Bluff must be between 2 and 120 characters");
      if (text.localeCompare(state.secretPrompt, undefined, { sensitivity: "accent" }) === 0) {
        throw new Error("Bluff cannot copy the secret prompt");
      }
      const bluff = { id: `bluff-${Object.keys(state.bluffs).length + 1}`, authorId: action.playerId, text };
      return { state: { ...state, bluffs: { ...state.bluffs, [action.playerId]: bluff } } };
    }

    if (action.payload.kind === "begin_voting") {
      requireSystem(action.playerId);
      if (state.phase !== "bluffing" || !state.drawing) throw new Error("Voting is not ready");
      if (Object.keys(state.bluffs).length < 2) throw new Error("Voting needs at least two bluffs");
      const choices = [
        { id: "correct", text: state.secretPrompt, authorId: null },
        ...Object.values(state.bluffs).map(({ id, text, authorId }) => ({ id, text, authorId })),
      ].sort((left, right) => left.id.localeCompare(right.id));
      return { state: { ...state, phase: "voting", choices }, phaseChanged: true };
    }

    if (action.payload.kind === "vote") {
      if (state.phase !== "voting") throw new Error("Voting is closed");
      if (!state.players[action.playerId] || action.playerId === state.artistId) throw new Error("Player cannot vote this round");
      if (state.votes[action.playerId]) throw new Error("Player already voted this round");
      const choiceId = action.payload.choiceId;
      const choice = state.choices.find((candidate) => candidate.id === choiceId);
      if (!choice) throw new Error("Choice is not part of this round");
      if (choice.authorId === action.playerId) throw new Error("Players cannot vote for their own bluff");
      return { state: { ...state, votes: { ...state.votes, [action.playerId]: choice.id } } };
    }

    requireSystem(action.playerId);
    if (state.phase !== "voting") throw new Error("Results can only follow voting");
    const awards: Record<string, number> = {};
    for (const [voterId, choiceId] of Object.entries(state.votes)) {
      const choice = state.choices.find((candidate) => candidate.id === choiceId);
      if (!choice) continue;
      if (choice.id === "correct") awards[voterId] = (awards[voterId] ?? 0) + 2;
      if (choice.authorId) awards[choice.authorId] = (awards[choice.authorId] ?? 0) + 1;
    }
    return {
      state: {
        ...state,
        phase: "results",
        players: Object.fromEntries(Object.values(state.players).map((player) => [
          player.id,
          { ...player, score: player.score + (awards[player.id] ?? 0) },
        ])),
      },
      phaseChanged: true,
    };
  },
  tick(state) {
    return { state };
  },
  getPublicState(state) {
    return {
      phase: state.phase,
      artistName: state.players[state.artistId]?.name ?? "Artist",
      drawing: state.drawing,
      submittedCount: Object.keys(state.bluffs).length,
      votedCount: Object.keys(state.votes).length,
      choices: state.phase === "voting"
        ? state.choices.map(({ id, text }) => ({ id, text }))
        : state.phase === "results" || state.phase === "finished"
          ? state.choices.map((choice) => ({
              id: choice.id,
              text: choice.text,
              authorName: choice.authorId ? state.players[choice.authorId]?.name ?? "Player" : null,
              isCorrect: choice.id === "correct",
            }))
          : [],
      leaderboard: Object.values(state.players)
        .map(({ id, name, score }) => ({ id, name, score }))
        .sort((left, right) => right.score - left.score || left.name.localeCompare(right.name)),
    };
  },
  getPrivateState(state, playerId) {
    if (!state.players[playerId]) throw new Error("Player is not part of this session");
    return {
      playerId,
      isArtist: playerId === state.artistId,
      secretPrompt: playerId === state.artistId ? state.secretPrompt : null,
      ownBluff: state.bluffs[playerId]?.text ?? null,
      hasVoted: Boolean(state.votes[playerId]),
    };
  },
  finish(state) {
    return { state: { ...state, phase: "finished" }, phaseChanged: true, finished: true };
  },
  reset(state, context) {
    return this.prepare({
      ...context,
      players: Object.values(state.players).map(({ id, name }) => ({ id, name })),
    });
  },
};
