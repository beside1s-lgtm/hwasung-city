/**
 * 수원화성 2.5D 도트 스프라이트 시트 제너레이터 & 캐시 매니저
 * 도로 및 성벽 오토타일링(16방향), 조선 전통 건축(초가, 기와, 주막, 시전, 물레방아 둔전),
 * 실시간 보행/작업 백성(지게꾼, 보부상, 장용영 병사, 농민)의 고해상도 픽셀 스프라이트 생성
 */

export class PixelArtSheets {
  private static spriteCache: Map<string, HTMLCanvasElement> = new Map();

  private static createSheetCanvas(w: number, h: number): { canvas: HTMLCanvasElement; ctx: CanvasRenderingContext2D } {
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true })!;
    ctx.imageSmoothingEnabled = false;
    return { canvas, ctx };
  }

  /**
   * 1. 3D 절벽 단면 (Cliff Sheet 64x32)
   */
  public static getCliffSprite(type: 'west' | 'east', seasonIdx: number): HTMLCanvasElement {
    const key = `cliff_${type}_${seasonIdx}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(64, 32);
    const baseColor = (type === 'west') ? '#6b4c2b' : '#52381f';
    const darkColor = (type === 'west') ? '#422c15' : '#332010';
    const highlight = (type === 'west') ? '#8c653d' : '#6e4c2c';

    ctx.fillStyle = baseColor;
    ctx.fillRect(0, 0, 64, 32);

    for (let y = 0; y < 32; y += 4) {
      ctx.fillStyle = darkColor;
      ctx.fillRect(0, y, 64, 1.5);
      for (let x = (y % 8); x < 64; x += 12) {
        ctx.fillRect(x, y, 1.5, 4);
      }
    }

    ctx.fillStyle = highlight;
    for (let x = 0; x < 64; x += 4) {
      ctx.fillRect(x, (x % 3), 3, 1.5);
    }

    if (seasonIdx === 3) {
      ctx.fillStyle = 'rgba(235, 243, 250, 0.85)';
      ctx.fillRect(0, 0, 64, 3);
      for (let x = 0; x < 64; x += 6) {
        ctx.fillRect(x, 3, 4, 2);
      }
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 2. 도로 오토타일링 (16방향 연결 박석/황토 삼남대로, 64x32)
   * mask: 북(1) + 동(2) + 남(4) + 서(8)
   */
  public static getRoadSprite(mask: number): HTMLCanvasElement {
    const key = `road_mask_${mask}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(64, 32);

    // 아이소메트릭 다이아몬드 좌표: 북(32, 0), 동(64, 16), 남(32, 32), 서(0, 16), 중심(32, 16)
    ctx.fillStyle = '#b38d4f';
    ctx.strokeStyle = '#8c6230';
    ctx.lineWidth = 1;

    // 중심 로터리/교차 코어
    ctx.beginPath();
    ctx.arc(32, 16, 6, 0, Math.PI * 2);
    ctx.fill();

    const n = (mask & 1) !== 0;
    const e = (mask & 2) !== 0;
    const s = (mask & 4) !== 0;
    const w = (mask & 8) !== 0;

    // 북쪽 가지 (32, 0 쪽)
    if (n) {
      ctx.beginPath();
      ctx.moveTo(27, 16); ctx.lineTo(28, 0); ctx.lineTo(36, 0); ctx.lineTo(37, 16);
      ctx.closePath(); ctx.fill();
    }
    // 동쪽 가지 (64, 16 쪽)
    if (e) {
      ctx.beginPath();
      ctx.moveTo(32, 11); ctx.lineTo(64, 12); ctx.lineTo(64, 20); ctx.lineTo(32, 21);
      ctx.closePath(); ctx.fill();
    }
    // 남쪽 가지 (32, 32 쪽)
    if (s) {
      ctx.beginPath();
      ctx.moveTo(27, 16); ctx.lineTo(28, 32); ctx.lineTo(36, 32); ctx.lineTo(37, 16);
      ctx.closePath(); ctx.fill();
    }
    // 서쪽 가지 (0, 16 쪽)
    if (w) {
      ctx.beginPath();
      ctx.moveTo(32, 11); ctx.lineTo(0, 12); ctx.lineTo(0, 20); ctx.lineTo(32, 21);
      ctx.closePath(); ctx.fill();
    }

    // 고립된 단일 도로(mask === 0)일 경우 작은 박석 광장
    if (mask === 0) {
      ctx.beginPath();
      ctx.ellipse(32, 16, 12, 6, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    // 박석 도트 텍스처 (돌길 느낌)
    ctx.fillStyle = '#96703c';
    for (let i = 0; i < 6; i++) {
      const rx = 24 + (i * 3) % 16;
      const ry = 12 + (i * 2) % 8;
      ctx.fillRect(rx, ry, 2, 1.5);
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 3. 성곽 오토타일링 (16방향 연결 화성 성곽 체성 및 여장, 64x48)
   * 인접 성벽과 틈새 없이 완벽히 이어지도록 렌더링
   */
  public static getWallAutoSprite(mask: number): HTMLCanvasElement {
    const key = `wall_auto_${mask}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(64, 48);

    const n = (mask & 1) !== 0;
    const e = (mask & 2) !== 0;
    const s = (mask & 4) !== 0;
    const w = (mask & 8) !== 0;

    // 기본 화강암 기단석 베이스 (중심 32, 32)
    ctx.fillStyle = '#57534e';
    ctx.fillRect(20, 26, 24, 14);

    // 전돌 상단부
    ctx.fillStyle = '#292524';
    ctx.fillRect(22, 18, 20, 10);

    // 총안 여장 (담장)
    ctx.fillStyle = '#1c1917';
    ctx.fillRect(22, 12, 6, 6);
    ctx.fillRect(36, 12, 6, 6);

    // 연결 가지 확장 (북/동/남/서로 두껍게 이어짐)
    if (n) {
      ctx.fillStyle = '#57534e';
      ctx.fillRect(26, 8, 12, 20);
      ctx.fillStyle = '#292524';
      ctx.fillRect(27, 2, 10, 10);
    }
    if (s) {
      ctx.fillStyle = '#57534e';
      ctx.fillRect(26, 28, 12, 18);
      ctx.fillStyle = '#292524';
      ctx.fillRect(27, 26, 10, 12);
    }
    if (w) {
      ctx.fillStyle = '#57534e';
      ctx.fillRect(0, 24, 24, 14);
      ctx.fillStyle = '#292524';
      ctx.fillRect(0, 16, 24, 10);
      ctx.fillStyle = '#1c1917';
      ctx.fillRect(2, 12, 8, 6);
      ctx.fillRect(14, 12, 8, 6);
    }
    if (e) {
      ctx.fillStyle = '#57534e';
      ctx.fillRect(40, 24, 24, 14);
      ctx.fillStyle = '#292524';
      ctx.fillRect(40, 16, 24, 10);
      ctx.fillStyle = '#1c1917';
      ctx.fillRect(42, 12, 8, 6);
      ctx.fillRect(54, 12, 8, 6);
    }

    // 성돌 텍스처 선
    ctx.fillStyle = '#78716c';
    ctx.fillRect(20, 32, 24, 1);
    ctx.fillRect(20, 38, 24, 1);

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 4. 초가삼간 민가 스프라이트 (Choga Sheet 48x36, 마당, 장독대 디테일)
   */
  public static getChogaSprite(seasonIdx: number): HTMLCanvasElement {
    const key = `choga_${seasonIdx}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(48, 36);

    // 마당 및 울타리
    ctx.fillStyle = '#c79c5e';
    ctx.fillRect(10, 16, 28, 16);

    // 나무 기둥
    ctx.fillStyle = '#6b4423';
    ctx.fillRect(10, 16, 2.5, 16);
    ctx.fillRect(35, 16, 2.5, 16);
    ctx.fillRect(22, 16, 2, 16);

    // 봉창문과 마루
    ctx.fillStyle = '#fdf8ee';
    ctx.fillRect(14, 20, 6, 8);
    ctx.fillStyle = '#b45309';
    ctx.fillRect(24, 24, 10, 6);

    // 볏짚 지붕 곡선
    ctx.fillStyle = seasonIdx === 3 ? '#e2e8f0' : '#b45309';
    ctx.beginPath();
    ctx.moveTo(24, 4);
    ctx.quadraticCurveTo(44, 8, 44, 18);
    ctx.lineTo(4, 18);
    ctx.quadraticCurveTo(4, 8, 24, 4);
    ctx.fill();

    // 새끼줄
    ctx.strokeStyle = seasonIdx === 3 ? '#94a3b8' : '#78350f';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(12, 8); ctx.lineTo(10, 18);
    ctx.moveTo(24, 6); ctx.lineTo(24, 18);
    ctx.moveTo(36, 8); ctx.lineTo(38, 18);
    ctx.stroke();

    // 장독대 (앞마당 항아리 2개)
    ctx.fillStyle = '#44403c';
    ctx.beginPath();
    ctx.ellipse(39, 29, 3, 4, 0, 0, Math.PI * 2);
    ctx.ellipse(44, 30, 2.5, 3.5, 0, 0, Math.PI * 2);
    ctx.fill();

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 5. 고래등 기와집 스프라이트 (Giwa Sheet 56x44, 팔작지붕, 행랑채)
   */
  public static getGiwaSprite(seasonIdx: number): HTMLCanvasElement {
    const key = `giwa_${seasonIdx}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(56, 44);

    // 화강암 기단
    ctx.fillStyle = '#78716c';
    ctx.fillRect(8, 34, 40, 6);

    // 흰 회벽과 목조 기둥
    ctx.fillStyle = '#f5eedb';
    ctx.fillRect(10, 18, 36, 17);
    ctx.fillStyle = '#78350f';
    ctx.fillRect(10, 18, 3, 17);
    ctx.fillRect(27, 18, 2.5, 17);
    ctx.fillRect(43, 18, 3, 17);

    // 대청마루와 격자문
    ctx.fillStyle = '#b45309';
    ctx.fillRect(14, 26, 12, 8);
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(30, 20, 12, 12);

    // 팔작지붕 기와
    ctx.fillStyle = seasonIdx === 3 ? '#e2e8f0' : '#1e293b';
    ctx.beginPath();
    ctx.moveTo(28, 4);
    ctx.lineTo(54, 18);
    ctx.lineTo(50, 20);
    ctx.lineTo(28, 9);
    ctx.lineTo(6, 20);
    ctx.lineTo(2, 18);
    ctx.closePath();
    ctx.fill();

    // 단청
    ctx.fillStyle = '#b91c1c';
    ctx.fillRect(10, 17, 36, 2);
    ctx.fillStyle = '#059669';
    for (let i = 12; i < 44; i += 6) {
      ctx.fillRect(i, 17, 2.5, 2);
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 6. 주막 및 저잣거리 상점 (Com 1, 48x40 - 삼색 차양막, 평상, 주막 깃발)
   */
  public static getJumakSprite(): HTMLCanvasElement {
    const key = 'jumak_com1';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(48, 40);

    // 주막 건물 본체
    ctx.fillStyle = '#c79c5e';
    ctx.fillRect(6, 16, 24, 18);

    // 초가지붕
    ctx.fillStyle = '#b45309';
    ctx.beginPath();
    ctx.moveTo(18, 6);
    ctx.lineTo(34, 16);
    ctx.lineTo(2, 16);
    ctx.closePath();
    ctx.fill();

    // 주막 앞 평상 (나무 평상)
    ctx.fillStyle = '#92400e';
    ctx.fillRect(28, 26, 16, 10);
    ctx.fillStyle = '#78350f';
    ctx.fillRect(29, 34, 2, 4);
    ctx.fillRect(41, 34, 2, 4);

    // 삼색 차양막 (포목 차양)
    ctx.fillStyle = '#ef4444'; ctx.fillRect(24, 18, 6, 6);
    ctx.fillStyle = '#3b82f6'; ctx.fillRect(30, 18, 6, 6);
    ctx.fillStyle = '#eab308'; ctx.fillRect(36, 18, 6, 6);

    // '주(酒)' 깃발
    ctx.fillStyle = '#78350f';
    ctx.fillRect(44, 10, 2, 22);
    ctx.fillStyle = '#fef08a';
    ctx.fillRect(36, 10, 8, 7);
    ctx.fillStyle = '#dc2626';
    ctx.fillRect(39, 12, 3, 3); // 술 주 도트

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 7. 대형 시전 상가 / 육의전 (Com 2, 56x48 - 2층 루각, 청사초롱)
   */
  public static getMarketSprite(): HTMLCanvasElement {
    const key = 'market_com2';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(56, 48);

    // 1층 및 2층 기둥
    ctx.fillStyle = '#78350f';
    ctx.fillRect(8, 26, 40, 16);
    ctx.fillStyle = '#fef3c7';
    ctx.fillRect(10, 28, 36, 14);

    // 2층 누각
    ctx.fillStyle = '#991b1b';
    ctx.fillRect(12, 16, 32, 12);
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(16, 18, 24, 8);

    // 기와지붕
    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.moveTo(28, 4);
    ctx.lineTo(52, 16);
    ctx.lineTo(4, 16);
    ctx.closePath();
    ctx.fill();

    // 청사초롱 2개 (청색/홍색 초롱불)
    ctx.fillStyle = '#ef4444'; ctx.fillRect(10, 24, 3, 3);
    ctx.fillStyle = '#2563eb'; ctx.fillRect(10, 27, 3, 3);
    ctx.fillStyle = '#ef4444'; ctx.fillRect(43, 24, 3, 3);
    ctx.fillStyle = '#2563eb'; ctx.fillRect(43, 27, 3, 3);

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 8. 대유둔전 논두렁 및 물레방아 (Agr Sheet 48x36)
   */
  public static getAgrSprite(level: number, seasonIdx: number): HTMLCanvasElement {
    const key = `agr_${level}_${seasonIdx}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(48, 36);

    const cropColor = seasonIdx === 2 ? '#eab308' : (seasonIdx === 3 ? '#94a3b8' : '#22c55e');

    // 논두렁 구획선
    ctx.fillStyle = '#713f12';
    ctx.fillRect(4, 16, 40, 3);
    ctx.fillRect(22, 6, 4, 24);

    // 벼 포기 도트들
    ctx.fillStyle = cropColor;
    for (let x = 6; x < 42; x += 6) {
      for (let y = 8; y < 32; y += 7) {
        if (x !== 22) {
          ctx.fillRect(x, y, 3, 4);
          ctx.fillRect(x - 1, y + 1, 1, 2);
          ctx.fillRect(x + 3, y + 1, 1, 2);
        }
      }
    }

    // 2단계 발전 시 물레방아 및 볏가리
    if (level === 2) {
      // 볏가리 (노적가리)
      ctx.fillStyle = '#ca8a04';
      ctx.beginPath();
      ctx.moveTo(38, 20); ctx.lineTo(44, 28); ctx.lineTo(32, 28); ctx.closePath();
      ctx.fill();

      // 물레방아 바퀴
      ctx.strokeStyle = '#78350f';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(10, 24, 5, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(10, 19); ctx.lineTo(10, 29);
      ctx.moveTo(5, 24); ctx.lineTo(15, 24);
      ctx.stroke();
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 9. 수원화성 4대문 문루 (Gate 64x64)
   */
  public static getGateSprite(): HTMLCanvasElement {
    const key = 'gate_monument';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(64, 64);

    ctx.fillStyle = '#57534e';
    ctx.fillRect(8, 30, 48, 24);

    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.arc(32, 54, 12, Math.PI, 0);
    ctx.fill();

    ctx.strokeStyle = '#78716c';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(32, 56, 22, Math.PI * 0.1, Math.PI * 0.9);
    ctx.stroke();

    ctx.fillStyle = '#dc2626';
    ctx.fillRect(14, 16, 36, 14);
    ctx.fillStyle = '#059669';
    ctx.fillRect(12, 14, 40, 2);
    ctx.fillRect(14, 22, 36, 2);

    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.moveTo(32, 4);
    ctx.lineTo(58, 14);
    ctx.lineTo(54, 16);
    ctx.lineTo(32, 8);
    ctx.lineTo(10, 16);
    ctx.lineTo(6, 14);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = '#ef4444';
    ctx.beginPath();
    ctx.moveTo(48, 6);
    ctx.lineTo(60, 3);
    ctx.lineTo(56, 10);
    ctx.closePath();
    ctx.fill();

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 10. 실시간 보행 백성 에이전트 스프라이트들 (24x24)
   * 타입: carrier(지게꾼), merchant(보부상), guard(장용영), farmer(농민)
   */
  public static getCitizenSprite(type: string, frame: number): HTMLCanvasElement {
    const key = `cit_${type}_${frame % 2}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(24, 24);
    const bob = (frame % 2 === 0) ? 0 : 1;

    // 공통 머리 및 얼굴
    ctx.fillStyle = '#fed7aa';
    ctx.fillRect(10, 5 + bob, 4, 4);

    if (type === 'carrier' || type === 'supply_carrier') {
      // 지게꾼 / 보급 운반: 패랭이 + 흰 무명옷 + 나무 지게와 쌀가마니/물동이
      ctx.fillStyle = '#d97706'; ctx.fillRect(9, 4 + bob, 6, 2); // 패랭이
      ctx.fillStyle = '#f8fafc'; ctx.fillRect(9, 9 + bob, 6, 6); // 흰옷
      ctx.fillStyle = '#475569'; ctx.fillRect(10, 15 + bob, 2, 5 - bob); ctx.fillRect(13, 15 + bob, 2, 5 + bob); // 다리
      ctx.fillStyle = '#78350f'; ctx.fillRect(6, 6 + bob, 2, 10); // 지게 나무
      ctx.fillStyle = '#ca8a04'; ctx.fillRect(4, 7 + bob, 4, 6); // 쌀가마
    } else if (type === 'merchant') {
      // 보부상: 목화송이 패랭이 + 봇짐
      ctx.fillStyle = '#d97706'; ctx.fillRect(9, 4 + bob, 6, 2);
      ctx.fillStyle = '#ffffff'; ctx.fillRect(8, 4 + bob, 1.5, 1.5); ctx.fillRect(14, 4 + bob, 1.5, 1.5);
      ctx.fillStyle = '#f8fafc'; ctx.fillRect(9, 9 + bob, 6, 6);
      ctx.fillStyle = '#334155'; ctx.fillRect(10, 15 + bob, 2, 5 - bob); ctx.fillRect(13, 15 + bob, 2, 5 + bob);
      ctx.fillStyle = '#b45309'; ctx.fillRect(5, 7 + bob, 4, 6); // 봇짐
    } else if (type === 'guard' || type === 'militia' || type === 'posu' || type === 'sasu' || type === 'salsu' || type === 'gipo' || type === 'traitor') {
      // 장용영 / 정규군 / 의병: 흑립 + 붉은 동달이 + 장창
      ctx.fillStyle = '#0f172a'; ctx.fillRect(9, 3 + bob, 6, 2);
      ctx.fillStyle = '#dc2626'; ctx.fillRect(11, 2 + bob, 2, 2); // 깃털
      ctx.fillStyle = (type === 'posu') ? '#1e3a8a' : (type === 'sasu') ? '#047857' : '#b91c1c'; // 병종별 군복색
      ctx.fillRect(9, 9 + bob, 6, 6);
      ctx.fillStyle = '#0f172a'; ctx.fillRect(9, 12 + bob, 6, 1.5); // 허리띠
      ctx.fillStyle = '#1e293b'; ctx.fillRect(10, 15 + bob, 2, 5 - bob); ctx.fillRect(13, 15 + bob, 2, 5 + bob);
      ctx.fillStyle = '#78350f'; ctx.fillRect(16, 1 + bob, 1.5, 18); // 장창 / 무기
      ctx.fillStyle = '#e2e8f0'; ctx.fillRect(15.5, 0 + bob, 2.5, 2.5); // 창날 / 총열
    } else {
      // 농민: 상투 + 괭이/호미
      ctx.fillStyle = '#0f172a'; ctx.fillRect(11, 3 + bob, 2, 2); // 상투
      ctx.fillStyle = '#e2e8f0'; ctx.fillRect(9, 9 + bob, 6, 6);
      ctx.fillStyle = '#713f12'; ctx.fillRect(10, 15 + bob, 2, 5 - bob); ctx.fillRect(13, 15 + bob, 2, 5 + bob);
      ctx.fillStyle = '#78350f'; ctx.fillRect(6, 6 + bob, 1.5, 12); // 괭이 자루
      ctx.fillStyle = '#64748b'; ctx.fillRect(5, 5 + bob, 4, 2); // 괭이 쇠날
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 11. 청계천/수원천 석축 제방 (Levee 48x32)
   */
  public static getLeveeSprite(): HTMLCanvasElement {
    const key = 'levee_embankment';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(48, 32);

    // 화강암 견치석 석축 옹벽
    ctx.fillStyle = '#64748b';
    ctx.fillRect(4, 12, 40, 16);
    ctx.fillStyle = '#475569';
    for (let y = 12; y < 28; y += 4) {
      ctx.fillRect(4, y, 40, 1);
      for (let x = (y % 8); x < 44; x += 8) {
        ctx.fillRect(x, y, 1, 4);
      }
    }

    // 제방 둑 상단 흙길
    ctx.fillStyle = '#b38d4f';
    ctx.fillRect(4, 8, 40, 4);

    // 물막이 나무 말뚝
    ctx.fillStyle = '#78350f';
    for (let x = 6; x < 44; x += 7) {
      ctx.fillRect(x, 6, 2.5, 6);
    }

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 12. 만석거/축만제 고지대 저수지 (Reservoir 56x44)
   */
  public static getReservoirSprite(): HTMLCanvasElement {
    const key = 'reservoir_manseok';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(56, 44);

    // 저수지 제방 둑
    ctx.fillStyle = '#57534e';
    ctx.fillRect(6, 14, 44, 26);

    // 저수지 담수호 (깊고 맑은 수면)
    ctx.fillStyle = '#0284c7';
    ctx.beginPath();
    ctx.ellipse(28, 24, 18, 9, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#0369a1';
    ctx.beginPath();
    ctx.ellipse(28, 24, 12, 6, 0, 0, Math.PI * 2);
    ctx.fill();

    // 관개 수문 (홍예 아치형 석조 갑문)
    ctx.fillStyle = '#334155';
    ctx.fillRect(23, 30, 10, 8);
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(25, 32, 6, 6); // 수문 구멍

    // 수문 목조 승강기 틀
    ctx.fillStyle = '#78350f';
    ctx.fillRect(23, 24, 2, 8);
    ctx.fillRect(31, 24, 2, 8);
    ctx.fillRect(21, 24, 14, 2);

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 13. 국책 대역사 공사 현장 (비계 및 거중기 48x40)
   */
  public static getConstructionSprite(): HTMLCanvasElement {
    const key = 'construction_site';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(48, 40);

    // 쌓아둔 장대석/성돌
    ctx.fillStyle = '#64748b';
    ctx.fillRect(8, 28, 14, 8);
    ctx.fillRect(10, 22, 10, 6);
    ctx.fillStyle = '#475569';
    ctx.fillRect(9, 28, 12, 1);
    ctx.fillRect(9, 32, 12, 1);

    // 목조 가설 비계 (Scaffolding 통나무 기둥 및 발판)
    ctx.fillStyle = '#78350f';
    ctx.fillRect(24, 10, 3, 26);
    ctx.fillRect(38, 10, 3, 26);
    ctx.fillRect(22, 16, 20, 2.5); // 1층 발판
    ctx.fillRect(22, 26, 20, 2.5); // 2층 발판
    // X자 가새(Bracing)
    ctx.strokeStyle = '#92400e';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(25, 10); ctx.lineTo(39, 26);
    ctx.moveTo(39, 10); ctx.lineTo(25, 26);
    ctx.stroke();

    // 정약용의 거중기 도르래와 밧줄
    ctx.fillStyle = '#b45309';
    ctx.fillRect(30, 4, 3, 12);
    ctx.strokeStyle = '#fef08a';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(31.5, 6, 3, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(31.5, 9); ctx.lineTo(15, 22); // 밧줄
    ctx.stroke();

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 14. 화산 현륭원(顯隆園) 사도세자 묘역 스프라이트 (64x52)
   * 조선 왕릉 능원: 둥근 봉분, 병풍석/곡장, 정자각, 비각, 주변 노송
   */
  public static getHyoryungwonSprite(): HTMLCanvasElement {
    const key = 'hyoryungwon_shrine';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(64, 52);

    // 봉분 능선 잔디 언덕
    ctx.fillStyle = '#2e7d32';
    ctx.beginPath();
    ctx.ellipse(32, 22, 20, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    // 능원 곡장(담장)
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(32, 20, 18, Math.PI * 0.85, Math.PI * 2.15);
    ctx.stroke();

    // 사도세자 원침 봉분 (잔디 둔덕 중심)
    ctx.fillStyle = '#4ade80';
    ctx.beginPath();
    ctx.arc(32, 18, 9, 0, Math.PI * 2);
    ctx.fill();

    // 상석 및 장명등 석물
    ctx.fillStyle = '#cbd5e1';
    ctx.fillRect(28, 26, 8, 3);
    ctx.fillRect(30, 24, 4, 3);

    // 정자각 (T자형 제향 건물 기와지붕)
    ctx.fillStyle = '#1e293b';
    ctx.beginPath();
    ctx.moveTo(18, 38); ctx.lineTo(32, 30); ctx.lineTo(46, 38); ctx.lineTo(44, 42); ctx.lineTo(20, 42);
    ctx.closePath(); ctx.fill();

    // 정자각 붉은 단청 기둥
    ctx.fillStyle = '#dc2626';
    ctx.fillRect(22, 42, 3, 7);
    ctx.fillRect(39, 42, 3, 7);
    ctx.fillRect(28, 42, 8, 7);

    // 홍살문 (입구 붉은 문)
    ctx.fillStyle = '#b91c1c';
    ctx.fillRect(10, 36, 2, 12);
    ctx.fillRect(18, 36, 2, 12);
    ctx.fillRect(9, 39, 12, 2);

    // 노송 (소나무) 2그루
    ctx.fillStyle = '#78350f';
    ctx.fillRect(6, 20, 2, 12);
    ctx.fillRect(54, 18, 2, 14);
    ctx.fillStyle = '#14532d';
    ctx.beginPath(); ctx.arc(7, 18, 5, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(55, 16, 6, 0, Math.PI * 2); ctx.fill();

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 15. 수원화성 성문/관문 (장안문/팔달문 56x56)
   * 웅장한 무지개 홍예 석축 + 2층 누각 문루
   */
  public static getBorderGateSprite(): HTMLCanvasElement {
    const key = 'border_gate';
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(56, 56);

    // 화강암 육축(기단 석벽)
    ctx.fillStyle = '#64748b';
    ctx.fillRect(8, 28, 40, 24);
    ctx.fillStyle = '#475569';
    ctx.fillRect(6, 26, 44, 3);

    // 중앙 홍예문 (무지개 아치 터널)
    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.arc(28, 44, 9, Math.PI, 0, false);
    ctx.lineTo(37, 52); ctx.lineTo(19, 52);
    ctx.closePath(); ctx.fill();

    // 철갑 대문 빗장 도트
    ctx.fillStyle = '#7c2d12';
    ctx.fillRect(21, 44, 6, 8);
    ctx.fillRect(29, 44, 6, 8);

    // 1층 문루 누각 (단청과 붉은 기둥)
    ctx.fillStyle = '#dc2626';
    ctx.fillRect(14, 20, 3, 7);
    ctx.fillRect(26, 20, 4, 7);
    ctx.fillRect(39, 20, 3, 7);

    // 1층 팔작지붕
    ctx.fillStyle = '#1e293b';
    ctx.beginPath();
    ctx.moveTo(8, 22); ctx.lineTo(28, 14); ctx.lineTo(48, 22); ctx.lineTo(46, 25); ctx.lineTo(10, 25);
    ctx.closePath(); ctx.fill();

    // 2층 문루 누각 및 우진각 기와지붕
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(18, 10, 20, 5);
    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.moveTo(12, 11); ctx.lineTo(28, 4); ctx.lineTo(44, 11); ctx.lineTo(42, 13); ctx.lineTo(14, 13);
    ctx.closePath(); ctx.fill();

    // 장용영 수문장 깃발
    ctx.strokeStyle = '#ca8a04';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(43, 4); ctx.lineTo(43, 14); ctx.stroke();
    ctx.fillStyle = '#eab308';
    ctx.beginPath(); ctx.moveTo(43, 4); ctx.lineTo(50, 7); ctx.lineTo(43, 10); ctx.closePath(); ctx.fill();

    this.spriteCache.set(key, canvas);
    return canvas;
  }

  /**
   * 16. 정조시대 백두산 맹호/호랑이 스프라이트 (32x24)
   */
  public static getTigerSprite(frame: number = 0): HTMLCanvasElement {
    const key = `tiger_sprite_${frame % 2}`;
    if (this.spriteCache.has(key)) return this.spriteCache.get(key)!;

    const { canvas, ctx } = this.createSheetCanvas(32, 24);

    // 몸통 황갈색
    ctx.fillStyle = '#d97706';
    ctx.beginPath();
    ctx.ellipse(16, 12, 10, 6, 0, 0, Math.PI * 2);
    ctx.fill();

    // 검은 호랑이 줄무늬
    ctx.strokeStyle = '#1c1917';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(13, 8); ctx.lineTo(14, 16);
    ctx.moveTo(17, 7); ctx.lineTo(17, 17);
    ctx.moveTo(21, 9); ctx.lineTo(20, 16);
    ctx.stroke();

    // 머리
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath();
    ctx.arc(8, 10, 5, 0, Math.PI * 2);
    ctx.fill();

    // 귀
    ctx.fillStyle = '#1c1917';
    ctx.beginPath(); ctx.arc(6, 6, 2, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(10, 6, 2, 0, Math.PI * 2); ctx.fill();

    // 다리
    const legOffset = (frame % 2 === 0) ? 0 : 2;
    ctx.fillStyle = '#b45309';
    ctx.fillRect(8, 16 - legOffset, 2.5, 6 + legOffset);
    ctx.fillRect(13, 16 + legOffset, 2.5, 6 - legOffset);
    ctx.fillRect(19, 16 - legOffset, 2.5, 6 + legOffset);
    ctx.fillRect(23, 16 + legOffset, 2.5, 6 - legOffset);

    // 꼬리
    ctx.strokeStyle = '#d97706';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(25, 11);
    ctx.quadraticCurveTo(29, 6, 28, 3);
    ctx.stroke();

    this.spriteCache.set(key, canvas);
    return canvas;
  }
}
