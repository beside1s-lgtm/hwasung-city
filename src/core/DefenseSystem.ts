import { GameState, TileData, RepairState } from '../types';
import { MobilizationManager } from './MobilizationManager';

export class DefenseSystem {
  public defensePower = 1000;
  public defenseFatigue = 0;
  public repairState: RepairState = {
    isRepairing: false,
    repairType: 'none',
    turnsLeft: 0
  };
  public isWartimeMobilized = false;
  public mobilization = new MobilizationManager();

  public computeDefensePower(state: GameState, grid: TileData[][]): number {
    const wallRatio = Math.min(1.0, state.fortressProgress / 100.0) * 400.0;
    
    let militaryCount = 0;
    const milTypes = ['seojangdae', 'bongdon', 'gongsimdon', 'poru', 'yeonmudae', 'patrol'];
    for (const row of grid) {
      for (const t of row) {
        if (t.building && milTypes.includes(t.building) && !t.underConstruction) {
          militaryCount++;
        }
      }
    }

    const milScore = Math.min(10, militaryCount) * 30.0;
    const jangScore = state.retainers.baek ? 300.0 : 0.0;
    const taxScore = Math.min(100.0, Math.max(-100.0, (state.taxRates.militaryTax - 7.0) * 20.0));

    let baseDef = Math.floor(wallRatio + milScore + jangScore + taxScore) - this.defenseFatigue;

    if (this.isWartimeMobilized) {
      if (this.mobilization.combatBuff > 1.0) {
        baseDef = Math.floor(baseDef * this.mobilization.combatBuff);
      } else if (this.mobilization.betrayedGate) {
        baseDef -= 200; // 배신으로 인한 방호력 급락
      }
    }

    this.defensePower = Math.min(1000, Math.max(0, baseDef));
    state.defensePower = this.defensePower;
    state.repairState = this.repairState;
    state.isWartimeMobilized = this.isWartimeMobilized;
    return this.defensePower;
  }

  public emergencyRepair(state: GameState): { success: boolean; message: string } {
    const costGold = 600;
    const costRice = 300;
    if (state.gold < costGold || state.rice < costRice) {
      return { success: false, message: `재정 부족 (필요: 금 ${costGold}냥, 곡 ${costRice}석)` };
    }

    state.gold -= costGold;
    state.rice -= costRice;
    this.defenseFatigue = Math.max(0, this.defenseFatigue - 300);
    this.repairState = { isRepairing: false, repairType: 'none', turnsLeft: 0 };
    return { success: true, message: '긴급 땜질 보수 완료: 방호력 300 즉시 회복' };
  }

  public startGrandRepair(state: GameState): { success: boolean; message: string } {
    this.repairState = {
      isRepairing: true,
      repairType: 'grand',
      turnsLeft: 6
    };
    state.repairState = this.repairState;
    return { success: true, message: '수축 대역사 발주 완료' };
  }

  public cancelGrandRepair(state: GameState): void {
    this.repairState = { isRepairing: false, repairType: 'none', turnsLeft: 0 };
    state.repairState = this.repairState;
  }

  public processTurn(state: GameState, grid: TileData[][]): void {
    // 1. 자연 피로 회복
    this.defenseFatigue = Math.max(0, this.defenseFatigue - 25);

    // 2. 수축 대역사 턴 처리
    if (this.repairState.isRepairing && this.repairState.repairType === 'grand') {
      const hasBuff = state.retainers.jeong;
      const costGold = hasBuff ? 210 : 300;
      const costRice = hasBuff ? 140 : 200;
      const restoreAmt = hasBuff ? 150 : 100;

      if (state.gold >= costGold && state.rice >= costRice) {
        state.gold -= costGold;
        state.rice -= costRice;
        this.defenseFatigue = Math.max(0, this.defenseFatigue - restoreAmt);
        if (this.defenseFatigue <= 0) {
          this.repairState = { isRepairing: false, repairType: 'none', turnsLeft: 0 };
        }
      } else {
        this.repairState = { isRepairing: false, repairType: 'none', turnsLeft: 0 };
      }
    }

    // 3. 방치 패널티
    const curDef = this.computeDefensePower(state, grid);
    if (curDef < 500) {
      state.loyalty = Math.max(0, state.loyalty - 1);
    }
  }
}
