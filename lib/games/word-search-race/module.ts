import { findRegisteredGame } from "../registry.ts";
import {
  claimWord,
  getWordGridPrivateState,
  getWordGridPublicState,
  prepareWordGrid,
  type GridPoint,
  type WordGridState,
} from "../word-grid/core.ts";
import type { GameModule } from "../types.ts";

type WordSearchAction = { kind: "claim_word"; word: string; path: GridPoint[] };

const definition = findRegisteredGame("word-search-race");
if (!definition) throw new Error("Word Search Race is missing from the game registry");

const grid = [
  ["C", "A", "T", "S"],
  ["R", "A", "I", "N"],
  ["B", "O", "A", "T"],
  ["S", "U", "N", "Y"],
];
const words = ["CAT", "RAIN", "BOAT", "SUN"];

export const wordSearchRaceModule: GameModule<
  WordGridState,
  WordSearchAction,
  ReturnType<typeof getWordGridPublicState>,
  ReturnType<typeof getWordGridPrivateState>
> = {
  definition,
  prepare(context) {
    return prepareWordGrid(context.players ?? [], grid, words);
  },
  start(state) {
    if (state.phase !== "prepared") throw new Error("Word Search Race can only start from prepared state");
    return { state: { ...state, phase: "playing" }, phaseChanged: true };
  },
  handleAction(state, action) {
    if (action.payload.kind !== "claim_word") throw new Error("Unknown Word Search Race action");
    return { state: claimWord(state, action.playerId, action.payload.word, action.payload.path) };
  },
  tick(state) {
    return { state };
  },
  getPublicState: getWordGridPublicState,
  getPrivateState: getWordGridPrivateState,
  finish(state) {
    return { state: { ...state, phase: "finished" }, phaseChanged: true, finished: true };
  },
  reset(state) {
    return prepareWordGrid(Object.values(state.players).map(({ id, name }) => ({ id, name })), grid, words);
  },
};
