import type { GameCollection, GameDefinition } from "@/lib/games/types";

export const triviaBranches: GameDefinition[] = [
  {
    id: "trivia-kenya",
    title: "Home Turf",
    kicker: "Kenya & East Africa",
    icon: "sparkles",
    color: "pink",
    template: "trivia_vault_kenya",
    mode: "trivia",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    parentId: "trivia",
    description: "A three-round Kenya and East Africa challenge, from warm-up facts to proper local knowledge.",
    meta: "15 questions · 100 → 200 points · Kenya focus",
    instructions: "Choose an answer on your phone before the timer ends. Each round gets tougher and earns more points.",
  },
  {
    id: "trivia-scitech",
    title: "Brain Buzz",
    kicker: "Science & Technology",
    icon: "sparkles",
    color: "pink",
    template: "trivia_vault_scitech",
    mode: "trivia",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    parentId: "trivia",
    description: "Test the table on science and technology through three escalating rounds.",
    meta: "15 questions · 100 → 200 points · Science + tech",
    instructions: "Start with a warm-up, then progress into technology and the final hard round.",
  },
  {
    id: "trivia-mix",
    title: "Anything Goes",
    kicker: "Mixed knowledge",
    icon: "sparkles",
    color: "pink",
    template: "trivia_vault_mix",
    mode: "trivia",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    parentId: "trivia",
    description: "A broad general-knowledge run for mixed groups, with a clear Easy, Medium and Hard finish.",
    meta: "15 questions · 100 → 200 points · Mixed topics",
    instructions: "Every correct tap scores. The final round is worth the most, so no lead is safe.",
  },
];

export const classicGames: GameDefinition[] = [
  {
    id: "trivia",
    title: "Trivia Vault",
    kicker: "Pick your branch",
    icon: "sparkles",
    color: "pink",
    template: "",
    mode: "trivia",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    description: "Choose a themed quiz branch: Home Turf, Brain Buzz, or Anything Goes.",
    meta: "3 branches · 15 questions · 100 → 200 points",
    instructions: "Pick a Trivia Vault branch before starting.",
  },
  {
    id: "flags",
    title: "Flag Frenzy",
    kicker: "Fastest finger wins",
    icon: "map",
    color: "yellow",
    template: "flag_frenzy_africa",
    mode: "flag_frenzy",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    description: "Spot the country from its flag before the countdown runs down.",
    meta: "15, 30, 45 or 60 flags · 30 seconds each",
    instructions: "A flag will display on the screen. Tap the matching country name as fast as you can to score points!",
  },
  {
    id: "who",
    title: "Who Am I?",
    kicker: "Talk, clue, guess",
    icon: "image",
    color: "lime",
    template: "who_am_i_kenya",
    mode: "who_am_i",
    engine: "identity",
    collection: "mavelas-classics",
    availability: "live",
    description: "One player at a time discovers a famous face through yes-or-no questions from the table.",
    meta: "90 seconds · Private question clipboard · Live table clues",
    instructions: "The guesser has 90 seconds and a private clipboard. Everyone else sees the identity and can send short clues before the final guess.",
  },
  {
    id: "logos",
    title: "Logo Rush",
    kicker: "Name that brand",
    icon: "shapes",
    color: "yellow",
    template: "logo_rush_world",
    mode: "logo_quiz",
    engine: "round-quiz",
    collection: "mavelas-classics",
    availability: "live",
    description: "Recognise familiar international, African and Kenyan brands from their logos.",
    meta: "67-logo library · 20 shuffled rounds · Global + local",
    instructions: "Study the logo on the shared screen, then tap the matching A, B, C or D answer on your phone.",
  },
  {
    id: "image",
    title: "Clue Heist",
    kicker: "Guess early or steal",
    icon: "scan",
    color: "blue",
    template: "clue_heist_classic",
    mode: "guess_image",
    engine: "clue-reveal",
    collection: "mavelas-classics",
    availability: "live",
    description: "Solve a hidden image from up to 20 clues. Every extra clue lowers its value, and missed answers open the heist.",
    meta: "20 clues · 100→5 points · Live steals",
    instructions: "The spotlight player guesses first. A wrong answer opens the steal to everyone else for half the available points.",
  },
];

/** Implemented expansion games remain hidden until their feature flags are
 * explicitly enabled after database and multi-device verification. */
export const expansionGames: GameDefinition[] = [
  { id: "trivia-dash", title: "Trivia Dash", kicker: "Answer and advance", icon: "route", color: "pink", template: "trivia_dash_classic", mode: "trivia_dash", engine: "board-quiz", collection: "quiz-adventures", availability: "live", featureFlag: "trivia-dash", description: "Race across a shared 24-space board through 12 simultaneous trivia rounds.", meta: "12 rounds · +2 correct · streak bonuses", instructions: "Answer correctly to move two spaces. Every third consecutive correct answer adds one bonus space." },
];

/** Safe expansion backlog. Planned entries never enter playableGames. */
export const plannedGames: GameDefinition[] = [
  { id: "trivia-turf", title: "Trivia Turf", kicker: "Claim the map", icon: "grid", color: "lime", template: "", mode: "trivia_turf", engine: "board-quiz", collection: "quiz-adventures", availability: "planned", featureFlag: "trivia-turf", description: "Earn claim tokens through trivia and use them to capture territory.", meta: "Planned · Phase 1", instructions: "Answer correctly, then use your claim tokens on the shared map." },
  { id: "meme-factory", title: "Meme Factory", kicker: "Caption and vote", icon: "laugh", color: "yellow", template: "", mode: "meme_factory", engine: "submission-vote", collection: "creative-social", availability: "planned", featureFlag: "meme-factory", description: "Write anonymous captions for curated meme templates and vote for the best.", meta: "Planned · Phase 2", instructions: "Submit a caption, then vote anonymously." },
  { id: "bluff-and-draw", title: "Bluff & Draw", kicker: "Draw, bluff, guess", icon: "brush", color: "blue", template: "", mode: "bluff_draw", engine: "submission-vote", collection: "creative-social", availability: "planned", featureFlag: "bluff-and-draw", description: "Draw a secret prompt while other players submit believable decoys.", meta: "Planned · Phase 2", instructions: "Draw or submit a bluff, then identify the real prompt." },
  { id: "pixel-painters", title: "Pixel Painters", kicker: "Paint together", icon: "grid", color: "lime", template: "", mode: "pixel_painters", engine: "shared-canvas", collection: "creative-social", availability: "planned", featureFlag: "pixel-painters", description: "Work together on a small shared pixel canvas.", meta: "Planned · Phase 4", instructions: "Place pixels carefully to complete the shared target." },
  { id: "word-sabotage", title: "Word Sabotage", kicker: "Build and disrupt", icon: "letters", color: "pink", template: "", mode: "word_sabotage", engine: "word-grid", collection: "word-games", availability: "planned", featureFlag: "word-sabotage", description: "Build valid words while temporary modifiers reshape the round.", meta: "Planned · Phase 2", instructions: "Submit valid words before the round ends." },
  { id: "word-search-race", title: "Word Search Race", kicker: "Find it first", icon: "search", color: "yellow", template: "", mode: "word_search_race", engine: "word-grid", collection: "word-games", availability: "planned", featureFlag: "word-search-race", description: "Race to find server-validated words on a shared grid.", meta: "Planned · Phase 2", instructions: "Trace a valid word before another player claims it." },
  { id: "auction-chaos", title: "Auction Chaos", kicker: "Bid with nerve", icon: "gavel", color: "yellow", template: "", mode: "auction_chaos", engine: "turn-strategy", collection: "strategy-coop", availability: "planned", featureFlag: "auction-chaos", description: "Bid on mystery lots using server-sequenced turns and limited funds.", meta: "Planned · Phase 3", instructions: "Bid within your balance or pass before time runs out." },
  { id: "bomb-defusal", title: "Bomb Defusal", kicker: "Solve and pass", icon: "bomb", color: "pink", template: "", mode: "bomb_defusal", engine: "asymmetric-coop", collection: "strategy-coop", availability: "planned", featureFlag: "bomb-defusal", description: "Complete tasks and pass control before the hidden fuse expires.", meta: "Planned · Phase 3", instructions: "Finish your task, then pass control to an eligible teammate." },
  { id: "escape-room", title: "Escape Room Co-op", kicker: "Share what you know", icon: "puzzle", color: "blue", template: "", mode: "escape_room", engine: "asymmetric-coop", collection: "strategy-coop", availability: "planned", featureFlag: "escape-room", description: "Combine private instructions and shared clues to solve each module.", meta: "Planned · Phase 3", instructions: "Describe your private information without showing your screen." },
  { id: "cooking-chaos", title: "Cooking Chaos", kicker: "Prepare and pass", icon: "chef", color: "lime", template: "", mode: "cooking_chaos", engine: "state-machine", collection: "strategy-coop", availability: "planned", featureFlag: "cooking-chaos", description: "Move orders through collect, prepare, cook, plate and serve stations.", meta: "Planned · Phase 4", instructions: "Complete your station action and pass the order onward." },
  { id: "tower-defense", title: "Tower Defense", kicker: "Build, then defend", icon: "tower", color: "blue", template: "", mode: "tower_defense", engine: "turn-strategy", collection: "strategy-coop", availability: "planned", featureFlag: "tower-defense", description: "Place and upgrade towers before each automatically resolved wave.", meta: "Planned · Phase 4", instructions: "Build during preparation, then watch the shared wave resolve." },
];

export const playableGames = [
  ...triviaBranches,
  ...classicGames.filter((game) => game.id !== "trivia"),
  ...expansionGames,
];

export const registeredGames = [...classicGames, ...triviaBranches, ...expansionGames, ...plannedGames];

export const gameCollections: GameCollection[] = [
  { id: "mavelas-classics", title: "Mavelas Classics", gameIds: classicGames.map((game) => game.id) },
  { id: "quiz-adventures", title: "Quiz Adventures", gameIds: ["trivia-dash", "trivia-turf"] },
  { id: "creative-social", title: "Creative & Social", gameIds: ["meme-factory", "bluff-and-draw", "pixel-painters"] },
  { id: "word-games", title: "Word Games", gameIds: ["word-sabotage", "word-search-race"] },
  { id: "strategy-coop", title: "Strategy & Co-op", gameIds: ["auction-chaos", "bomb-defusal", "escape-room", "cooking-chaos", "tower-defense"] },
];

const gameTitlesByMode = new Map<string, string>([
  ...classicGames.map((game) => [game.mode, game.title] as const),
  ...triviaBranches.map((game) => [game.id, `Trivia Vault · ${game.title}`] as const),
  ...expansionGames.map((game) => [game.mode, game.title] as const),
  ...plannedGames.map((game) => [game.mode, game.title] as const),
]);

export function findPlayableGame(value: string | null | undefined) {
  if (!value) return undefined;
  return playableGames.find((game) => game.id === value || game.template === value);
}

export function findRegisteredGame(value: string | null | undefined) {
  if (!value) return undefined;
  return registeredGames.find((game) => game.id === value || game.template === value || game.mode === value);
}

export function getGameTitle(mode: string | null | undefined, fallback = "Game Mavelas") {
  if (!mode) return fallback;
  return gameTitlesByMode.get(mode) ?? fallback;
}
