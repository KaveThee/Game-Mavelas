import { GameModuleLoader } from "./module-loader.ts";
import { triviaDashModule } from "./trivia-dash/module.ts";

export const gameModuleCatalog = new GameModuleLoader();

// Registered for development and contract testing. The loader still refuses
// to resolve Trivia Dash until its registry status is live and its feature
// flag is enabled after database and multi-device verification.
gameModuleCatalog.register(triviaDashModule);
