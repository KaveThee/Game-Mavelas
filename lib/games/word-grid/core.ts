export type GridPoint = { row: number; column: number };

export type WordGridClaim = {
  word: string;
  playerId: string;
  points: number;
  path: GridPoint[];
};

export type WordGridState = {
  phase: "prepared" | "playing" | "finished";
  grid: string[][];
  validWords: readonly string[];
  players: Record<string, { id: string; name: string; score: number }>;
  claims: Record<string, WordGridClaim>;
};

export function prepareWordGrid(
  players: readonly { id: string; name: string }[],
  grid: readonly (readonly string[])[],
  validWords: readonly string[],
): WordGridState {
  if (players.length < 1) throw new Error("Word games need at least one active player");
  if (new Set(players.map((player) => player.id)).size !== players.length) {
    throw new Error("Word game player ids must be unique");
  }
  if (grid.length < 3 || grid.some((row) => row.length !== grid.length)) {
    throw new Error("Word grids must be square and at least 3 by 3");
  }

  const normalizedGrid = grid.map((row) => row.map((letter) => letter.toUpperCase()));
  const normalizedWords = [...new Set(validWords.map((word) => word.toUpperCase()))];
  return {
    phase: "prepared",
    grid: normalizedGrid,
    validWords: normalizedWords,
    players: Object.fromEntries(players.map((player) => [player.id, { ...player, score: 0 }])),
    claims: {},
  };
}

function validatePath(grid: string[][], word: string, path: GridPoint[]) {
  if (path.length !== word.length) throw new Error("Word path does not match the submitted word");
  const seen = new Set<string>();

  path.forEach((point, index) => {
    if (!Number.isInteger(point.row) || !Number.isInteger(point.column)) throw new Error("Word path is invalid");
    if (point.row < 0 || point.column < 0 || point.row >= grid.length || point.column >= grid.length) {
      throw new Error("Word path leaves the grid");
    }
    const key = `${point.row}:${point.column}`;
    if (seen.has(key)) throw new Error("A grid cell cannot be reused in one word");
    seen.add(key);
    if (grid[point.row][point.column] !== word[index]) throw new Error("Word path letters do not match");

    const previous = path[index - 1];
    if (previous && (Math.abs(previous.row - point.row) > 1 || Math.abs(previous.column - point.column) > 1)) {
      throw new Error("Word path cells must touch");
    }
  });
}

export function claimWord(
  state: WordGridState,
  playerId: string,
  inputWord: string,
  path: GridPoint[],
): WordGridState {
  if (state.phase !== "playing") throw new Error("Word claims are closed");
  const player = state.players[playerId];
  if (!player) throw new Error("Player is not part of this session");

  const word = inputWord.trim().toUpperCase();
  if (word.length < 3 || word.length > state.grid.length * state.grid.length) throw new Error("Word length is invalid");
  if (!state.validWords.includes(word)) throw new Error("Word is not in the server-approved list");
  if (state.claims[word]) throw new Error("Word has already been claimed");
  validatePath(state.grid, word, path);

  const points = word.length;
  return {
    ...state,
    players: { ...state.players, [playerId]: { ...player, score: player.score + points } },
    claims: { ...state.claims, [word]: { word, playerId, points, path } },
  };
}

export function getWordGridPublicState(state: WordGridState) {
  return {
    phase: state.phase,
    grid: state.grid,
    claims: Object.values(state.claims).map(({ word, playerId, points }) => ({
      word,
      playerName: state.players[playerId]?.name ?? "Player",
      points,
    })),
    leaderboard: Object.values(state.players)
      .map(({ id, name, score }) => ({ id, name, score }))
      .sort((left, right) => right.score - left.score || left.name.localeCompare(right.name)),
  };
}

export function getWordGridPrivateState(state: WordGridState, playerId: string) {
  if (!state.players[playerId]) throw new Error("Player is not part of this session");
  return {
    playerId,
    claimedWords: Object.values(state.claims)
      .filter((claim) => claim.playerId === playerId)
      .map((claim) => claim.word),
  };
}
