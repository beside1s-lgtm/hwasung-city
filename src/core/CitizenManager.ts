import { CitizenAgent, GameState } from '../types';
import { MobilizationManager, LoyaltyBranch } from './MobilizationManager';
import { MilitaryManager } from './MilitaryManager';

export class CitizenManager {
  public citizens: CitizenAgent[] = [];
  public mobilization = new MobilizationManager();
  public military = new MilitaryManager();

  constructor(citizens: CitizenAgent[] = []) {
    this.citizens = citizens;
  }

  public triggerWartimeMobilization(state: GameState, targetGate: { x: number; y: number }): {
    branch: LoyaltyBranch;
    militia: number;
    supplies: number;
    traitors: number;
  } {
    const res = this.mobilization.mobilize(this.citizens, state, targetGate);
    return {
      branch: res.branch,
      militia: res.militiaCount,
      supplies: res.supplyCount,
      traitors: res.traitorCount
    };
  }

  public rollbackWartimeMobilization(state: GameState): void {
    this.mobilization.demobilize(this.citizens, state);
  }

  public update(delta: number): void {
    for (const citizen of this.citizens) {
      citizen.animFrame = (citizen.animFrame + delta * citizen.speed) % 4;
      const dx = citizen.targetX - citizen.x;
      const dy = citizen.targetY - citizen.y;
      const dist = Math.hypot(dx, dy);
      if (dist > 0.05) {
        const step = Math.min(dist, citizen.speed * delta);
        citizen.x += (dx / dist) * step;
        citizen.y += (dy / dist) * step;
      }
    }
  }

  /**
   * 3칸 근접 도달 판정 (Proximity Arrival):
   * 목적지 건물로부터 체비쇼프(Chebyshev) 3칸 반경 이내 도달 시 도착으로 판정
   */
  public hasReachedProximity(citizen: CitizenAgent, threshold = 3.0): boolean {
    const cDist = Math.max(Math.abs(citizen.targetX - citizen.x), Math.abs(citizen.targetY - citizen.y));
    return cDist <= threshold;
  }
}
