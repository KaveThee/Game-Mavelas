export type GameEngineKind =
  | "round-quiz"
  | "identity"
  | "clue-reveal"
  | "board-quiz"
  | "submission-vote"
  | "word-grid"
  | "turn-strategy"
  | "asymmetric-coop"
  | "shared-canvas"
  | "state-machine";

export type GameAvailability = "live" | "planned";

export type GameCollectionId =
  | "mavelas-classics"
  | "quiz-adventures"
  | "creative-social"
  | "word-games"
  | "strategy-coop";

export type GameIconKey =
  | "sparkles"
  | "map"
  | "image"
  | "shapes"
  | "scan"
  | "grid"
  | "route"
  | "laugh"
  | "brush"
  | "letters"
  | "search"
  | "gavel"
  | "bomb"
  | "puzzle"
  | "chef"
  | "tower";

export type GameColor = "pink" | "yellow" | "lime" | "blue";

export type GameDefinition = {
  id: string;
  title: string;
  kicker: string;
  description: string;
  meta: string;
  instructions: string;
  template: string;
  mode: string;
  engine: GameEngineKind;
  collection: GameCollectionId;
  icon: GameIconKey;
  color: GameColor;
  availability: GameAvailability;
  featureFlag?: string;
  parentId?: string;
};

export type GameCollection = {
  id: GameCollectionId;
  title: string;
  gameIds: readonly string[];
};

export type GameAction<TPayload = unknown> = {
  id: string;
  type: string;
  playerId: string;
  sequence: number;
  createdAt: string;
  payload: TPayload;
};

export type GameRuntimeContext = {
  roomId: string;
  sessionId: string;
  now: string;
  players?: readonly {
    id: string;
    name: string;
  }[];
};

export type GameTransition<TState> = {
  state: TState;
  phaseChanged?: boolean;
  finished?: boolean;
};

/**
 * Contract for expansion games. Existing Classics continue using their current
 * RPCs until they are migrated one at a time behind regression tests.
 */
export interface GameModule<
  TState,
  TActionPayload = unknown,
  TPublicState = unknown,
  TPrivateState = unknown,
> {
  definition: GameDefinition;
  prepare(context: GameRuntimeContext): Promise<TState> | TState;
  start(state: TState, context: GameRuntimeContext): GameTransition<TState>;
  handleAction(
    state: TState,
    action: GameAction<TActionPayload>,
    context: GameRuntimeContext,
  ): GameTransition<TState>;
  tick(state: TState, context: GameRuntimeContext): GameTransition<TState>;
  getPublicState(state: TState): TPublicState;
  getPrivateState(state: TState, playerId: string): TPrivateState;
  finish(state: TState, context: GameRuntimeContext): GameTransition<TState>;
  reset(state: TState, context: GameRuntimeContext): Promise<TState> | TState;
}
