import { TileData, GameState } from '../types';
import { WallLoopValidator, LoopValidationResult } from './WallLoopValidator';

export class WallManager {
  public loopValidator = new WallLoopValidator();

  public static readonly WALL_CONNECTORS = [
    'wall', 'gate', 'seojangdae', 'bongdon', 'gongsimdon',
    'gongsimdon_wall', 'poru', 'yeonmudae', 'banghwasuryu', 'hwahong', 'namsu'
  ];

  public isWallConnector(grid: TileData[][], x: number, y: number): boolean {
    if (y < 0 || y >= grid.length || x < 0 || x >= grid[0].length) return false;
    const b = grid[y][x].building;
    return b !== null && WallManager.WALL_CONNECTORS.includes(b);
  }

  public getWallMask(grid: TileData[][], x: number, y: number): number {
    let mask = 0;
    if (this.isWallConnector(grid, x, y - 1)) mask |= 1;
    if (this.isWallConnector(grid, x + 1, y)) mask |= 2;
    if (this.isWallConnector(grid, x, y + 1)) mask |= 4;
    if (this.isWallConnector(grid, x - 1, y)) mask |= 8;
    return mask;
  }

  public updateFortressProgress(grid: TileData[][], state: GameState): LoopValidationResult {
    let wallCount = 0;
    for (const row of grid) {
      for (const t of row) {
        if (!t.underConstruction && t.building && WallManager.WALL_CONNECTORS.includes(t.building)) {
          wallCount++;
        }
      }
    }

    const mult = state.retainers.jeong ? 1.8 : 1.0;
    const rawProgress = Math.min(100, Math.floor((wallCount / 28) * 100 * mult));

    const loopRes = this.loopValidator.validateLoop(grid, rawProgress);
    if (loopRes.isClosedLoop) {
      state.fortressProgress = Math.min(100, rawProgress);
    } else {
      state.fortressProgress = Math.min(99, rawProgress);
    }

    return loopRes;
  }

  public onWallChanged(): void {
    this.loopValidator.invalidate();
  }
}
