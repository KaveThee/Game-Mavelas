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

type WordSabotageState = WordGridState & { blockedLetter: string };
type WordSabotageAction = { kind: "claim_word"; word: string; path: GridPoint[] };

const definition = findRegisteredGame("word-sabotage");
if (!definition) throw new Error("Word Sabotage is missing from the game registry");

const grid = [
  ["P", "L", "A", "Y"],
  ["G", "A", "M", "E"],
  ["W", "O", "R", "D"],
  ["R", "A", "C", "E"],
];
const words = ["PLAY", "GAME", "WORD", "RACE"];

export const wordSabotageModule: GameModule<WordSabotageState, WordSabotageAction, unknown, unknown> = {
  definition,
  prepare(context) {
    return { ...prepareWordGrid(context.players ?? [], grid, words), blockedLetter: "Z" };
  },
  start(state) {
    if (state.phase !== "prepared") throw new Error("Word Sabotage can only start from prepared state");
    return { state: { ...state, phase: "playing" }, phaseChanged: true };
  },
  handleAction(state, action) {
    if (action.payload.word.toUpperCase().includes(state.blockedLetter)) {
      throw new Error("Submitted word contains the sabotaged letter");
    }
    return {
      state: {
        ...claimWord(state, action.playerId, action.payload.word, action.payload.path),
        blockedLetter: state.blockedLetter,
      },
    };
  },
  tick(state) {
    return { state };
  },
  getPublicState(state) {
    return { ...getWordGridPublicState(state), blockedLetter: state.blockedLetter };
  },
  getPrivateState: getWordGridPrivateState,
  finish(state) {
    return { state: { ...state, phase: "finished" }, phaseChanged: true, finished: true };
  },
  reset(state) {
    return { ...prepareWordGrid(Object.values(state.players).map(({ id, name }) => ({ id, name })), grid, words), blockedLetter: "Z" };
  },
};
