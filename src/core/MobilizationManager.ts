import { CitizenAgent, GameState } from '../types';

export enum LoyaltyBranch {
  UNITED_RESISTANCE = 'UNITED_RESISTANCE',
  NORMAL_MILITIA = 'NORMAL_MILITIA',
  TREASON_BETRAYAL = 'TREASON_BETRAYAL'
}

export interface MobilizationBackup {
  id: number;
  originalType: CitizenAgent['type'];
  originalAction: CitizenAgent['action'];
  targetX: number;
  targetY: number;
}

export class MobilizationManager {
  public isWartimeMobilized = false;
  public currentBranch: LoyaltyBranch = LoyaltyBranch.NORMAL_MILITIA;
  public combatBuff = 1.0;
  public supplyMitigationRatio = 0.0;
  public betrayedGate: { x: number; y: number } | null = null;

  private backupAgents = new Map<number, MobilizationBackup>();

  public evaluateLoyaltyBranch(loyalty: number, authority: number): LoyaltyBranch {
    if (loyalty >= 70 && authority >= 60) {
      return LoyaltyBranch.UNITED_RESISTANCE;
    } else if (loyalty < 40 || authority < 30) {
      return LoyaltyBranch.TREASON_BETRAYAL;
    } else {
      return LoyaltyBranch.NORMAL_MILITIA;
    }
  }

  public mobilize(citizens: CitizenAgent[], state: GameState, targetGate: { x: number; y: number }): {
    success: boolean;
    branch: LoyaltyBranch;
    militiaCount: number;
    supplyCount: number;
    traitorCount: number;
    combatBuff: number;
  } {
    if (this.isWartimeMobilized) {
      return {
        success: false,
        branch: this.currentBranch,
        militiaCount: 0,
        supplyCount: 0,
        traitorCount: 0,
        combatBuff: this.combatBuff
      };
    }

    this.isWartimeMobilized = true;
    this.backupAgents.clear();
    this.betrayedGate = null;

    this.currentBranch = this.evaluateLoyaltyBranch(state.loyalty, state.authority);

    switch (this.currentBranch) {
      case LoyaltyBranch.UNITED_RESISTANCE:
        this.combatBuff = 1.3;
        this.supplyMitigationRatio = 0.20;
        break;
      case LoyaltyBranch.NORMAL_MILITIA:
        this.combatBuff = 1.0;
        this.supplyMitigationRatio = 0.20;
        break;
      case LoyaltyBranch.TREASON_BETRAYAL:
        this.combatBuff = 0.7;
        this.supplyMitigationRatio = 0.0;
        break;
    }

    let militiaCount = 0;
    let supplyCount = 0;
    let traitorCount = 0;

    for (const citizen of citizens) {
      this.backupAgents.set(citizen.id, {
        id: citizen.id,
        originalType: citizen.type,
        originalAction: citizen.action,
        targetX: citizen.targetX,
        targetY: citizen.targetY
      });

      if (this.currentBranch === LoyaltyBranch.TREASON_BETRAYAL) {
        const roll = Math.random();
        if (roll < 0.40) {
          // 동원 거부
          continue;
        } else if (roll > 0.85 && traitorCount < 2) {
          traitorCount++;
          this.betrayedGate = targetGate;
          citizen.targetX = targetGate.x;
          citizen.targetY = targetGate.y;
          citizen.action = 'walk';
          continue;
        }
      }

      if (citizen.type === 'carrier' || Math.random() < 0.35) {
        supplyCount++;
        citizen.targetX = targetGate.x + Math.floor(Math.random() * 3) - 1;
        citizen.targetY = targetGate.y + Math.floor(Math.random() * 3) - 1;
        citizen.action = 'work';
      } else {
        militiaCount++;
        citizen.type = 'guard'; // 민병대
        citizen.targetX = targetGate.x;
        citizen.targetY = targetGate.y;
        citizen.action = 'work';
      }
    }

    state.isWartimeMobilized = true;

    return {
      success: true,
      branch: this.currentBranch,
      militiaCount,
      supplyCount,
      traitorCount,
      combatBuff: this.combatBuff
    };
  }

  public demobilize(citizens: CitizenAgent[], state: GameState): void {
    if (!this.isWartimeMobilized) return;
    this.isWartimeMobilized = false;

    for (const citizen of citizens) {
      const backup = this.backupAgents.get(citizen.id);
      if (backup) {
        citizen.type = backup.originalType;
        citizen.action = backup.originalAction;
        citizen.targetX = backup.targetX;
        citizen.targetY = backup.targetY;
      }
    }

    this.backupAgents.clear();
    this.betrayedGate = null;
    state.isWartimeMobilized = false;
  }
}
