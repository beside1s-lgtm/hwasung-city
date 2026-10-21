import { TileData } from '../types';

export interface LoopValidationResult {
  isClosedLoop: boolean;
  rawProgress: number;
  validatedProgress: number;
  visitedGates: string[];
  missingGates: string[];
  brokenSegments?: string[];
  tooltipMessage: string;
}

export class WallLoopValidator {
  private static readonly WALL_CONNECTORS = [
    'wall', 'gate', 'seojangdae', 'seojangdae_site', 'bongdon', 'bongdon_site', 'gongsimdon',
    'gongsimdon_wall', 'gongsimdon_site', 'poru', 'poru_site', 'yeonmudae', 'yeonmudae_range',
    'banghwasuryu', 'hwahong', 'namsu', 'chiseong', 'ammun', 'water_gate', 'dongjangdae',
    'dongbuk_gongsimdon', 'seobuk_gongsimdon', 'dongam_mun', 'seonam_ammun', 'bukam_mun'
  ];

  private static readonly DIRS8: [number, number][] = [
    [1, 0], [-1, 0], [0, 1], [0, -1],
    [1, 1], [1, -1], [-1, 1], [-1, -1]
  ];

  private isDirty = true;
  private cachedResult: LoopValidationResult = {
    isClosedLoop: false,
    rawProgress: 0,
    validatedProgress: 0,
    visitedGates: [],
    missingGates: ['jangan', 'paldal', 'hwaseo', 'changryong'],
    tooltipMessage: '사대문이 성곽으로 완전히 이어지지 않았습니다.'
  };

  public invalidate(): void {
    this.isDirty = true;
  }

  public validateLoop(grid: TileData[][], rawProgress: number): LoopValidationResult {
    if (!this.isDirty) {
      return this.cachedResult;
    }
    this.isDirty = false;

    if (!grid || grid.length === 0) {
      return this.cachedResult;
    }

    const gateTiles = new Map<string, Array<{ x: number; y: number }>>();
    gateTiles.set('jangan', []);
    gateTiles.set('hwaseo', []);
    gateTiles.set('paldal', []);
    gateTiles.set('changryong', []);

    const wallTiles = new Set<string>();

    for (let y = 0; y < grid.length; y++) {
      for (let x = 0; x < grid[y].length; x++) {
        const t = grid[y][x];
        if (t.underConstruction || (t as any).wall_build) continue;

        const b = t.building || '';
        const isConn = WallLoopValidator.WALL_CONNECTORS.includes(b) || (t as any).is_namsu || (t as any).is_hwahong || (t as any).is_bridge;
        if (isConn) {
          wallTiles.add(`${x},${y}`);

          const isGate = b === 'gate' || ((t as any).facility_id && (t as any).facility_id.endsWith('_mun'));
          if (isGate) {
            let gateId = '';
            const gname = (t as any).gate_name || '';
            if (gname.includes('화서') || gname.includes('hwaseo') || (t as any).facility_id === 'hwaseo_mun') gateId = 'hwaseo';
            else if (gname.includes('장안') || gname.includes('jangan') || (t as any).facility_id === 'jangan_mun') gateId = 'jangan';
            else if (gname.includes('팔달') || gname.includes('paldal') || (t as any).facility_id === 'paldal_mun') gateId = 'paldal';
            else if (gname.includes('창룡') || gname.includes('changryong') || (t as any).facility_id === 'changryong_mun') gateId = 'changryong';
            else if (Math.abs(x - 6) <= 6 && Math.abs(y - 13) <= 6) gateId = 'hwaseo';
            else if (Math.abs(x - 26) <= 6 && Math.abs(y - 6) <= 6) gateId = 'jangan';
            else if (Math.abs(x - 16) <= 6 && Math.abs(y - 54) <= 6) gateId = 'paldal';
            else if (Math.abs(x - 48) <= 6 && Math.abs(y - 29) <= 6) gateId = 'changryong';
            else if (x < 20 && Math.abs(y - 13) < 12) gateId = 'hwaseo';
            else if (y < 18) gateId = 'jangan';
            else if (y > 42) gateId = 'paldal';
            else gateId = 'changryong';

            if (gateTiles.has(gateId)) {
              gateTiles.get(gateId)!.push({ x, y });
            }
          }
        }
      }
    }

    const requiredGates = ['jangan', 'hwaseo', 'paldal', 'changryong'];
    const missing = requiredGates.filter(g => (gateTiles.get(g) || []).length === 0);

    if (missing.length > 0) {
      const missingKorean = missing.map(m => {
        if (m === 'jangan') return '장안문(북)';
        if (m === 'paldal') return '팔달문(남)';
        if (m === 'hwaseo') return '화서문(서)';
        return '창룡문(동)';
      });

      this.cachedResult = {
        isClosedLoop: false,
        rawProgress,
        validatedProgress: Math.min(99, rawProgress),
        visitedGates: Array.from(gateTiles.keys()).filter(g => (gateTiles.get(g) || []).length > 0),
        missingGates: missing,
        tooltipMessage: `사대문 중 미완성 성문이 존재합니다: ${missingKorean.join(', ')}`
      };
      return this.cachedResult;
    }

    const tilesJa = gateTiles.get('jangan')!;
    const tilesHw = gateTiles.get('hwaseo')!;
    const tilesPd = gateTiles.get('paldal')!;
    const tilesCr = gateTiles.get('changryong')!;

    const okNW = this.isPathConnectedSets(tilesJa, tilesHw, wallTiles, this.combineSets([tilesPd, tilesCr]));
    const okSW = this.isPathConnectedSets(tilesHw, tilesPd, wallTiles, this.combineSets([tilesJa, tilesCr]));
    const okSE = this.isPathConnectedSets(tilesPd, tilesCr, wallTiles, this.combineSets([tilesJa, tilesHw]));
    const okNE = this.isPathConnectedSets(tilesCr, tilesJa, wallTiles, this.combineSets([tilesHw, tilesPd]));

    const isLoopComplete = okNW && okSW && okSE && okNE;

    if (isLoopComplete) {
      this.cachedResult = {
        isClosedLoop: true,
        rawProgress: 100,
        validatedProgress: 100,
        visitedGates: ['jangan', 'hwaseo', 'paldal', 'changryong'],
        missingGates: [],
        brokenSegments: [],
        tooltipMessage: '사대문이 성곽으로 완전히 연결되어 화성 성곽 폐곡선이 100% 완공되었습니다!'
      };
    } else {
      const broken: string[] = [];
      if (!okNW) broken.push('서북성곽(장안문-화서문)');
      if (!okSW) broken.push('서남성곽(화서문-팔달문)');
      if (!okSE) broken.push('동남성곽(팔달문-창룡문)');
      if (!okNE) broken.push('동북성곽(창룡문-장안문)');

      this.cachedResult = {
        isClosedLoop: false,
        rawProgress,
        validatedProgress: Math.min(99, rawProgress),
        visitedGates: ['jangan', 'hwaseo', 'paldal', 'changryong'],
        missingGates: [],
        brokenSegments: broken,
        tooltipMessage: `사대문이 성곽으로 완전히 이어지지 않았습니다 (${broken.join(', ')} 구간 단절).`
      };
    }

    return this.cachedResult;
  }

  private combineSets(tileArrays: Array<Array<{ x: number; y: number }>>): Set<string> {
    const out = new Set<string>();
    for (const arr of tileArrays) {
      for (const pt of arr) {
        out.add(`${pt.x},${pt.y}`);
      }
    }
    return out;
  }

  private isPathConnectedSets(
    startTiles: Array<{ x: number; y: number }>,
    goalTiles: Array<{ x: number; y: number }>,
    wallTiles: Set<string>,
    forbiddenSet: Set<string>
  ): boolean {
    if (startTiles.length === 0 || goalTiles.length === 0) return false;

    const goalSet = new Set<string>();
    for (const gp of goalTiles) {
      goalSet.add(`${gp.x},${gp.y}`);
    }

    const queue: Array<{ x: number; y: number }> = [];
    const visited = new Set<string>();

    for (const sp of startTiles) {
      const key = `${sp.x},${sp.y}`;
      if (goalSet.has(key)) return true;
      visited.add(key);
      queue.push(sp);
    }

    let head = 0;
    while (head < queue.length) {
      const curr = queue[head++];
      const currKey = `${curr.x},${curr.y}`;
      if (goalSet.has(currKey)) return true;

      for (const [dx, dy] of WallLoopValidator.DIRS8) {
        const nx = curr.x + dx;
        const ny = curr.y + dy;
        const key = `${nx},${ny}`;

        if (!wallTiles.has(key) || visited.has(key)) continue;
        if (forbiddenSet.has(key) && !goalSet.has(key)) continue;

        visited.add(key);
        queue.push({ x: nx, y: ny });
      }
    }

    return false;
  }
}
