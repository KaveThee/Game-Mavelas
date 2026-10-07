import type { GameDefinition } from "@/lib/games/types";

const expansionFlags: Record<string, boolean> = {
  "trivia-dash": process.env.NEXT_PUBLIC_GAME_TRIVIA_DASH_ENABLED === "true",
  "trivia-turf": process.env.NEXT_PUBLIC_GAME_TRIVIA_TURF_ENABLED === "true",
  "meme-factory": process.env.NEXT_PUBLIC_GAME_MEME_FACTORY_ENABLED === "true",
  "bluff-and-draw": process.env.NEXT_PUBLIC_GAME_BLUFF_DRAW_ENABLED === "true",
  "pixel-painters": process.env.NEXT_PUBLIC_GAME_PIXEL_PAINTERS_ENABLED === "true",
  "word-sabotage": process.env.NEXT_PUBLIC_GAME_WORD_SABOTAGE_ENABLED === "true",
  "word-search-race": process.env.NEXT_PUBLIC_GAME_WORD_SEARCH_RACE_ENABLED === "true",
  "auction-chaos": process.env.NEXT_PUBLIC_GAME_AUCTION_CHAOS_ENABLED === "true",
  "bomb-defusal": process.env.NEXT_PUBLIC_GAME_BOMB_DEFUSAL_ENABLED === "true",
  "escape-room": process.env.NEXT_PUBLIC_GAME_ESCAPE_ROOM_ENABLED === "true",
  "cooking-chaos": process.env.NEXT_PUBLIC_GAME_COOKING_CHAOS_ENABLED === "true",
  "tower-defense": process.env.NEXT_PUBLIC_GAME_TOWER_DEFENSE_ENABLED === "true",
};

/**
 * A game must be implemented and explicitly enabled. Planned registry entries
 * remain unreachable even if somebody sets an environment variable early.
 */
export function isGameEnabled(game: GameDefinition) {
  if (game.availability !== "live") return false;
  if (!game.featureFlag) return true;
  return expansionFlags[game.featureFlag] === true;
}
