import { findRegisteredGame } from "../registry.ts";
import {
  getSubmissionVotePrivateState,
  getSubmissionVotePublicState,
  handleSubmissionVoteAction,
  prepareSubmissionVote,
  type SubmissionVoteActionPayload,
  type SubmissionVoteState,
} from "../submission-vote/core.ts";
import type { GameModule } from "../types.ts";

const prompts = [
  "When the Wi-Fi returns after everyone blamed the router",
  "That look when the group says the meeting will only take ten minutes",
  "When the host says one final round",
];

const definition = findRegisteredGame("meme-factory");
if (!definition) throw new Error("Meme Factory is missing from the game registry");

function selectPrompt(roomId: string) {
  const seed = [...roomId].reduce((total, character) => total + character.charCodeAt(0), 0);
  return prompts[seed % prompts.length];
}

export const memeFactoryModule: GameModule<
  SubmissionVoteState,
  SubmissionVoteActionPayload,
  ReturnType<typeof getSubmissionVotePublicState>,
  ReturnType<typeof getSubmissionVotePrivateState>
> = {
  definition,
  prepare(context) {
    return prepareSubmissionVote(context.players ?? [], selectPrompt(context.roomId));
  },
  start(state) {
    if (state.phase !== "prepared") throw new Error("Meme Factory can only start from prepared state");
    return { state: { ...state, phase: "submitting" }, phaseChanged: true };
  },
  handleAction(state, action) {
    const next = handleSubmissionVoteAction(state, action.playerId, action.payload);
    return { state: next, phaseChanged: next.phase !== state.phase };
  },
  tick(state) {
    return { state };
  },
  getPublicState: getSubmissionVotePublicState,
  getPrivateState: getSubmissionVotePrivateState,
  finish(state) {
    return { state: { ...state, phase: "finished" }, phaseChanged: true, finished: true };
  },
  reset(state, context) {
    return prepareSubmissionVote(
      Object.values(state.players).map(({ id, name }) => ({ id, name })),
      selectPrompt(`${context.roomId}:${context.now}`),
    );
  },
};
