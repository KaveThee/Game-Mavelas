import type { MavelasRoomPhase } from "./state-boundaries.ts";
import type { GameAction, GameModule, GameRuntimeContext } from "./types.ts";

const MAX_RECENT_ACTION_IDS = 512;

const allowedTransitions: Record<MavelasRoomPhase, ReadonlySet<MavelasRoomPhase>> = {
  lobby: new Set(["selected", "closed"]),
  selected: new Set(["lobby", "playing", "closed"]),
  playing: new Set(["all_answered", "revealed", "results", "closed"]),
  all_answered: new Set(["revealed", "closed"]),
  revealed: new Set(["playing", "results", "closed"]),
  results: new Set(["lobby", "selected", "playing", "closed"]),
  closed: new Set(),
};

export type VersionedGameSession<TState> = {
  roomId: string;
  sessionId: string;
  gameId: string;
  phase: MavelasRoomPhase;
  stateVersion: number;
  state: TState;
  processedActionIds: readonly string[];
  lastActionSequenceByPlayer: Readonly<Record<string, number>>;
};

export type ActionOutcome = "applied" | "duplicate" | "stale" | "out_of_order";

export type ActionApplication<TState> = {
  outcome: ActionOutcome;
  session: VersionedGameSession<TState>;
};

export function createVersionedGameSession<TState>(input: {
  roomId: string;
  sessionId: string;
  gameId: string;
  state: TState;
  phase?: MavelasRoomPhase;
}): VersionedGameSession<TState> {
  return {
    ...input,
    phase: input.phase ?? "selected",
    stateVersion: 0,
    processedActionIds: [],
    lastActionSequenceByPlayer: {},
  };
}

export function transitionGameSession<TState>(
  session: VersionedGameSession<TState>,
  nextPhase: MavelasRoomPhase,
): VersionedGameSession<TState> {
  if (nextPhase === session.phase) return session;
  if (!allowedTransitions[session.phase].has(nextPhase)) {
    throw new Error(`Illegal game phase transition: ${session.phase} -> ${nextPhase}`);
  }

  return {
    ...session,
    phase: nextPhase,
    stateVersion: session.stateVersion + 1,
  };
}

export function applyGameActionOnce<TState, TActionPayload, TPublicState, TPrivateState>(
  session: VersionedGameSession<TState>,
  gameModule: GameModule<TState, TActionPayload, TPublicState, TPrivateState>,
  action: GameAction<TActionPayload>,
  context: GameRuntimeContext,
): ActionApplication<TState> {
  if (gameModule.definition.id !== session.gameId) {
    throw new Error(`Module ${gameModule.definition.id} cannot handle session for ${session.gameId}`);
  }

  if (session.processedActionIds.includes(action.id)) return { outcome: "duplicate", session };

  const previousSequence = session.lastActionSequenceByPlayer[action.playerId] ?? 0;
  if (action.sequence <= previousSequence) return { outcome: "stale", session };
  if (action.sequence !== previousSequence + 1) return { outcome: "out_of_order", session };

  const transition = gameModule.handleAction(session.state, action, context);
  const processedActionIds = [...session.processedActionIds, action.id].slice(-MAX_RECENT_ACTION_IDS);

  return {
    outcome: "applied",
    session: {
      ...session,
      state: transition.state,
      stateVersion: session.stateVersion + 1,
      processedActionIds,
      lastActionSequenceByPlayer: {
        ...session.lastActionSequenceByPlayer,
        [action.playerId]: action.sequence,
      },
    },
  };
}
