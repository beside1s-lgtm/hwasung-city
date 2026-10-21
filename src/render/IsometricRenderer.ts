import { TileData, GameState, CitizenAgent } from '../types';
import { GameStateManager } from '../core/GameState';
import { PixelArtSheets } from './PixelArtSheets';

export interface Camera {
  x: number;
  y: number;
  zoom: number;
  minZoom: number;
  maxZoom: number;
}

export class IsometricRenderer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private viewport: HTMLElement;
  public camera: Camera;
  private animationTime = 0;
  private particles: Array<{ x: number; y: number; speedX: number; speedY: number; size: number; rot: number; rotSpeed: number }> = [];

  constructor(canvas: HTMLCanvasElement, viewport: HTMLElement) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.viewport = viewport;
    this.camera = {
      x: 0,
      y: 0,
      zoom: 1.0,
      minZoom: 0.55,
      maxZoom: 2.2
    };

    this.initParticles();
    this.resize();
  }

  private initParticles(): void {
    for (let i = 0; i < 36; i++) {
      this.particles.push({
        x: Math.random() * 1200,
        y: Math.random() * 800,
        speedX: (Math.random() - 0.5) * 1.6,
        speedY: 0.6 + Math.random() * 1.4,
        size: 2 + Math.random() * 3,
        rot: Math.random() * Math.PI * 2,
        rotSpeed: (Math.random() - 0.5) * 0.05
      });
    }
  }

  public resize(): void {
    const rect = this.viewport.getBoundingClientRect();
    const w = Math.floor(rect.width) || window.innerWidth || 800;
    const h = Math.floor(rect.height) || (window.innerHeight - 100) || 600;

    if (w > 0 && h > 0 && (this.canvas.width !== w || this.canvas.height !== h)) {
      this.canvas.width = w;
      this.canvas.height = h;
    }
    if (this.camera.x === 0 || this.camera.y === 0 || isNaN(this.camera.x)) {
      this.centerCamera();
    }
  }

  public centerCamera(): void {
    const w = this.canvas.width || 800;
    const h = this.canvas.height || 600;
    this.camera.zoom = window.innerWidth < 640 ? 0.85 : 1.1;
    this.camera.x = w / 2;
    this.camera.y = Math.max(50, h * 0.20);
  }

  public getCanvasPos(clientX: number, clientY: number): { x: number; y: number } {
    const rect = this.canvas.getBoundingClientRect();
    const scaleX = this.canvas.width / rect.width;
    const scaleY = this.canvas.height / rect.height;
    return {
      x: (clientX - rect.left) * scaleX,
      y: (clientY - rect.top) * scaleY
    };
  }

  /**
   * 정점(Vertex) 좌표계를 화면 좌표계로 변환 (부드러운 슬로프 지형의 핵심)
   */
  public vertexToScreen(vx: number, vy: number, elev: number): { x: number; y: number } {
    const halfW = (GameStateManager.TILE_W / 2) * this.camera.zoom;
    const halfH = (GameStateManager.TILE_H / 2) * this.camera.zoom;
    const sx = (vx - vy) * halfW + this.camera.x;
    const sy = (vx + vy) * halfH - (elev * GameStateManager.ELEV_STEP * this.camera.zoom) + this.camera.y;
    return { x: sx, y: sy };
  }

  public gridToScreen(gx: number, gy: number, elev = 0, rot = 0): { x: number; y: number } {
    const { rx, ry } = GameStateManager.rotateCoords(gx, gy, rot);
    const halfW = (GameStateManager.TILE_W / 2) * this.camera.zoom;
    const halfH = (GameStateManager.TILE_H / 2) * this.camera.zoom;
    const sx = (rx - ry) * halfW + this.camera.x;
    const sy = (rx + ry) * halfH - (elev * GameStateManager.ELEV_STEP * this.camera.zoom) + this.camera.y;
    return { x: sx, y: sy };
  }

  public screenToGrid(sx: number, sy: number, grid: TileData[][], rot = 0): { x: number; y: number } {
    const halfW = (GameStateManager.TILE_W / 2) * this.camera.zoom;
    const halfH = (GameStateManager.TILE_H / 2) * this.camera.zoom;

    const candidates: Array<{ tile: TileData; rx: number; ry: number }> = [];
    grid.forEach(row => row.forEach(t => {
      const r = GameStateManager.rotateCoords(t.x, t.y, rot);
      candidates.push({ tile: t, rx: r.rx, ry: r.ry });
    }));

    candidates.sort((a, b) => (b.tile.elevation * 100 + b.rx + b.ry) - (a.tile.elevation * 100 + a.rx + a.ry));

    for (const item of candidates) {
      const pos = this.gridToScreen(item.tile.x, item.tile.y, item.tile.elevation, rot);
      const cx = pos.x;
      const cy = pos.y + halfH;
      const distNorm = Math.abs(sx - cx) / halfW + Math.abs(sy - cy) / halfH;
      if (distNorm <= 1.0) {
        return { x: item.tile.x, y: item.tile.y };
      }
    }

    const u = (sx - this.camera.x) / halfW;
    const v = (sy - this.camera.y - halfH) / halfH;
    const rx = Math.floor((u + v) / 2);
    const ry = Math.floor((v - u) / 2);

    const orig = GameStateManager.unrotateCoords(rx, ry, rot);
    return {
      x: Math.max(0, Math.min(GameStateManager.MAP_SIZE - 1, orig.x)),
      y: Math.max(0, Math.min(GameStateManager.MAP_SIZE - 1, orig.y))
    };
  }

  public render(
    grid: TileData[][],
    cornerHeights: number[][],
    citizens: CitizenAgent[],
    state: GameState,
    hoverTile: { x: number; y: number } | null,
    dragTiles: Array<{ x: number; y: number }>,
    isPointerDown: boolean,
    isMiddlePanning: boolean,
    gameManager: GameStateManager
  ): void {
    this.animationTime += 0.03;
    if (!this.canvas.width || !this.canvas.height) return;
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    const halfW = (GameStateManager.TILE_W / 2) * this.camera.zoom;
    const halfH = (GameStateManager.TILE_H / 2) * this.camera.zoom;
    const pal = this.getPalette(state.seasonIndex);
    const rot = state.rotation;

    // 회전 정렬 타일 리스트
    const sortedTiles: Array<{ tile: TileData; rx: number; ry: number }> = [];
    for (let y = 0; y < GameStateManager.MAP_SIZE; y++) {
      for (let x = 0; x < GameStateManager.MAP_SIZE; x++) {
        const r = GameStateManager.rotateCoords(x, y, rot);
        sortedTiles.push({ tile: grid[y][x], rx: r.rx, ry: r.ry });
      }
    }
    sortedTiles.sort((a, b) => (a.rx + a.ry) - (b.rx + b.ry));

    // 1단계: 부드러운 연속 슬로프 지형 메쉬 렌더링 (골짜기 계곡 베이스 포함)
    for (const item of sortedTiles) {
      const tile = item.tile;
      const rx = item.rx;
      const ry = item.ry;

      // 회전된 4개 정점의 원본 좌표 및 고도 추출
      const vN = this.getVertexElev(rx, ry, rot, cornerHeights);
      const vE = this.getVertexElev(rx + 1, ry, rot, cornerHeights);
      const vS = this.getVertexElev(rx + 1, ry + 1, rot, cornerHeights);
      const vW = this.getVertexElev(rx, ry + 1, rot, cornerHeights);

      const pN = this.vertexToScreen(rx, ry, vN);
      const pE = this.vertexToScreen(rx + 1, ry, vE);
      const pS = this.vertexToScreen(rx + 1, ry + 1, vS);
      const pW = this.vertexToScreen(rx, ry + 1, vW);

      // 경사면 음영(Slope Shading) 계산
      const slopeLight = (vW - vE) * 0.12 + (vN - vS) * 0.15;

      this.ctx.beginPath();
      this.ctx.moveTo(pN.x, pN.y);
      this.ctx.lineTo(pE.x, pE.y);
      this.ctx.lineTo(pS.x, pS.y);
      this.ctx.lineTo(pW.x, pW.y);
      this.ctx.closePath();

      // 지형 베이스: 산맥 또는 완만한 평지/초원
      if (tile.terrain === 'mountain') {
        this.ctx.fillStyle = this.adjustBrightness(pal.mountainTop, slopeLight);
      } else {
        this.ctx.fillStyle = this.adjustBrightness(pal.plainTop, slopeLight);
      }
      this.ctx.fill();

      this.ctx.strokeStyle = 'rgba(0, 0, 0, 0.04)';
      this.ctx.lineWidth = 0.7;
      this.ctx.stroke();

      // 구획 지정 하이라이트 (RCI 색상)
      if (tile.zone && !tile.building) {
        this.ctx.fillStyle = tile.zone === 'res' ? 'rgba(74, 222, 128, 0.45)' :
                             tile.zone === 'com' ? 'rgba(56, 189, 248, 0.45)' :
                                                   'rgba(251, 191, 36, 0.45)';
        this.ctx.fill();
        this.ctx.strokeStyle = '#fef08a';
        this.ctx.lineWidth = 1.2;
        this.ctx.stroke();
      }
    }

    // 2단계: 심시티 4 스타일 연속 곡선 하천 (수원천) 렌더링 (타일 마름모 끊김 완전 제거)
    this.drawContinuousRiver(rot, cornerHeights, state.seasonIndex);

    // 3단계: 도로, 성곽 오토타일링 및 건물 구조물 렌더링
    for (const item of sortedTiles) {
      const tile = item.tile;
      const rx = item.rx;
      const ry = item.ry;

      const vN = this.getVertexElev(rx, ry, rot, cornerHeights);
      const vS = this.getVertexElev(rx + 1, ry + 1, rot, cornerHeights);
      const pN = this.vertexToScreen(rx, ry, vN);
      const pS = this.vertexToScreen(rx + 1, ry + 1, vS);
      const centerPos = { x: (pN.x + pS.x) / 2, y: (pN.y + pS.y) / 2 };

      // 샛길(골목길) 렌더링: 큰길에서 떨어진 구역(거리 2~3)에 자연스러운 황토 오솔길 연결선 표시
      const dist = gameManager.getDistanceToRoad(tile.x, tile.y);
      if ((tile.building || tile.zone) && dist >= 2 && dist <= 3) {
        this.ctx.strokeStyle = '#a16207';
        this.ctx.lineWidth = 3 * this.camera.zoom;
        this.ctx.setLineDash([4 * this.camera.zoom, 3 * this.camera.zoom]);
        this.ctx.beginPath();
        this.ctx.moveTo(centerPos.x, centerPos.y);
        this.ctx.lineTo(centerPos.x - halfW * 0.4, centerPos.y + halfH * 0.4);
        this.ctx.stroke();
        this.ctx.setLineDash([]);
      }

      this.drawTileStructures(tile, centerPos, halfW, halfH, state, gameManager);
    }

    // 4단계: 실시간 보행/작업 백성 에이전트 및 호랑이 렌더링
    this.drawCitizens(citizens, state.rotation, cornerHeights, state);

    // 5단계: 호버 커서 하이라이트
    if (hoverTile && !isPointerDown && !isMiddlePanning && !state.isPanMode) {
      this.drawHoverCursor(hoverTile, grid, halfW, halfH, state.currentTool, rot);
    }

    // 6단계: 드래그 청사진 미리보기
    if (dragTiles.length > 0 && !state.isPanMode) {
      this.drawDragPreview(dragTiles, grid, halfW, halfH, rot);
    }

    // 7단계: 사계절 파티클
    this.drawSeasonParticles(state.seasonIndex);
  }

  /**
   * 심시티 2000/4 스타일 연속 곡선 하천 (수원천) 렌더링
   * 타일 마름모 단위의 픽셀 끊김 없이, 부드럽게 굽이치는 강줄기 + 모래톱 + 수심 그라데이션
   */
  private drawContinuousRiver(rot: number, heights: number[][], seasonIdx: number): void {
    const pal = this.getPalette(seasonIdx);
    const numSteps = 75; // 촘촘한 곡선 분할
    const startY = -0.5;
    const endY = GameStateManager.MAP_SIZE + 0.5;
    const stepSize = (endY - startY) / numSteps;

    const centerLine: Array<{ gx: number; gy: number; w: number }> = [];
    for (let i = 0; i <= numSteps; i++) {
      const gy = startY + i * stepSize;
      // 유려한 사행천(Meandering stream) 곡선
      const gx = 8.5 + 1.25 * Math.sin(gy * 0.45) + 0.45 * Math.cos(gy * 0.95);
      const w = 0.65 + 0.02 * gy + 0.06 * Math.sin(gy * 0.7); // 하류로 갈수록 점진적으로 넓어짐
      centerLine.push({ gx, gy, w });
    }

    // 1. 강변 모래톱 / 제방 (Sand Bank)
    this.renderRiverStrip(centerLine, rot, heights, 1.45, () => {
      return seasonIdx === 3 ? 'rgba(203, 213, 225, 0.70)' : 'rgba(194, 154, 108, 0.75)';
    }, 0.01);

    // 2. 얕은 강변 여울 (Shallow Turquoise Water)
    this.renderRiverStrip(centerLine, rot, heights, 1.15, () => {
      return 'rgba(56, 189, 248, 0.55)';
    }, 0.03);

    // 3. 깊은 본류 (Deep Blue Core)
    this.renderRiverStrip(centerLine, rot, heights, 0.82, (t) => {
      const shimmer = Math.sin(this.animationTime * 2.5 + t * 4) * 0.08;
      return this.adjustBrightness(pal.water, shimmer);
    }, 0.05);

    // 4. 흐르는 물결 하이라이트 라인 (Flowing Water Shimmer Waves)
    this.renderRiverShimmer(centerLine, rot, heights);
  }

  /**
   * 하천 사다리꼴 스트립 렌더링 헬퍼
   */
  private renderRiverStrip(
    centerLine: Array<{ gx: number; gy: number; w: number }>,
    rot: number,
    heights: number[][],
    widthScale: number,
    colorFn: (t: number) => string,
    elevOffset: number
  ): void {
    const count = centerLine.length;
    const leftPoints: Array<{ x: number; y: number }> = [];
    const rightPoints: Array<{ x: number; y: number }> = [];

    for (let i = 0; i < count; i++) {
      const p = centerLine[i];
      const next = centerLine[Math.min(count - 1, i + 1)];
      const prev = centerLine[Math.max(0, i - 1)];

      const dx = next.gx - prev.gx;
      const dy = next.gy - prev.gy;
      const len = Math.hypot(dx, dy) || 1;
      const nx = -dy / len;
      const ny = dx / len;

      const w = p.w * widthScale;
      const h = this.sampleHeight(p.gx, p.gy, heights) + elevOffset;

      const left = { x: p.gx - nx * w, y: p.gy - ny * w };
      const right = { x: p.gx + nx * w, y: p.gy + ny * w };

      leftPoints.push(this.coordToScreen(left.x, left.y, h, rot));
      rightPoints.push(this.coordToScreen(right.x, right.y, h, rot));
    }

    // 왼쪽 라인을 따라 내려간 후, 오른쪽 라인을 역순으로 잇는 완벽한 연속 곡면 폴리곤
    this.ctx.fillStyle = colorFn(0.5);
    this.ctx.beginPath();
    if (leftPoints.length > 0) {
      this.ctx.moveTo(leftPoints[0].x, leftPoints[0].y);
      for (let i = 1; i < leftPoints.length; i++) {
        this.ctx.lineTo(leftPoints[i].x, leftPoints[i].y);
      }
      for (let i = rightPoints.length - 1; i >= 0; i--) {
        this.ctx.lineTo(rightPoints[i].x, rightPoints[i].y);
      }
      this.ctx.closePath();
      this.ctx.fill();
    }
  }

  /**
   * 실시간으로 흘러가는 물결 하이라이트 애니메이션
   */
  private renderRiverShimmer(
    centerLine: Array<{ gx: number; gy: number; w: number }>,
    rot: number,
    heights: number[][]
  ): void {
    const count = centerLine.length;
    this.ctx.save();
    this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
    this.ctx.lineWidth = 1.2 * this.camera.zoom;
    this.ctx.lineCap = 'round';

    for (let i = 4; i < count - 4; i += 6) {
      const flowOffset = (this.animationTime * 12 + i) % count;
      const idx = Math.floor(flowOffset);
      if (idx >= count - 2) continue;

      const p1 = centerLine[idx];
      const p2 = centerLine[idx + 1];

      const h = this.sampleHeight(p1.gx, p1.gy, heights) + 0.06;
      const s1 = this.coordToScreen(p1.gx, p1.gy, h, rot);
      const s2 = this.coordToScreen(p2.gx, p2.gy, h, rot);

      this.ctx.beginPath();
      this.ctx.moveTo(s1.x, s1.y);
      this.ctx.lineTo(s2.x, s2.y);
      this.ctx.stroke();
    }
    this.ctx.restore();
  }

  private sampleHeight(gx: number, gy: number, heights: number[][]): number {
    const size = GameStateManager.MAP_SIZE;
    const cx = Math.max(0, Math.min(size, Math.round(gx)));
    const cy = Math.max(0, Math.min(size, Math.round(gy)));
    return heights[cy]?.[cx] ?? 0.2;
  }

  private coordToScreen(gx: number, gy: number, elev: number, rot: number): { x: number; y: number } {
    const { rx, ry } = GameStateManager.rotateCoords(gx, gy, rot);
    const halfW = (GameStateManager.TILE_W / 2) * this.camera.zoom;
    const halfH = (GameStateManager.TILE_H / 2) * this.camera.zoom;
    const sx = (rx - ry) * halfW + this.camera.x;
    const sy = (rx + ry) * halfH - (elev * GameStateManager.ELEV_STEP * this.camera.zoom) + this.camera.y;
    return { x: sx, y: sy };
  }

  /**
   * 회전된 정점 좌표의 원래 고도맵 조회
   */
  private getVertexElev(vrx: number, vry: number, rot: number, heights: number[][]): number {
    const size = GameStateManager.MAP_SIZE;
    let ox = vrx, oy = vry;
    switch (rot % 4) {
      case 1: ox = size - vry; oy = vrx; break;
      case 2: ox = size - vrx; oy = size - vry; break;
      case 3: ox = vry; oy = size - vrx; break;
      default: ox = vrx; oy = vry; break;
    }
    ox = Math.max(0, Math.min(size, ox));
    oy = Math.max(0, Math.min(size, oy));
    return heights[oy]?.[ox] ?? 1.0;
  }

  private adjustBrightness(hex: string, delta: number): string {
    const num = parseInt(hex.replace('#', ''), 16);
    let r = (num >> 16) + Math.round(delta * 255);
    let g = ((num >> 8) & 0x00FF) + Math.round(delta * 255);
    let b = (num & 0x0000FF) + Math.round(delta * 255);
    r = Math.max(0, Math.min(255, r));
    g = Math.max(0, Math.min(255, g));
    b = Math.max(0, Math.min(255, b));
    return `rgb(${r},${g},${b})`;
  }

  private drawTileStructures(
    tile: TileData,
    pos: { x: number; y: number },
    halfW: number,
    halfH: number,
    state: GameState,
    gameManager: GameStateManager
  ): void {
    const b = tile.building;
    if (!b) return;

    const zoom = this.camera.zoom;

    // 0. 국책사업 공사 진행 중인 구역 (비계 및 거중기 렌더링)
    if (tile.underConstruction) {
      const conSpr = PixelArtSheets.getConstructionSprite();
      this.ctx.drawImage(conSpr, pos.x - 24 * zoom, pos.y - 24 * zoom, 48 * zoom, 40 * zoom);
      return;
    }

    // 1. 단절 없는 연속 삼남대로 렌더링 (Seamless Road Ribbon)
    if (b === 'road') {
      this.drawSeamlessRoad(tile, pos, halfW, halfH, gameManager);
      return;
    }

    // 2. 단절 없는 연속 화성 성곽 렌더링 (Seamless Fortress Wall)
    if (b === 'wall') {
      this.drawSeamlessWall(tile, pos, halfW, halfH, gameManager);
      return;
    }

    // 3. 고도화 주거구역 (초가삼간, 대감댁 기와집)
    if (b.startsWith('res')) {
      if (b === 'res_2') {
        const gSpr = PixelArtSheets.getGiwaSprite(state.seasonIndex);
        this.ctx.drawImage(gSpr, pos.x - 28 * zoom, pos.y - 36 * zoom, 56 * zoom, 44 * zoom);
      } else {
        const cSpr = PixelArtSheets.getChogaSprite(state.seasonIndex);
        this.ctx.drawImage(cSpr, pos.x - 24 * zoom, pos.y - 28 * zoom, 48 * zoom, 36 * zoom);
      }
      return;
    }

    // 4. 고도화 상업구역 (주막 평상/차양막, 대형 시전상가 청사초롱)
    if (b.startsWith('com')) {
      if (b === 'com_2') {
        const mSpr = PixelArtSheets.getMarketSprite();
        this.ctx.drawImage(mSpr, pos.x - 28 * zoom, pos.y - 40 * zoom, 56 * zoom, 48 * zoom);
      } else {
        const jSpr = PixelArtSheets.getJumakSprite();
        this.ctx.drawImage(jSpr, pos.x - 24 * zoom, pos.y - 32 * zoom, 48 * zoom, 40 * zoom);
      }
      return;
    }

    // 5. 고도화 대유둔전 (논두렁, 물레방아)
    if (b.startsWith('agr')) {
      const level = (b === 'agr_2') ? 2 : 1;
      const aSpr = PixelArtSheets.getAgrSprite(level, state.seasonIndex);
      this.ctx.drawImage(aSpr, pos.x - 24 * zoom, pos.y - 28 * zoom, 48 * zoom, 36 * zoom);
      return;
    }

    // 6. 관아 및 특수 시설
    if (b === 'office') {
      const gSpr = PixelArtSheets.getGiwaSprite(state.seasonIndex);
      this.ctx.drawImage(gSpr, pos.x - 32 * zoom, pos.y - 42 * zoom, 64 * zoom, 48 * zoom);
      this.ctx.fillStyle = '#dc2626';
      this.ctx.fillRect(pos.x - 6 * zoom, pos.y - 8 * zoom, 12 * zoom, 6 * zoom);
      return;
    }

    if (b === 'seojangdae') {
      const gSpr = PixelArtSheets.getGateSprite();
      this.ctx.drawImage(gSpr, pos.x - 28 * zoom, pos.y - 48 * zoom, 56 * zoom, 56 * zoom);
      return;
    }

    if (b === 'bongdon') {
      this.ctx.fillStyle = '#78716c';
      this.ctx.fillRect(pos.x - 16 * zoom, pos.y - 16 * zoom, 32 * zoom, 16 * zoom);
      for (let i = -2; i <= 2; i++) {
        const cx = pos.x + i * 6 * zoom;
        this.ctx.fillStyle = '#44403c';
        this.ctx.fillRect(cx - 2 * zoom, pos.y - 22 * zoom, 4 * zoom, 6 * zoom);
        const smY = (this.animationTime * 8 + i * 2) % 18;
        this.ctx.fillStyle = 'rgba(220, 220, 220, 0.7)';
        this.ctx.beginPath();
        this.ctx.arc(cx, pos.y - 24 * zoom - smY, 2 + smY * 0.25, 0, Math.PI * 2);
        this.ctx.fill();
      }
      return;
    }

    if (b === 'well') {
      this.ctx.fillStyle = '#64748b';
      this.ctx.fillRect(pos.x - 8 * zoom, pos.y + halfH * 0.3, 16 * zoom, 10 * zoom);
      this.ctx.fillStyle = '#0284c7';
      this.ctx.fillRect(pos.x - 5 * zoom, pos.y + halfH * 0.3 + 2, 10 * zoom, 6 * zoom);
      return;
    }

    // 7. 청계천/수원천 석축 제방 (Levee)
    if (b === 'levee') {
      const levSpr = PixelArtSheets.getLeveeSprite();
      this.ctx.drawImage(levSpr, pos.x - 24 * zoom, pos.y - 18 * zoom, 48 * zoom, 32 * zoom);
      return;
    }

    // 8. 만석거 고지대 관개 저수지 (Reservoir)
    if (b === 'reservoir') {
      const resvSpr = PixelArtSheets.getReservoirSprite();
      this.ctx.drawImage(resvSpr, pos.x - 28 * zoom, pos.y - 24 * zoom, 56 * zoom, 44 * zoom);
      return;
    }

    // 9. 화산 현륭원(顯隆園) 사도세자 묘역
    if (b === 'hyoryungwon') {
      const hyoSpr = PixelArtSheets.getHyoryungwonSprite();
      this.ctx.drawImage(hyoSpr, pos.x - 32 * zoom, pos.y - 42 * zoom, 64 * zoom, 52 * zoom);
      // 참배 효심 오라 효과 (황금빛 은은한 후광)
      if (state.hyoryungwon.blessingActive) {
        this.ctx.strokeStyle = 'rgba(250, 204, 21, 0.6)';
        this.ctx.lineWidth = 2 * zoom;
        this.ctx.beginPath();
        this.ctx.ellipse(pos.x, pos.y - 15 * zoom, 28 * zoom, 16 * zoom, 0, 0, Math.PI * 2);
        this.ctx.stroke();
      }
      return;
    }

    // 10. 수원화성 성문/관문 (Gate - 장안문/팔달문)
    if (b === 'gate') {
      const gateSpr = PixelArtSheets.getBorderGateSprite();
      this.ctx.drawImage(gateSpr, pos.x - 28 * zoom, pos.y - 48 * zoom, 56 * zoom, 56 * zoom);
      return;
    }
  }

  /**
   * 실시간 보행/작업 백성 에이전트 렌더링 및 호환(호랑이) 렌더링
   */
  private drawCitizens(citizens: CitizenAgent[], rot: number, heights: number[][], state?: GameState): void {
    const zoom = this.camera.zoom;
    citizens.forEach(c => {
      const gx = Math.floor(c.x);
      const gy = Math.floor(c.y);
      const elev = heights[gy]?.[gx] ?? 1.0;
      const pos = this.gridToScreen(c.x, c.y, elev, rot);
      const frame = Math.floor(c.animFrame);
      const spr = PixelArtSheets.getCitizenSprite(c.type, frame);

      this.ctx.drawImage(spr, pos.x - 12 * zoom, pos.y - 18 * zoom, 24 * zoom, 24 * zoom);
    });

    // 호환(호랑이 출몰) 시 팔달산/광교산 능선에 호랑이 렌더링
    if (state?.tigerCrisis?.active) {
      const tigerPos = this.gridToScreen(2.5, 2.5, heights[2]?.[2] ?? 3.5, rot);
      const tigerSpr = PixelArtSheets.getTigerSprite(Math.floor(this.animationTime * 4));
      this.ctx.drawImage(tigerSpr, tigerPos.x - 16 * zoom, tigerPos.y - 20 * zoom, 32 * zoom, 24 * zoom);
    }
  }

  private drawHoverCursor(hover: { x: number; y: number }, grid: TileData[][], halfW: number, halfH: number, tool: string, rot: number): void {
    if (hover.x < 0 || hover.x >= GameStateManager.MAP_SIZE || hover.y < 0 || hover.y >= GameStateManager.MAP_SIZE) return;
    const tile = grid[hover.y][hover.x];
    const pos = this.gridToScreen(tile.x, tile.y, tile.elevation, rot);

    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.moveTo(pos.x, pos.y);
    this.ctx.lineTo(pos.x + halfW, pos.y + halfH);
    this.ctx.lineTo(pos.x, pos.y + halfH * 2);
    this.ctx.lineTo(pos.x - halfW, pos.y + halfH);
    this.ctx.closePath();

    if (tool === 'demolish') {
      this.ctx.fillStyle = 'rgba(239, 68, 68, 0.3)';
      this.ctx.strokeStyle = '#ef4444';
    } else if (tool === 'inspect') {
      this.ctx.fillStyle = 'rgba(56, 189, 248, 0.25)';
      this.ctx.strokeStyle = '#38bdf8';
    } else {
      this.ctx.fillStyle = 'rgba(251, 191, 36, 0.3)';
      this.ctx.strokeStyle = '#fbbf24';
    }
    this.ctx.lineWidth = 2;
    this.ctx.fill();
    this.ctx.stroke();
    this.ctx.restore();
  }

  private drawDragPreview(dragTiles: Array<{ x: number; y: number }>, grid: TileData[][], halfW: number, halfH: number, rot: number): void {
    this.ctx.save();
    this.ctx.fillStyle = 'rgba(251, 191, 36, 0.45)';
    this.ctx.strokeStyle = '#f59e0b';
    this.ctx.lineWidth = 2;

    dragTiles.forEach(pt => {
      if (pt.x < 0 || pt.x >= GameStateManager.MAP_SIZE || pt.y < 0 || pt.y >= GameStateManager.MAP_SIZE) return;
      const tile = grid[pt.y][pt.x];
      const pos = this.gridToScreen(pt.x, pt.y, tile.elevation, rot);
      this.ctx.beginPath();
      this.ctx.moveTo(pos.x, pos.y);
      this.ctx.lineTo(pos.x + halfW, pos.y + halfH);
      this.ctx.lineTo(pos.x, pos.y + halfH * 2);
      this.ctx.lineTo(pos.x - halfW, pos.y + halfH);
      this.ctx.closePath();
      this.ctx.fill();
      this.ctx.stroke();
    });
    this.ctx.restore();
  }

  private drawSeasonParticles(seasonIdx: number): void {
    const w = this.canvas.width || 800;
    const h = this.canvas.height || 600;
    this.ctx.save();

    this.particles.forEach(p => {
      p.x += p.speedX;
      p.y += p.speedY;
      p.rot += p.rotSpeed;

      if (p.y > h + 10) { p.y = -10; p.x = Math.random() * w; }
      if (p.x < -10) p.x = w + 10;
      if (p.x > w + 10) p.x = -10;

      this.ctx.save();
      this.ctx.translate(p.x, p.y);
      this.ctx.rotate(p.rot);

      if (seasonIdx === 0) {
        this.ctx.fillStyle = 'rgba(251, 182, 206, 0.75)';
        this.ctx.beginPath();
        this.ctx.ellipse(0, 0, p.size * 1.4, p.size * 0.7, 0, 0, Math.PI * 2);
        this.ctx.fill();
      } else if (seasonIdx === 1) {
        this.ctx.fillStyle = 'rgba(254, 240, 138, 0.55)';
        this.ctx.beginPath();
        this.ctx.arc(0, 0, p.size * 0.65, 0, Math.PI * 2);
        this.ctx.fill();
      } else if (seasonIdx === 2) {
        this.ctx.fillStyle = (p.size > 3.4) ? 'rgba(220, 38, 38, 0.75)' : 'rgba(234, 179, 8, 0.8)';
        this.ctx.beginPath();
        this.ctx.ellipse(0, 0, p.size * 1.3, p.size * 0.8, 0, 0, Math.PI * 2);
        this.ctx.fill();
      } else if (seasonIdx === 3) {
        this.ctx.fillStyle = 'rgba(248, 250, 252, 0.85)';
        this.ctx.beginPath();
        this.ctx.arc(0, 0, p.size * 0.8, 0, Math.PI * 2);
        this.ctx.fill();
      }
      this.ctx.restore();
    });

    this.ctx.restore();
  }

  private drawSeamlessRoad(tile: TileData, pos: { x: number; y: number }, halfW: number, halfH: number, gameManager: GameStateManager): void {
    const zoom = this.camera.zoom;
    const cx = pos.x;
    const cy = pos.y;
    const rw = 9 * zoom; // 도로 반폭 (총 폭 약 18px)

    const mask = gameManager.getRoadMask(tile.x, tile.y);
    const n = (mask & 1) !== 0;
    const e = (mask & 2) !== 0;
    const s = (mask & 4) !== 0;
    const w = (mask & 8) !== 0;

    // 1. 도로 음영 테두리 (가장자리 흙둑)
    this.ctx.fillStyle = '#875d2b';
    this.drawRoadBranch(cx, cy, halfW, halfH, rw + 2.5 * zoom, n, e, s, w);

    // 2. 도로 표면 (다져진 황토 박석길)
    this.ctx.fillStyle = '#c79f61';
    this.drawRoadBranch(cx, cy, halfW, halfH, rw, n, e, s, w);

    // 3. 중심 교차로 부드러운 박석 포장
    this.ctx.beginPath();
    this.ctx.ellipse(cx, cy, rw * 1.3, rw * 0.75, 0, 0, Math.PI * 2);
    this.ctx.fill();

    // 4. 박석 도트 질감
    this.ctx.fillStyle = '#aa8044';
    this.ctx.fillRect(cx - 3 * zoom, cy - 1.5 * zoom, 3 * zoom, 2 * zoom);
    this.ctx.fillRect(cx + 2 * zoom, cy + 1 * zoom, 3 * zoom, 2 * zoom);
  }

  private drawRoadBranch(cx: number, cy: number, halfW: number, halfH: number, rw: number, n: boolean, e: boolean, s: boolean, w: boolean): void {
    const rwh = rw * 0.55;

    // 북쪽 가지 (타일 상단 꼭짓점까지 완벽 접합)
    if (n) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx - rw, cy);
      this.ctx.lineTo(cx - rw * 0.8, cy - halfH);
      this.ctx.lineTo(cx + rw * 0.8, cy - halfH);
      this.ctx.lineTo(cx + rw, cy);
      this.ctx.closePath();
      this.ctx.fill();
    }
    // 동쪽 가지 (타일 우측 꼭짓점까지 완벽 접합)
    if (e) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx, cy - rwh);
      this.ctx.lineTo(cx + halfW, cy - rwh * 0.8);
      this.ctx.lineTo(cx + halfW, cy + rwh * 0.8);
      this.ctx.lineTo(cx, cy + rwh);
      this.ctx.closePath();
      this.ctx.fill();
    }
    // 남쪽 가지 (타일 하단 꼭짓점까지 완벽 접합)
    if (s) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx - rw, cy);
      this.ctx.lineTo(cx - rw * 0.8, cy + halfH);
      this.ctx.lineTo(cx + rw * 0.8, cy + halfH);
      this.ctx.lineTo(cx + rw, cy);
      this.ctx.closePath();
      this.ctx.fill();
    }
    // 서쪽 가지 (타일 좌측 꼭짓점까지 완벽 접합)
    if (w) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx, cy - rwh);
      this.ctx.lineTo(cx - halfW, cy - rwh * 0.8);
      this.ctx.lineTo(cx - halfW, cy + rwh * 0.8);
      this.ctx.lineTo(cx, cy + rwh);
      this.ctx.closePath();
      this.ctx.fill();
    }
    if (!n && !e && !s && !w) {
      this.ctx.beginPath();
      this.ctx.ellipse(cx, cy, rw * 1.5, rw * 0.8, 0, 0, Math.PI * 2);
      this.ctx.fill();
    }
  }

  private drawSeamlessWall(tile: TileData, pos: { x: number; y: number }, halfW: number, halfH: number, gameManager: GameStateManager): void {
    const zoom = this.camera.zoom;
    const cx = pos.x;
    const cy = pos.y;
    const ww = 11 * zoom; // 성벽 두께

    const hasRoad = (tile.x > 0 && gameManager.grid[tile.y][tile.x - 1].building === 'road') ||
                    (tile.x + 1 < GameStateManager.MAP_SIZE && gameManager.grid[tile.y][tile.x + 1].building === 'road') ||
                    (tile.y > 0 && gameManager.grid[tile.y - 1][tile.x].building === 'road') ||
                    (tile.y + 1 < GameStateManager.MAP_SIZE && gameManager.grid[tile.y + 1][tile.x].building === 'road');

    // 도로와 교차하는 성곽 지점은 4대문(홍예문 문루) 렌더링
    if (hasRoad && tile.terrain !== 'water') {
      const gateSpr = PixelArtSheets.getGateSprite();
      this.ctx.drawImage(gateSpr, cx - 32 * zoom, cy - 48 * zoom, 64 * zoom, 64 * zoom);
      return;
    }

    const mask = gameManager.getWallMask(tile.x, tile.y);
    const n = (mask & 1) !== 0;
    const e = (mask & 2) !== 0;
    const s = (mask & 4) !== 0;
    const w = (mask & 8) !== 0;

    // 1. 하단 화강암 장대석 기단 (벽돌 틈새 없는 연속 옹벽)
    this.ctx.fillStyle = '#475569';
    this.drawWallBody(cx, cy + 4 * zoom, halfW, halfH, ww + 2 * zoom, n, e, s, w);

    // 2. 상단 검은 전돌 체성 (수원화성 특유의 전돌 성벽)
    this.ctx.fillStyle = '#1e293b';
    this.drawWallBody(cx, cy - 6 * zoom, halfW, halfH, ww, n, e, s, w);

    // 3. 중심 망루/체성 코어
    this.ctx.fillRect(cx - ww, cy - 14 * zoom, ww * 2, 16 * zoom);

    // 4. 여장(총안 담장) 및 성돌 텍스처
    this.ctx.fillStyle = '#0f172a';
    this.ctx.fillRect(cx - ww, cy - 18 * zoom, 6 * zoom, 5 * zoom);
    this.ctx.fillRect(cx + ww - 6 * zoom, cy - 18 * zoom, 6 * zoom, 5 * zoom);

    // 총안 구멍
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(cx - ww + 1.5 * zoom, cy - 16 * zoom, 3 * zoom, 2 * zoom);
    this.ctx.fillRect(cx + ww - 4.5 * zoom, cy - 16 * zoom, 3 * zoom, 2 * zoom);
  }

  private drawWallBody(cx: number, cy: number, halfW: number, halfH: number, ww: number, n: boolean, e: boolean, s: boolean, w: boolean): void {
    const wwh = ww * 0.6;
    if (n) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx - ww, cy);
      this.ctx.lineTo(cx - ww, cy - halfH);
      this.ctx.lineTo(cx + ww, cy - halfH);
      this.ctx.lineTo(cx + ww, cy);
      this.ctx.closePath();
      this.ctx.fill();
    }
    if (e) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx, cy - wwh);
      this.ctx.lineTo(cx + halfW, cy - wwh);
      this.ctx.lineTo(cx + halfW, cy + wwh);
      this.ctx.lineTo(cx, cy + wwh);
      this.ctx.closePath();
      this.ctx.fill();
    }
    if (s) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx - ww, cy);
      this.ctx.lineTo(cx - ww, cy + halfH);
      this.ctx.lineTo(cx + ww, cy + halfH);
      this.ctx.lineTo(cx + ww, cy);
      this.ctx.closePath();
      this.ctx.fill();
    }
    if (w) {
      this.ctx.beginPath();
      this.ctx.moveTo(cx, cy - wwh);
      this.ctx.lineTo(cx - halfW, cy - wwh);
      this.ctx.lineTo(cx - halfW, cy + wwh);
      this.ctx.lineTo(cx, cy + wwh);
      this.ctx.closePath();
      this.ctx.fill();
    }
    if (!n && !e && !s && !w) {
      this.ctx.fillRect(cx - ww, cy - wwh, ww * 2, wwh * 2);
    }
  }

  private getPalette(seasonIdx: number) {
    switch (seasonIdx) {
      case 0:
        return { plainTop: '#6fa13f', mountainTop: '#547d2b', water: '#2563eb' };
      case 1:
        return { plainTop: '#2b873c', mountainTop: '#1e662c', water: '#1d4ed8' };
      case 2:
        return { plainTop: '#b6872a', mountainTop: '#914319', water: '#3b82f6' };
      case 3:
        return { plainTop: '#eaf0f6', mountainTop: '#9fb3c9', water: '#60a5fa' };
      default:
        return { plainTop: '#6fa13f', mountainTop: '#547d2b', water: '#2563eb' };
    }
  }
}
