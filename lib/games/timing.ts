export const GAME_TIMING = {
  allAnswersHoldMs: 3_100,
  revealHoldMs: 6_200,
  controllerRecoveryPollMs: 4_000,
  displayPollMs: 1_000,
  countdownTickMs: 250,
  triviaDashAnswerSeconds: 25,
} as const;

const DISPLAY_FIRST_MODES = new Set([
  "trivia",
  "flag_frenzy",
  "logo_quiz",
  "trivia_dash",
]);

/** Modes whose shared-screen question must be visible before phone inputs unlock. */
export function hasDisplayFirstLead(gameMode?: string | null) {
  return Boolean(gameMode && DISPLAY_FIRST_MODES.has(gameMode));
}
