import { isGameEnabled } from "./feature-flags.ts";
import { findRegisteredGame } from "./registry.ts";
import type { GameModule } from "./types.ts";

type LoadedGameModule = GameModule<unknown, unknown, unknown, unknown>;

/**
 * Runtime catalog for modular games. Classics keep using their existing RPCs;
 * an expansion becomes resolvable only after it is registered, implemented,
 * promoted to `live`, and enabled by its build-time feature flag.
 */
export class GameModuleLoader {
  private readonly modules = new Map<string, LoadedGameModule>();

  register<TState, TActionPayload, TPublicState, TPrivateState>(
    gameModule: GameModule<TState, TActionPayload, TPublicState, TPrivateState>,
  ) {
    const definition = findRegisteredGame(gameModule.definition.id);
    if (!definition) throw new Error(`Cannot register unknown game: ${gameModule.definition.id}`);
    if (definition !== gameModule.definition) {
      throw new Error(`Game module must use the canonical registry definition: ${gameModule.definition.id}`);
    }
    if (this.modules.has(definition.id)) throw new Error(`Game module already registered: ${definition.id}`);

    this.modules.set(definition.id, gameModule as LoadedGameModule);
  }

  has(gameId: string) {
    return this.modules.has(gameId);
  }

  get(gameId: string) {
    return this.modules.get(gameId);
  }

  requirePlayable(gameId: string) {
    const definition = findRegisteredGame(gameId);
    if (!definition) throw new Error(`Unknown game: ${gameId}`);
    if (!isGameEnabled(definition)) throw new Error(`Game is not enabled: ${gameId}`);

    const gameModule = this.modules.get(definition.id);
    if (!gameModule) throw new Error(`Game module is not loaded: ${gameId}`);
    return gameModule;
  }
}
