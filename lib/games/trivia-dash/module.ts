import { findRegisteredGame } from "../registry.ts";
import type { GameModule } from "../types.ts";

export const TRIVIA_DASH_BOARD_LENGTH = 24;
export const TRIVIA_DASH_TOTAL_ROUNDS = 12;
export const TRIVIA_DASH_CORRECT_MOVE = 2;
export const TRIVIA_DASH_STREAK_INTERVAL = 3;
export const TRIVIA_DASH_STREAK_BONUS_MOVE = 1;

export type TriviaDashStatus = "prepared" | "playing" | "finished";

export type TriviaDashPlayerState = {
  id: string;
  name: string;
  position: number;
  score: number;
  correctAnswers: number;
  streak: number;
  lastScoredRound: number;
};

export type TriviaDashState = {
  status: TriviaDashStatus;
  boardLength: number;
  currentRound: number;
  totalRounds: number;
  players: Record<string, TriviaDashPlayerState>;
};

export type TriviaDashActionPayload =
  | {
      kind: "score_answer";
      round: number;
      correct: boolean;
      points: number;
    }
  | {
      kind: "advance_round";
    };

export type TriviaDashPublicState = {
  status: TriviaDashStatus;
  boardLength: number;
  currentRound: number;
  totalRounds: number;
  players: Array<{
    id: string;
    name: string;
    position: number;
    score: number;
  }>;
  winnerIds: string[];
};

export type TriviaDashPrivateState = {
  playerId: string;
  position: number;
  score: number;
  streak: number;
  hasAnsweredCurrentRound: boolean;
};

const definition = findRegisteredGame("trivia-dash");
if (!definition) throw new Error("Trivia Dash is missing from the game registry");

function buildPlayers(players: readonly { id: string; name: string }[]) {
  return Object.fromEntries(
    players.map((player) => [
      player.id,
      {
        id: player.id,
        name: player.name,
        position: 0,
        score: 0,
        correctAnswers: 0,
        streak: 0,
        lastScoredRound: 0,
      },
    ]),
  );
}

function requirePlaying(state: TriviaDashState) {
  if (state.status !== "playing") throw new Error("Trivia Dash is not accepting actions");
}

function scoreAnswer(
  state: TriviaDashState,
  playerId: string,
  payload: Extract<TriviaDashActionPayload, { kind: "score_answer" }>,
) {
  requirePlaying(state);
  if (payload.round !== state.currentRound) throw new Error("Answer does not belong to the current round");

  const player = state.players[playerId];
  if (!player) throw new Error("Player is not part of this Trivia Dash session");
  if (player.lastScoredRound >= state.currentRound) throw new Error("Player already has a result for this round");

  const nextStreak = payload.correct ? player.streak + 1 : 0;
  const streakBonus = payload.correct && nextStreak % TRIVIA_DASH_STREAK_INTERVAL === 0
    ? TRIVIA_DASH_STREAK_BONUS_MOVE
    : 0;
  const movement = payload.correct ? TRIVIA_DASH_CORRECT_MOVE + streakBonus : 0;
  const points = Number.isInteger(payload.points) ? Math.max(0, payload.points) : 0;

  return {
    ...state,
    players: {
      ...state.players,
      [playerId]: {
        ...player,
        position: Math.min(state.boardLength, player.position + movement),
        score: player.score + points,
        correctAnswers: player.correctAnswers + (payload.correct ? 1 : 0),
        streak: nextStreak,
        lastScoredRound: state.currentRound,
      },
    },
  };
}

function advanceRound(state: TriviaDashState) {
  requirePlaying(state);
  const waitingPlayers = Object.values(state.players).filter(
    (player) => player.lastScoredRound !== state.currentRound,
  );
  if (waitingPlayers.length > 0) throw new Error("Cannot advance before every active player has a round result");

  if (state.currentRound >= state.totalRounds) {
    return { ...state, status: "finished" as const };
  }

  return { ...state, currentRound: state.currentRound + 1 };
}

export const triviaDashModule: GameModule<
  TriviaDashState,
  TriviaDashActionPayload,
  TriviaDashPublicState,
  TriviaDashPrivateState
> = {
  definition,

  prepare(context) {
    const players = context.players ?? [];
    if (players.length === 0) throw new Error("Trivia Dash needs at least one active player");
    if (new Set(players.map((player) => player.id)).size !== players.length) {
      throw new Error("Trivia Dash player ids must be unique");
    }

    return {
      status: "prepared",
      boardLength: TRIVIA_DASH_BOARD_LENGTH,
      currentRound: 1,
      totalRounds: TRIVIA_DASH_TOTAL_ROUNDS,
      players: buildPlayers(players),
    };
  },

  start(state) {
    if (state.status !== "prepared") throw new Error("Trivia Dash can only start from prepared state");
    return { state: { ...state, status: "playing" } };
  },

  handleAction(state, action) {
    if (action.payload.kind === "score_answer") {
      return { state: scoreAnswer(state, action.playerId, action.payload) };
    }
    if (action.playerId !== "system") throw new Error("Only the server can advance Trivia Dash rounds");

    const nextState = advanceRound(state);
    return { state: nextState, phaseChanged: true, finished: nextState.status === "finished" };
  },

  tick(state) {
    return { state };
  },

  getPublicState(state) {
    const players = Object.values(state.players)
      .map(({ id, name, position, score }) => ({ id, name, position, score }))
      .sort((left, right) => right.position - left.position || right.score - left.score || left.name.localeCompare(right.name));
    const leadPosition = players[0]?.position ?? 0;

    return {
      status: state.status,
      boardLength: state.boardLength,
      currentRound: state.currentRound,
      totalRounds: state.totalRounds,
      players,
      winnerIds: state.status === "finished"
        ? players.filter((player) => player.position === leadPosition).map((player) => player.id)
        : [],
    };
  },

  getPrivateState(state, playerId) {
    const player = state.players[playerId];
    if (!player) throw new Error("Player is not part of this Trivia Dash session");
    return {
      playerId,
      position: player.position,
      score: player.score,
      streak: player.streak,
      hasAnsweredCurrentRound: player.lastScoredRound === state.currentRound,
    };
  },

  finish(state) {
    return { state: { ...state, status: "finished" }, phaseChanged: true, finished: true };
  },

  reset(state) {
    return {
      status: "prepared",
      boardLength: state.boardLength,
      currentRound: 1,
      totalRounds: state.totalRounds,
      players: buildPlayers(Object.values(state.players).map(({ id, name }) => ({ id, name }))),
    };
  },
};
