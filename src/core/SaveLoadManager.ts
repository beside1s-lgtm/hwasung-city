import { GameState, TileData } from '../types';
import { MilitaryManager } from './MilitaryManager';

export class SaveLoadManager {
  public static saveGame(state: GameState, grid: TileData[][]): string {
    const payload = {
      state: {
        ...state,
        defensePower: state.defensePower ?? 1000,
        repairState: state.repairState ?? { isRepairing: false, repairType: 'none', turnsLeft: 0 },
        isWartimeMobilized: state.isWartimeMobilized ?? false,
        troopRoster: state.troopRoster ?? new MilitaryManager().computeRoster(state.military ?? 70)
      },
      grid,
      timestamp: new Date().toISOString()
    };
    return JSON.stringify(payload, null, 2);
  }

  public static loadGame(jsonStr: string): { state: GameState; grid: TileData[][] } | null {
    try {
      const data = JSON.parse(jsonStr);
      if (!data || !data.state || !data.grid) return null;

      const state: GameState = data.state;
      // Fallback for backward compatibility
      if (state.defensePower === undefined) {
        state.defensePower = 1000;
      }
      if (!state.repairState) {
        state.repairState = { isRepairing: false, repairType: 'none', turnsLeft: 0 };
      }
      if (state.isWartimeMobilized === undefined) {
        state.isWartimeMobilized = false;
      }
      if (!state.troopRoster) {
        state.troopRoster = new MilitaryManager().computeRoster(state.military ?? 70);
      }

      return {
        state,
        grid: data.grid
      };
    } catch {
      return null;
    }
  }
}
