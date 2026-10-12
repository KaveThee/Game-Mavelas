import { GameModuleLoader } from "./module-loader.ts";
import { bluffAndDrawModule } from "./bluff-and-draw/module.ts";
import { memeFactoryModule } from "./meme-factory/module.ts";
import { triviaDashModule } from "./trivia-dash/module.ts";
import { wordSabotageModule } from "./word-sabotage/module.ts";
import { wordSearchRaceModule } from "./word-search-race/module.ts";

export const gameModuleCatalog = new GameModuleLoader();

// Registered for development and contract testing. The loader still refuses
// to resolve Trivia Dash until its registry status is live and its feature
// flag is enabled after database and multi-device verification.
gameModuleCatalog.register(triviaDashModule);

// Phase 2 modules are contract-testable but remain planned and therefore
// cannot be selected by a live room before database and multi-device review.
gameModuleCatalog.register(memeFactoryModule);
gameModuleCatalog.register(bluffAndDrawModule);
gameModuleCatalog.register(wordSabotageModule);
gameModuleCatalog.register(wordSearchRaceModule);
