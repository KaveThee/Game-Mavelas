export type MavelasRoomPhase =
  | "lobby"
  | "selected"
  | "playing"
  | "all_answered"
  | "revealed"
  | "results"
  | "closed";

export type PublicGameSession<TPublicState> = {
  audience: "display";
  roomId: string;
  sessionId: string;
  gameId: string;
  phase: MavelasRoomPhase;
  stateVersion: number;
  startedAt: string | null;
  endsAt: string | null;
  state: TPublicState;
};

export type PrivateGameSession<TPrivateState> = {
  audience: "controller";
  roomId: string;
  sessionId: string;
  gameId: string;
  playerId: string;
  isHost: boolean;
  phase: MavelasRoomPhase;
  stateVersion: number;
  state: TPrivateState;
};

const ALWAYS_PRIVATE_KEYS = new Set([
  "answerkey",
  "correctoptionid",
  "hiddenmediaurl",
  "privatemediaurl",
  "privatestate",
  "realprompt",
  "secretidentity",
  "selectedoptionid",
]);

const REVEAL_ONLY_KEYS = new Set([
  "answer",
  "correctoption",
  "iscorrect",
]);

const REVEAL_PHASES = new Set<MavelasRoomPhase>(["revealed", "results", "closed"]);

function normalizedKey(key: string) {
  return key.replace(/[^a-z0-9]/gi, "").toLowerCase();
}

function collectPublicStateLeaks(
  value: unknown,
  phase: MavelasRoomPhase,
  path: string,
  leaks: string[],
) {
  if (value === null || value === undefined || typeof value !== "object") return;

  if (Array.isArray(value)) {
    value.forEach((entry, index) => collectPublicStateLeaks(entry, phase, `${path}[${index}]`, leaks));
    return;
  }

  for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
    const entryPath = path ? `${path}.${key}` : key;
    const safeKey = normalizedKey(key);

    if (entry !== null && entry !== undefined) {
      if (ALWAYS_PRIVATE_KEYS.has(safeKey)) leaks.push(entryPath);
      if (REVEAL_ONLY_KEYS.has(safeKey) && !REVEAL_PHASES.has(phase)) leaks.push(entryPath);
    }

    collectPublicStateLeaks(entry, phase, entryPath, leaks);
  }
}

/**
 * Fails closed when an RPC accidentally places controller-only or early-reveal
 * information in a public display payload. This supplements RLS and sanitized
 * public RPCs; it does not replace server-side authorization.
 */
export function assertPublicStateSafe(value: unknown, phase: MavelasRoomPhase) {
  const leaks: string[] = [];
  collectPublicStateLeaks(value, phase, "", leaks);

  if (leaks.length > 0) {
    throw new Error(`Unsafe public game state at: ${leaks.join(", ")}`);
  }
}

export function asMavelasRoomPhase(value: unknown): MavelasRoomPhase {
  switch (value) {
    case "lobby":
    case "selected":
    case "playing":
    case "all_answered":
    case "revealed":
    case "results":
    case "closed":
      return value;
    default:
      return "lobby";
  }
}
