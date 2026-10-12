export const MAX_SUBMISSION_LENGTH = 180;

export type SubmissionVotePhase = "prepared" | "submitting" | "voting" | "results" | "finished";

export type SubmissionVotePlayer = {
  id: string;
  name: string;
  score: number;
};

export type PrivateSubmission = {
  id: string;
  authorId: string;
  text: string;
};

export type SubmissionVoteState = {
  phase: SubmissionVotePhase;
  prompt: string;
  players: Record<string, SubmissionVotePlayer>;
  submissions: Record<string, PrivateSubmission>;
  votes: Record<string, string>;
};

export type SubmissionVoteActionPayload =
  | { kind: "submit"; text: string }
  | { kind: "begin_voting" }
  | { kind: "vote"; submissionId: string }
  | { kind: "reveal_results" };

export function prepareSubmissionVote(
  players: readonly { id: string; name: string }[],
  prompt: string,
): SubmissionVoteState {
  if (players.length < 2) throw new Error("Submission games need at least two active players");
  if (new Set(players.map((player) => player.id)).size !== players.length) {
    throw new Error("Submission game player ids must be unique");
  }

  return {
    phase: "prepared",
    prompt,
    players: Object.fromEntries(players.map((player) => [player.id, { ...player, score: 0 }])),
    submissions: {},
    votes: {},
  };
}

function normalizeSubmission(text: string) {
  return text.replace(/\s+/g, " ").trim();
}

function requireSystem(playerId: string) {
  if (playerId !== "system") throw new Error("Only the server can change submission phases");
}

export function handleSubmissionVoteAction(
  state: SubmissionVoteState,
  playerId: string,
  payload: SubmissionVoteActionPayload,
): SubmissionVoteState {
  if (payload.kind === "submit") {
    if (state.phase !== "submitting") throw new Error("Submissions are closed");
    if (!state.players[playerId]) throw new Error("Player is not part of this session");
    if (state.submissions[playerId]) throw new Error("Player already submitted this round");

    const text = normalizeSubmission(payload.text);
    if (text.length < 2 || text.length > MAX_SUBMISSION_LENGTH) {
      throw new Error(`Submission must be between 2 and ${MAX_SUBMISSION_LENGTH} characters`);
    }

    return {
      ...state,
      submissions: {
        ...state.submissions,
        [playerId]: {
          id: `entry-${Object.keys(state.submissions).length + 1}`,
          authorId: playerId,
          text,
        },
      },
    };
  }

  if (payload.kind === "begin_voting") {
    requireSystem(playerId);
    if (state.phase !== "submitting") throw new Error("Voting can only follow submissions");
    if (Object.keys(state.submissions).length < 2) throw new Error("Voting needs at least two submissions");
    return { ...state, phase: "voting" };
  }

  if (payload.kind === "vote") {
    if (state.phase !== "voting") throw new Error("Voting is closed");
    if (!state.players[playerId]) throw new Error("Player is not part of this session");
    if (state.votes[playerId]) throw new Error("Player already voted this round");

    const submission = Object.values(state.submissions).find((entry) => entry.id === payload.submissionId);
    if (!submission) throw new Error("Submission is not part of this round");
    if (submission.authorId === playerId) throw new Error("Players cannot vote for their own submission");

    return { ...state, votes: { ...state.votes, [playerId]: submission.id } };
  }

  requireSystem(playerId);
  if (state.phase !== "voting") throw new Error("Results can only follow voting");

  const pointsByPlayer: Record<string, number> = {};
  for (const submissionId of Object.values(state.votes)) {
    const submission = Object.values(state.submissions).find((entry) => entry.id === submissionId);
    if (submission) pointsByPlayer[submission.authorId] = (pointsByPlayer[submission.authorId] ?? 0) + 1;
  }

  return {
    ...state,
    phase: "results",
    players: Object.fromEntries(
      Object.values(state.players).map((player) => [
        player.id,
        { ...player, score: player.score + (pointsByPlayer[player.id] ?? 0) },
      ]),
    ),
  };
}

export function getSubmissionVotePublicState(state: SubmissionVoteState) {
  const entries = Object.values(state.submissions).map((submission) => ({
    id: submission.id,
    text: state.phase === "submitting" || state.phase === "prepared" ? null : submission.text,
    authorName: state.phase === "results" || state.phase === "finished"
      ? state.players[submission.authorId]?.name ?? "Player"
      : null,
    voteCount: state.phase === "results" || state.phase === "finished"
      ? Object.values(state.votes).filter((submissionId) => submissionId === submission.id).length
      : null,
  }));

  return {
    phase: state.phase,
    prompt: state.prompt,
    submittedCount: Object.keys(state.submissions).length,
    votedCount: Object.keys(state.votes).length,
    entries,
    leaderboard: Object.values(state.players)
      .map(({ id, name, score }) => ({ id, name, score }))
      .sort((left, right) => right.score - left.score || left.name.localeCompare(right.name)),
  };
}

export function getSubmissionVotePrivateState(state: SubmissionVoteState, playerId: string) {
  if (!state.players[playerId]) throw new Error("Player is not part of this session");
  return {
    playerId,
    ownSubmission: state.submissions[playerId]?.text ?? null,
    hasSubmitted: Boolean(state.submissions[playerId]),
    hasVoted: Boolean(state.votes[playerId]),
  };
}
