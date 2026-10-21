import { CitizenAgent, GameState, TileData, TroopRoster } from '../types';

/**
 * [조선 후기 삼수병(포수·사수·살수) 및 기포병 편제 관리 시스템]
 * 포수 60% : 사수 15% : 살수 15% : 기포병 10% 엄격 고증 편제
 * 평시: 연무대·행궁·서장대·사대문 순시 및 사열 훈련
 * 전시: 병종별 전술 앵커 배치 (포수-성벽/포루 일제사격, 사수-곡사궁술, 살수-성문백병전, 기포병-외곽기동타격)
 * 성능 최적화: 그룹 웨이포인트 기반 이동 및 오브젝트 풀링 (총구 화염/백색 연막/화살)
 */

export const RATIO_POSU = 0.60;
export const RATIO_SASU = 0.15;
export const RATIO_SALSU = 0.15;
export const RATIO_GIPO = 0.10;

export interface SmokeParticle {
  active: boolean;
  x: number;
  y: number;
  life: number;
  maxLife: number;
  size: number;
}

export interface ArrowProjectile {
  active: boolean;
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  progress: number;
  arcH: number;
}

export interface FlashParticle {
  active: boolean;
  x: number;
  y: number;
  life: number;
  maxLife: number;
}

export class MilitaryManager {
  public troopRoster: TroopRoster = {
    total: 20,
    posu: 12,
    sasu: 3,
    salsu: 3,
    gipo: 2
  };

  public isWartime = false;
  private militaryAgentIds: number[] = [];
  private savedPeaceAnchors: Map<number, { x: number; y: number }> = new Map();

  // 발사체 및 VFX 오브젝트 풀 (GC 렉 원천 차단)
  public readonly maxPoolSize = 30;
  public smokePool: SmokeParticle[] = [];
  public arrowPool: ArrowProjectile[] = [];
  public flashPool: FlashParticle[] = [];

  constructor() {
    this.initPools();
  }

  private initPools(): void {
    this.smokePool = [];
    this.arrowPool = [];
    this.flashPool = [];
    for (let i = 0; i < this.maxPoolSize; i++) {
      this.smokePool.push({ active: false, x: 0, y: 0, life: 0, maxLife: 1.2, size: 3.0 });
      this.arrowPool.push({ active: false, fromX: 0, fromY: 0, toX: 0, toY: 0, progress: 0, arcH: 12.0 });
      this.flashPool.push({ active: false, x: 0, y: 0, life: 0, maxLife: 0.2 });
    }
  }

  /**
   * 국방력 수치(military)에 따라 정규군 편제 수 산출 (60:15:15:10 비율)
   */
  public computeRoster(milPower: number): TroopRoster {
    const totalCount = Math.min(40, Math.max(10, Math.floor(milPower * 0.25)));
    const nPosu = Math.round(totalCount * RATIO_POSU);
    const nSasu = Math.round(totalCount * RATIO_SASU);
    const nSalsu = Math.round(totalCount * RATIO_SALSU);
    const nGipo = Math.max(1, totalCount - nPosu - nSasu - nSalsu);

    this.troopRoster = {
      total: totalCount,
      posu: nPosu,
      sasu: nSasu,
      salsu: nSalsu,
      gipo: nGipo
    };
    return this.troopRoster;
  }

  /**
   * 평시 정규군 스폰 및 배치
   */
  public spawnRegularArmy(
    citizens: CitizenAgent[],
    grid: TileData[][],
    state: GameState
  ): CitizenAgent[] {
    this.computeRoster(state.military || 70);
    this.militaryAgentIds = [];
    this.savedPeaceAnchors.clear();

    const waypoints: Array<{ x: number; y: number }> = [];
    const milBuildings = ['yeonmudae', 'seojangdae', 'haenggung', 'patrol', 'gate'];

    for (let r = 0; r < grid.length; r++) {
      for (let c = 0; c < grid[r].length; c++) {
        const cell = grid[r][c];
        if (cell.building && milBuildings.includes(cell.building) && !cell.underConstruction) {
          waypoints.push({ x: c, y: r });
        }
      }
    }

    if (waypoints.length === 0) {
      waypoints.push({ x: 32, y: 32 });
    }

    const troopTypes: Array<'posu' | 'sasu' | 'salsu' | 'gipo'> = [];
    for (let i = 0; i < this.troopRoster.posu; i++) troopTypes.push('posu');
    for (let i = 0; i < this.troopRoster.sasu; i++) troopTypes.push('sasu');
    for (let i = 0; i < this.troopRoster.salsu; i++) troopTypes.push('salsu');
    for (let i = 0; i < this.troopRoster.gipo; i++) troopTypes.push('gipo');

    let nextId = citizens.length > 0 ? Math.max(...citizens.map(c => c.id)) + 1 : 1000;
    const armyUnits: CitizenAgent[] = [];

    for (let i = 0; i < troopTypes.length; i++) {
      const btype = troopTypes[i];
      const anchor = waypoints[i % waypoints.length];
      const spawnX = Math.max(0, Math.min(63, anchor.x + (Math.floor(Math.random() * 3) - 1)));
      const spawnY = Math.max(0, Math.min(63, anchor.y + (Math.floor(Math.random() * 3) - 1)));

      const agentId = nextId++;
      const agent: CitizenAgent = {
        id: agentId,
        x: spawnX,
        y: spawnY,
        targetX: anchor.x,
        targetY: anchor.y,
        type: btype,
        action: 'patrol',
        speed: btype === 'gipo' ? 1.3 : 0.95,
        animFrame: 0,
        militaryUnit: true,
        btype,
        peaceAnchor: { x: anchor.x, y: anchor.y },
        bubbleText: btype === 'posu' ? '조총 화약과 심지를 정비한다.' :
                    btype === 'sasu' ? '활 시위를 팽팽히 조인다.' :
                    btype === 'salsu' ? '당파창을 곧게 쥐고 열을 맞추자.' :
                    '행궁 주위를 기마로 삼엄히 경계하라.',
        bubbleTimer: 3.0,
        reloadTimer: 2.0,
        drawTimer: 1.5,
        fireTimer: 2.5
      };

      this.militaryAgentIds.push(agentId);
      this.savedPeaceAnchors.set(agentId, { x: anchor.x, y: anchor.y });
      armyUnits.push(agent);
      citizens.push(agent);
    }

    state.troopRoster = { ...this.troopRoster };
    return armyUnits;
  }

  /**
   * 전시 전술 배치 (공성전 발생 시 병종별 전술 앵커 배정)
   */
  public deployWartime(
    citizens: CitizenAgent[],
    grid: TileData[][],
    targetGate: { x: number; y: number }
  ): void {
    this.isWartime = true;

    const wallAnchors: Array<{ x: number; y: number }> = [];
    const highAnchors: Array<{ x: number; y: number }> = [];
    const gateAnchors: Array<{ x: number; y: number }> = [];
    const outsideAnchors: Array<{ x: number; y: number }> = [];

    for (let r = 0; r < grid.length; r++) {
      for (let c = 0; c < grid[r].length; c++) {
        const cell = grid[r][c];
        if (cell.underConstruction) continue;

        const b = cell.building;
        if (b === 'wall' || b === 'poru' || b === 'gongsimdon' || b === 'gongsimdon_wall') {
          wallAnchors.push({ x: c, y: r });
        } else if (b === 'seojangdae' || b === 'yeonmudae' || b === 'gate') {
          highAnchors.push({ x: c, y: r });
        }

        if (cell.terrain === 'plain' && (!b || b === 'road')) {
          const dist = Math.abs(c - targetGate.x) + Math.abs(r - targetGate.y);
          if (dist >= 4 && dist <= 12) {
            outsideAnchors.push({ x: c, y: r });
          }
        }
      }
    }

    // 성문 주변 살수 앵커
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const gx = targetGate.x + dx;
      const gy = targetGate.y + dy;
      if (gy >= 0 && gy < grid.length && gx >= 0 && gx < grid[0].length) {
        gateAnchors.push({ x: gx, y: gy });
      }
    }

    if (wallAnchors.length === 0) wallAnchors.push(targetGate);
    if (highAnchors.length === 0) highAnchors.push(targetGate);
    if (gateAnchors.length === 0) gateAnchors.push(targetGate);
    if (outsideAnchors.length === 0) outsideAnchors.push({ x: 2, y: 32 });

    let posuIdx = 0;
    let sasuIdx = 0;
    let salsuIdx = 0;
    let gipoIdx = 0;

    for (const a of citizens) {
      if (!a.militaryUnit) continue;

      switch (a.btype) {
        case 'posu': {
          const tpos = wallAnchors[posuIdx++ % wallAnchors.length];
          a.targetX = tpos.x;
          a.targetY = tpos.y;
          a.action = 'combat';
          a.bubbleText = '조총 일제 사격 준비! 점화하라!';
          a.bubbleTimer = 3.5;
          a.reloadTimer = 1.5 + Math.random() * 2.0;
          break;
        }
        case 'sasu': {
          const tpos = highAnchors[sasuIdx++ % highAnchors.length];
          a.targetX = tpos.x;
          a.targetY = tpos.y;
          a.action = 'combat';
          a.bubbleText = '곡사로 쏘아라! 성벽 아래 놈들을 궤멸시켜라!';
          a.bubbleTimer = 3.5;
          a.drawTimer = 1.0 + Math.random() * 1.5;
          break;
        }
        case 'salsu': {
          const tpos = gateAnchors[salsuIdx++ % gateAnchors.length];
          a.targetX = tpos.x;
          a.targetY = tpos.y;
          a.action = 'combat';
          a.bubbleText = '당파창을 세우고 돌파하는 놈들을 베어라!';
          a.bubbleTimer = 3.5;
          break;
        }
        case 'gipo': {
          const tpos = outsideAnchors[gipoIdx++ % outsideAnchors.length];
          a.targetX = tpos.x;
          a.targetY = tpos.y;
          a.action = 'combat';
          a.bubbleText = '기마 화포 출격! 적의 후방과 측면을 들이쳐라!';
          a.bubbleTimer = 4.0;
          a.fireTimer = 2.0 + Math.random() * 2.0;
          break;
        }
      }
    }
  }

  /**
   * 종전 및 평시 상태 롤백 (정규군 100% 원직/원거점 복귀)
   */
  public standDown(citizens: CitizenAgent[]): void {
    this.isWartime = false;

    for (const a of citizens) {
      if (!a.militaryUnit) continue;

      const orig = this.savedPeaceAnchors.get(a.id) || { x: a.x, y: a.y };
      a.targetX = orig.x;
      a.targetY = orig.y;
      a.action = 'patrol';
      a.bubbleText = '싸움이 끝났으니 진형을 정비하고 순시로 복귀하자.';
      a.bubbleTimer = 3.0;
    }
  }

  /**
   * 매 틱 정규군 FSM 및 발사체 연산
   */
  public update(
    citizens: CitizenAgent[],
    delta: number,
    targetSiegePos: { x: number; y: number }
  ): void {
    this.updatePools(delta);

    for (const a of citizens) {
      if (!a.militaryUnit) continue;

      if (a.bubbleTimer && a.bubbleTimer > 0) {
        a.bubbleTimer -= delta;
        if (a.bubbleTimer <= 0) {
          a.bubbleText = undefined;
        }
      }

      if (!this.isWartime || a.action === 'patrol') {
        // 평시 순시
        const anchor = a.peaceAnchor || { x: a.x, y: a.y };
        const dx = anchor.x - a.x;
        const dy = anchor.y - a.y;
        if (Math.hypot(dx, dy) > 2.0) {
          a.targetX = anchor.x;
          a.targetY = anchor.y;
        }
      } else {
        // 전시 행동
        switch (a.btype) {
          case 'posu':
            if (a.reloadTimer !== undefined) {
              a.reloadTimer -= delta;
              if (a.reloadTimer <= 0) {
                a.reloadTimer = 2.0 + Math.random() * 2.0;
                this.spawnFlash(a.x, a.y - 0.4);
                this.spawnSmoke(a.x, a.y - 0.4);
                a.bubbleText = '탕! 장전 완료, 다음 열 발사!';
                a.bubbleTimer = 2.0;
              }
            }
            break;
          case 'sasu':
            if (a.drawTimer !== undefined) {
              a.drawTimer -= delta;
              if (a.drawTimer <= 0) {
                a.drawTimer = 1.5 + Math.random() * 1.5;
                this.spawnArrow(a.x, a.y - 0.5, targetSiegePos.x, targetSiegePos.y);
              }
            }
            break;
          case 'gipo':
            if (a.fireTimer !== undefined) {
              a.fireTimer -= delta;
              if (a.fireTimer <= 0) {
                a.fireTimer = 2.5 + Math.random() * 2.0;
                this.spawnFlash(a.x, a.y - 0.5);
                this.spawnSmoke(a.x, a.y - 0.5);
                a.bubbleText = '기마 화포 일제 격발!';
                a.bubbleTimer = 2.0;
              }
            }
            break;
        }
      }
    }
  }

  // ------------------------------------------------------------ 오브젝트 풀링 (Object Pooling)
  public spawnSmoke(x: number, y: number): void {
    for (const p of this.smokePool) {
      if (!p.active) {
        p.active = true;
        p.x = x;
        p.y = y;
        p.life = 0;
        p.size = 3.0 + Math.random() * 2.0;
        return;
      }
    }
  }

  public spawnArrow(fromX: number, fromY: number, toX: number, toY: number): void {
    for (const a of this.arrowPool) {
      if (!a.active) {
        a.active = true;
        a.fromX = fromX;
        a.fromY = fromY;
        a.toX = toX;
        a.toY = toY;
        a.progress = 0;
        return;
      }
    }
  }

  public spawnFlash(x: number, y: number): void {
    for (const f of this.flashPool) {
      if (!f.active) {
        f.active = true;
        f.x = x;
        f.y = y;
        f.life = 0;
        return;
      }
    }
  }

  private updatePools(delta: number): void {
    for (const p of this.smokePool) {
      if (p.active) {
        p.life += delta;
        if (p.life >= p.maxLife) p.active = false;
      }
    }

    for (const a of this.arrowPool) {
      if (a.active) {
        a.progress += delta * 1.5;
        if (a.progress >= 1.0) a.active = false;
      }
    }

    for (const f of this.flashPool) {
      if (f.active) {
        f.life += delta;
        if (f.life >= f.maxLife) f.active = false;
      }
    }
  }
}
