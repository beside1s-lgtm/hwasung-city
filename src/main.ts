import { GameStateManager } from './core/GameState';
import { AudioSystem } from './core/AudioSystem';
import { IsometricRenderer } from './render/IsometricRenderer';
import { ModalManager } from './ui/ModalManager';
import { HistoryEventManager } from './domain/HistoryEvents';
import { NewspaperArticle } from './types';

class HwaseongApp {
  private game: GameStateManager;
  private audio: AudioSystem;
  private renderer: IsometricRenderer;
  private modal: ModalManager;

  private isPointerDown = false;
  private isMiddlePanning = false;
  private hoverTile: { x: number; y: number } | null = null;
  private pointerDownScreen = { x: 0, y: 0 };
  private lastScreenPos = { x: 0, y: 0 };
  private dragStartGrid: { x: number; y: number } | null = null;
  private dragCurrentGrid: { x: number; y: number } | null = null;
  private latestArticle: NewspaperArticle | null = null;

  constructor() {
    this.game = new GameStateManager();
    this.audio = new AudioSystem();
    const canvas = document.getElementById('gameCanvas') as HTMLCanvasElement;
    const viewport = document.getElementById('viewport') as HTMLElement;
    this.renderer = new IsometricRenderer(canvas, viewport);
    this.modal = new ModalManager();

    this.latestArticle = this.game.generateNewspaperArticle(null);

    this.bindEvents(viewport);
    this.updateHUD();
    this.updateQuestUI();
    this.updateCompassUI();

    // 시작 시 첫 어명 교지 모달
    setTimeout(() => {
      this.modal.open(
        "정조 대왕의 첫 어명",
        "수원화성 신도시 축조의 교지",
        `<p class="font-traditional leading-relaxed mb-3">
          "과인이 사도세자의 묘소를 화산으로 모시고, 이곳 수원을 자주국방과 상업 번영의 중심 도시로 개척하고자 하노라.<br><br>
          그대는 유수부의 동헌을 세우고, 삼남대로를 닦아 백성을 모으며, 24년 내에 웅장한 수원화성을 완공하여 세도정치의 싹을 잘라내라!"
        </p>`,
        [
          { text: "어명을 받듭니다 (동헌 터 잡기)", primary: true, action: () => { this.modal.close(); this.selectTool('office'); } }
        ]
      );
    }, 400);

    this.loop();
  }

  private loop = (): void => {
    this.game.updateCitizens();

    const dragTiles = (this.dragStartGrid && this.dragCurrentGrid && !this.game.state.isPanMode && this.game.state.currentTool !== 'inspect') ?
      this.getDragTiles(this.dragStartGrid, this.dragCurrentGrid, this.game.state.currentTool) : [];

    this.renderer.render(
      this.game.grid,
      this.game.cornerHeights,
      this.game.citizens,
      this.game.state,
      this.hoverTile,
      dragTiles,
      this.isPointerDown,
      this.isMiddlePanning,
      this.game
    );
    requestAnimationFrame(this.loop);
  };

  private bindEvents(viewport: HTMLElement): void {
    window.addEventListener('resize', () => this.renderer.resize());

    // 마우스 휠 클릭(Middle Click) 맵 이동 (패닝)
    viewport.addEventListener('mousedown', e => {
      if (e.button === 1) {
        e.preventDefault();
        this.isMiddlePanning = true;
        this.lastScreenPos = { x: e.clientX, y: e.clientY };
        viewport.style.cursor = 'grabbing';
      }
    });

    viewport.addEventListener('auxclick', e => {
      if (e.button === 1) e.preventDefault();
    });

    window.addEventListener('mouseup', e => {
      if (this.isMiddlePanning && (e.button === 1 || e.buttons === 0)) {
        this.isMiddlePanning = false;
        viewport.style.cursor = this.game.state.isPanMode ? 'grab' : 'crosshair';
      }
    });

    // 마우스 휠 스크롤 줌 인/아웃 (마우스 포인터 중심 줌)
    viewport.addEventListener('wheel', e => {
      e.preventDefault();
      const zoomFactor = e.deltaY < 0 ? 1.12 : 0.88;
      const cam = this.renderer.camera;
      const newZoom = Math.max(cam.minZoom, Math.min(cam.maxZoom, cam.zoom * zoomFactor));
      const cPos = this.renderer.getCanvasPos(e.clientX, e.clientY);
      cam.x = cPos.x - (cPos.x - cam.x) * (newZoom / cam.zoom);
      cam.y = cPos.y - (cPos.y - cam.y) * (newZoom / cam.zoom);
      cam.zoom = newZoom;
    }, { passive: false });

    // 포인터 다운 (회전각 반영)
    viewport.addEventListener('pointerdown', e => {
      if (e.button === 1) return;
      if (e.button !== 0 && e.pointerType === 'mouse') return;

      this.isPointerDown = true;
      this.pointerDownScreen = { x: e.clientX, y: e.clientY };
      this.lastScreenPos = { x: e.clientX, y: e.clientY };

      const cPos = this.renderer.getCanvasPos(e.clientX, e.clientY);
      const g = this.renderer.screenToGrid(cPos.x, cPos.y, this.game.grid, this.game.state.rotation);
      this.dragStartGrid = g;
      this.dragCurrentGrid = g;
    });

    window.addEventListener('pointermove', e => {
      const cPos = this.renderer.getCanvasPos(e.clientX, e.clientY);
      this.hoverTile = this.renderer.screenToGrid(cPos.x, cPos.y, this.game.grid, this.game.state.rotation);

      if (this.isMiddlePanning) {
        const dx = e.clientX - this.lastScreenPos.x;
        const dy = e.clientY - this.lastScreenPos.y;
        this.renderer.camera.x += dx;
        this.renderer.camera.y += dy;
        this.lastScreenPos = { x: e.clientX, y: e.clientY };
        return;
      }

      if (!this.isPointerDown) return;
      const dx = e.clientX - this.lastScreenPos.x;
      const dy = e.clientY - this.lastScreenPos.y;

      if (this.game.state.isPanMode || (this.game.state.currentTool === 'inspect' && Math.hypot(e.clientX - this.pointerDownScreen.x, e.clientY - this.pointerDownScreen.y) > 6)) {
        this.renderer.camera.x += dx;
        this.renderer.camera.y += dy;
        this.lastScreenPos = { x: e.clientX, y: e.clientY };
      } else {
        this.dragCurrentGrid = this.renderer.screenToGrid(cPos.x, cPos.y, this.game.grid, this.game.state.rotation);
      }
    });

    window.addEventListener('pointerup', e => {
      if (this.isMiddlePanning) {
        this.isMiddlePanning = false;
        viewport.style.cursor = this.game.state.isPanMode ? 'grab' : 'crosshair';
        return;
      }
      if (!this.isPointerDown) return;
      this.isPointerDown = false;
      const dist = Math.hypot(e.clientX - this.pointerDownScreen.x, e.clientY - this.pointerDownScreen.y);
      const cPos = this.renderer.getCanvasPos(e.clientX, e.clientY);

      if (dist < 8 && !this.game.state.isPanMode) {
        const g = this.renderer.screenToGrid(cPos.x, cPos.y, this.game.grid, this.game.state.rotation);
        this.handleTileClick(g.x, g.y);
      } else if (!this.game.state.isPanMode && this.game.state.currentTool !== 'inspect' && this.dragStartGrid && this.dragCurrentGrid) {
        const tiles = this.getDragTiles(this.dragStartGrid, this.dragCurrentGrid, this.game.state.currentTool);
        this.applyBatchBuild(tiles, this.game.state.currentTool);
      }

      this.dragStartGrid = null;
      this.dragCurrentGrid = null;
    });

    // 툴바 버튼
    document.querySelectorAll('.dock-btn[data-tool]').forEach(btn => {
      btn.addEventListener('click', () => {
        const tool = (btn as HTMLElement).dataset.tool;
        if (tool) this.selectTool(tool);
      });
    });

    // 계절 진행 버튼
    document.getElementById('btn-advance-turn')?.addEventListener('click', () => this.advanceTurn());

    // 심시티 2000 4방향 90도 회전 나침반 버튼
    document.getElementById('btn-rotate-cw')?.addEventListener('click', () => {
      this.game.state.rotation = (this.game.state.rotation + 1) % 4;
      this.updateCompassUI();
      this.audio.play('hammer');
    });

    document.getElementById('btn-rotate-ccw')?.addEventListener('click', () => {
      this.game.state.rotation = (this.game.state.rotation + 3) % 4;
      this.updateCompassUI();
      this.audio.play('hammer');
    });

    // 심시티 2000 RCI 수요 바 클릭
    document.getElementById('hud-rca-container')?.addEventListener('click', () => {
      this.modal.showDemandModal(this.game.state, () => this.openTaxModal());
    });

    // 비변사 시보(신문) 버튼
    document.getElementById('btn-newspaper')?.addEventListener('click', () => {
      if (this.latestArticle) {
        this.modal.showNewspaperModal(this.latestArticle, () => this.openTaxModal());
      }
    });

    // 탕평 조세(세율) 버튼
    document.getElementById('btn-tax-budget')?.addEventListener('click', () => {
      this.openTaxModal();
    });

    // 국책대역사 공사 발주 모달 연동 (헤더 및 독바 버튼)
    const openMegaProjects = () => {
      this.modal.showMegaProjectsModal(this.game.state, (id) => {
        const res = this.game.startMegaProject(id);
        if (res.success) {
          this.audio.play('hammer');
          this.modal.showToast(res.msg, "🏗️");
          this.modal.close();
          this.updateHUD();
        } else {
          this.audio.play('error');
          this.modal.showToast(res.msg, "❌");
        }
      });
    };

    document.getElementById('btn-mega-projects')?.addEventListener('click', openMegaProjects);
    document.getElementById('btn-dock-mega')?.addEventListener('click', openMegaProjects);

    // 1. 포호책(호환 방비 및 착호군 급파) 버튼
    document.getElementById('btn-tiger-crisis')?.addEventListener('click', () => {
      this.modal.showTigerCrisisModal(this.game.state, (choice) => {
        const res = this.game.resolveTigerCrisis(choice);
        if (res.success) {
          this.audio.play('coin');
          this.modal.showToast(res.msg, "🐅");
        } else {
          this.audio.play('error');
          this.modal.showToast(res.msg, "❌");
        }
        this.modal.close();
        this.updateHUD();
      });
    });

    // 2. 세자(순조) 책봉 및 시강원 제왕학 서연 버튼
    document.getElementById('btn-crown-prince')?.addEventListener('click', () => {
      this.modal.showCrownPrinceModal(
        this.game.state,
        (tutor) => {
          const res = this.game.investCrownPrince(tutor);
          if (res.success) {
            this.audio.play('coin');
            this.modal.showToast(res.msg, "👑");
          } else {
            this.audio.play('error');
            this.modal.showToast(res.msg, "❌");
          }
          this.modal.close();
          this.updateHUD();
        },
        () => {
          const res = this.game.studyCrownPrince();
          if (res.success) {
            this.audio.play('hammer');
            this.modal.showToast(res.msg, "📖");
          } else {
            this.audio.play('error');
            this.modal.showToast(res.msg, "❌");
          }
          this.modal.close();
          this.updateHUD();
        }
      );
    });

    // 3. 화산 현륭원 친림 참배 버튼
    document.getElementById('btn-hyoryungwon')?.addEventListener('click', () => {
      this.modal.showHyoryungwonModal(this.game.state, () => {
        const res = this.game.visitHyoryungwon();
        if (res.success) {
          this.audio.play('coin');
          this.modal.showToast(res.msg, "🌸");
        } else {
          this.modal.showToast(res.msg, "❌");
        }
        this.modal.close();
        this.updateHUD();
      });
    });

    // 4. 정조 19년 을묘년 화성 원행 & 봉수당진찬연 버튼
    document.getElementById('btn-eulmyo-wonhaeng')?.addEventListener('click', () => {
      this.modal.showEulmyoWonhaengModal(this.game.state, (_id) => {
        this.game.state.loyalty = Math.min(100, this.game.state.loyalty + 15);
        this.game.state.authority = Math.min(100, this.game.state.authority + 10);
        this.game.state.eulmyoEvent.gyeokjaengSolved++;
        this.audio.play('coin');
        this.modal.showToast("격쟁을 올린 백성의 억울한 환곡 빚을 탕감하고 방면을 명하셨습니다! (❤️+15, 👑+10)", "📜");
        this.modal.close();
        this.updateHUD();
      });
    });

    // 조정 인재 버튼
    document.getElementById('btn-open-court')?.addEventListener('click', () => {
      this.modal.showRetainersModal(this.game.state, (id, cost) => {
        const isHired = (this.game.state.retainers as any)[id];
        if (isHired) {
          (this.game.state.retainers as any)[id] = false;
          this.modal.showToast("신하를 해임하였습니다.", "📜");
        } else {
          if (this.game.state.gold < cost) {
            this.modal.showToast("국고가 부족합니다!", "❌");
            return;
          }
          this.game.state.gold -= cost;
          (this.game.state.retainers as any)[id] = true;
          this.audio.play('coin');
          this.modal.showToast("인재를 조정에 등용하였습니다!", "👑");
        }
        this.modal.close();
        this.game.updateFortressScore();
        this.game.updateDemands();
        this.updateHUD();
      });
    });

    // 줌 및 화면 원위치 버튼
    document.getElementById('btn-zoom-in')?.addEventListener('click', () => {
      this.renderer.camera.zoom = Math.min(this.renderer.camera.maxZoom, this.renderer.camera.zoom + 0.15);
    });
    document.getElementById('btn-zoom-out')?.addEventListener('click', () => {
      this.renderer.camera.zoom = Math.max(this.renderer.camera.minZoom, this.renderer.camera.zoom - 0.15);
    });
    document.getElementById('btn-center-view')?.addEventListener('click', () => this.renderer.centerCamera());

    document.getElementById('btn-pan-toggle')?.addEventListener('click', () => {
      this.game.state.isPanMode = !this.game.state.isPanMode;
      const btn = document.getElementById('btn-pan-toggle');
      if (this.game.state.isPanMode) {
        btn?.classList.add('bg-amber-600', 'text-black');
        viewport.classList.add('panning');
      } else {
        btn?.classList.remove('bg-amber-600', 'text-black');
        viewport.classList.remove('panning');
      }
    });

    document.getElementById('btn-demolish-toggle')?.addEventListener('click', () => {
      if (this.game.state.currentTool === 'demolish') {
        this.selectTool('inspect');
      } else {
        this.selectTool('demolish');
      }
    });

    document.getElementById('btn-quest-action')?.addEventListener('click', () => {
      if (this.game.currentQuestIndex < this.game.quests.length) {
        this.selectTool(this.game.quests[this.game.currentQuestIndex].tool);
      }
    });
  }

  private openTaxModal(): void {
    this.modal.showTaxModal(this.game.state, (land, market, mil) => {
      this.game.state.taxRates.landTax = land;
      this.game.state.taxRates.marketTax = market;
      this.game.state.taxRates.militaryTax = mil;
      this.game.updateDemands();
      this.updateHUD();
    });
  }

  private updateCompassUI(): void {
    const directions = ["북동 (0°)", "동남 (90°)", "남서 (180°)", "서북 (270°)"];
    const label = document.getElementById('hud-compass-label');
    if (label) {
      label.innerText = directions[this.game.state.rotation % 4];
    }
  }

  private handleTileClick(x: number, y: number): void {
    const tile = this.game.grid[y][x];

    if (this.game.state.currentTool === 'inspect') {
      this.showTileLore(tile);
      return;
    }

    if (this.game.state.currentTool === 'demolish') {
      if (tile.building || tile.zone) {
        tile.building = null;
        tile.zone = null;
        this.audio.play('demolish');
        this.game.updateFortressScore();
        this.game.updateDemands();
        this.updateHUD();
      }
      return;
    }

    if (tile.building) {
      this.audio.play('error');
      this.modal.showToast("이미 건물이 존재합니다. 철거(🚜) 후에 건설하십시오.", "⚠️");
      return;
    }

    if (this.game.state.currentTool === 'reservoir' && tile.elevation < 1.8) {
      this.audio.play('error');
      this.modal.showToast("만석거(저수지)는 고지대(능선/산자락)에 축조해야 하류 둔전으로 물을 댈 수 있습니다!", "⚠️");
      return;
    }

    const costMap: Record<string, { gold: number; rice: number }> = {
      'road': { gold: 20, rice: 0 },
      'wall': { gold: 80, rice: 25 },
      'gate': { gold: 120, rice: 40 },
      'well': { gold: 50, rice: 10 },
      'zone_res': { gold: 30, rice: 0 },
      'zone_com': { gold: 40, rice: 0 },
      'zone_agr': { gold: 20, rice: 20 },
      'levee': { gold: 60, rice: 20 },
      'reservoir': { gold: 250, rice: 100 },
      'office': { gold: 250, rice: 100 },
      'seojangdae': { gold: 200, rice: 80 },
      'bongdon': { gold: 150, rice: 50 }
    };

    const cost = costMap[this.game.state.currentTool] || { gold: 0, rice: 0 };
    if (this.game.state.gold < cost.gold || this.game.state.rice < cost.rice) {
      this.audio.play('error');
      this.modal.showToast("국고나 군량이 부족하옵니다!", "❌");
      return;
    }

    this.game.state.gold -= cost.gold;
    this.game.state.rice -= cost.rice;

    if (this.game.state.currentTool.startsWith('zone_')) {
      tile.zone = this.game.state.currentTool.replace('zone_', '') as any;
    } else {
      tile.building = this.game.state.currentTool;
      tile.zone = null;
    }

    this.audio.play('hammer');
    this.game.updateFortressScore();
    this.game.updateWaterManagement();
    this.game.updateDemands();
    this.updateHUD();
    this.checkQuest();
  }

  private applyBatchBuild(tiles: Array<{ x: number; y: number }>, tool: string): void {
    if (tool === 'inspect') return;
    let built = 0;

    tiles.forEach(pt => {
      const tile = this.game.grid[pt.y][pt.x];
      if (tool === 'demolish') {
        if (tile.building || tile.zone) {
          tile.building = null;
          tile.zone = null;
          built++;
        }
        return;
      }

      if (tile.building && tool !== 'wall') return;

      const cost = (tool === 'road') ? { gold: 20, rice: 0 } :
                   (tool === 'wall') ? { gold: 80, rice: 25 } : { gold: 30, rice: 0 };

      if (this.game.state.gold < cost.gold || this.game.state.rice < cost.rice) return;

      this.game.state.gold -= cost.gold;
      this.game.state.rice -= cost.rice;

      if (tool === 'road') {
        tile.building = 'road';
        tile.zone = null;
      } else if (tool === 'wall') {
        tile.building = 'wall';
      } else if (tool.startsWith('zone_')) {
        tile.zone = tool.replace('zone_', '') as any;
      }
      built++;
    });

    if (built > 0) {
      this.audio.play(tool === 'demolish' ? 'demolish' : 'hammer');
      this.game.updateFortressScore();
      this.game.updateDemands();
      this.updateHUD();
      this.checkQuest();
    }
  }

  private checkQuest(): void {
    if (this.game.currentQuestIndex >= this.game.quests.length) return;
    const q = this.game.quests[this.game.currentQuestIndex];
    if (q.check(this.game.grid, this.game.state)) {
      this.game.state.gold += q.reward.gold || 0;
      this.game.state.rice += q.reward.rice || 0;
      this.game.state.loyalty = Math.min(100, this.game.state.loyalty + (q.reward.loyalty || 0));
      this.audio.play('coin');
      this.modal.showToast(q.reward.msg, "👑");

      this.game.currentQuestIndex++;
      this.updateQuestUI();
      this.updateHUD();
    }
  }

  private updateQuestUI(): void {
    const banner = document.getElementById('quest-banner');
    if (!banner) return;
    if (this.game.currentQuestIndex >= this.game.quests.length) {
      banner.innerHTML = `<span class="text-amber-300 font-bold font-traditional">모든 어명 교지를 완수하셨습니다! 성역을 수호하십시오.</span>`;
      return;
    }
    const q = this.game.quests[this.game.currentQuestIndex];
    document.getElementById('quest-title')!.innerText = q.title;
    document.getElementById('quest-desc')!.innerText = q.desc;
    document.getElementById('btn-quest-action')!.innerText = q.btnText;
  }

  private advanceTurn(): void {
    const res = this.game.advanceTurn();
    this.audio.play('season');
    this.latestArticle = res.article;
    this.updateHUD();
    this.checkQuest();

    if (res.completedProject) {
      this.audio.play('coin');
      this.modal.showToast(res.completedProject, "🎉");
    }

    // 포호(호랑이 출몰) 호환 이벤트 점검
    if (this.game.state.turn % 12 === 6 && !this.game.state.tigerCrisis.solved) {
      this.game.state.tigerCrisis.active = true;
      this.audio.play('error');
      this.modal.showToast("팔달산 능선에 호환(맹호)이 발생했습니다! 상단 [포호책]에서 착호군을 급파하십시오.", "🐅");
    }

    // 1790년 원자(순조) 탄생 및 세자 책봉 권고
    if (this.game.state.year === 1790 && this.game.state.seasonIndex === 0 && !this.game.state.crownPrince.invested) {
      this.modal.showToast("원자(순조)께서 탄생하셨습니다! 상단 [세자서연]을 통해 조기 책봉과 제왕학 교육을 결단하십시오.", "👑");
    }

    if (res.historicEvent === 'wonhaeng1789') {
      this.modal.open(
        "1789년 현륭원(사도세자 묘) 원행",
        "한강 배다리(舟橋) 축조의 결단",
        `<p class="mb-2">정조 대왕께서 부친 사도세자의 묘를 수원 화산으로 이장하고 능행길에 오르십니다. 대규모 행렬이 한강을 건너기 위해 배다리를 놓아야 합니다.</p>`,
        [
          {
            text: "정약용의 주교지모(舟橋之模) 채택 (금 300, 민심 +15, 왕권 +10)",
            primary: true,
            action: () => {
              this.game.state.gold = Math.max(0, this.game.state.gold - 300);
              this.game.state.loyalty = Math.min(100, this.game.state.loyalty + 15);
              this.modal.close();
              this.modal.showToast("견고한 배다리가 놓여 백성들의 피해 없이 성역으로 진입했습니다!", "🚢");
              this.modal.showNewspaperModal(res.article, () => this.openTaxModal());
              this.updateHUD();
            }
          }
        ]
      );
    } else if (res.historicEvent === 'eulmyo1795') {
      this.modal.showEulmyoWonhaengModal(this.game.state, () => {
        this.game.state.loyalty = Math.min(100, this.game.state.loyalty + 15);
        this.game.state.authority = Math.min(100, this.game.state.authority + 10);
        this.modal.showToast("격쟁 탄원을 명쾌히 해결하고 봉수당진찬연을 성대히 거행했습니다!", "🥁");
        this.modal.close();
        this.modal.showNewspaperModal(res.article, () => this.openTaxModal());
        this.updateHUD();
      });
    } else if (this.game.state.seasonIndex === 0) {
      // 1년에 한 번 봄마다 비변사 시보 신문 자동 팝업 (심시티 2000 스타일)
      this.modal.showNewspaperModal(res.article, () => this.openTaxModal());
    } else if (res.dilemma) {
      const pool = HistoryEventManager.getDilemmaPool();
      const ev = pool[Math.floor(Math.random() * pool.length)];
      this.modal.open(ev.title, "수원유수부 비변사 감찰", `<p>${ev.desc}</p>`, ev.choices.map(c => ({
        text: c.text,
        primary: c.primary,
        action: () => {
          const msg = c.effect(this.game.state);
          this.modal.close();
          this.modal.showToast(msg, "📜");
          this.updateHUD();
        }
      })));
    }

    if (this.game.state.turn >= 96) {
      const end = HistoryEventManager.evaluateEnding(this.game.state);
      this.modal.open(`대단원: ${end.title}`, "정조 24년의 기록", `<p class="font-traditional">${end.story}</p>`, [
        { text: "다시 시작하기", primary: true, action: () => location.reload() }
      ]);
    }
  }

  private selectTool(toolName: string): void {
    this.game.state.currentTool = toolName;
    document.querySelectorAll('.dock-btn[data-tool]').forEach(btn => {
      if ((btn as HTMLElement).dataset.tool === toolName) btn.classList.add('active');
      else btn.classList.remove('active');
    });

    const iconMap: Record<string, string> = {
      'inspect': '🔍', 'road': '🛣️', 'wall': '🧱', 'gate': '⛩️', 'zone_res': '🏡',
      'zone_com': '🏪', 'zone_agr': '🌾', 'levee': '🛡️', 'reservoir': '💧',
      'office': '🏛️', 'seojangdae': '🏯', 'bongdon': '🔥', 'well': '💧', 'demolish': '🚜'
    };
    document.getElementById('tool-bar-icon')!.innerText = iconMap[toolName] || '🛠️';
    document.getElementById('tool-bar-title')!.innerText = `${toolName} 도구`;
  }

  private showTileLore(tile: any): void {
    let desc = "삼남대로와 수원천이 지나는 길목입니다.";
    if (tile.building === 'office') desc = "수원유수부 동헌: 신도시 행정 총괄 관아입니다.";
    else if (tile.building === 'seojangdae') desc = "서장대: 팔달산 정상 군사 총지휘소입니다.";
    else if (tile.building === 'wall') desc = "수원화성 성곽: 전돌과 석재를 혼합한 최첨단 방어벽입니다.";
    else if (tile.building === 'gate') desc = "수원화성 홍예성문(장안문/팔달문): 대외 교역 관세를 징수하고 치안을 철저히 통제하는 관문입니다.";
    else if (tile.building === 'hyoryungwon') desc = "화산 현륭원(顯隆園): 정조 대왕께서 사도세자를 모신 조선 최고의 명당이자 성역의 영원한 성소입니다. 친림 참배 시 온 백성이 감읍합니다.";
    else if (tile.building === 'levee') desc = "석축 제방: 수원천 범람을 영구 방어하는 청계천식 제방입니다.";
    else if (tile.building === 'reservoir') desc = "만석거: 고지대에 축조된 정조 대왕의 수리 관개 저수지입니다.";
    this.modal.open("역사 고증 도감", "수원의 터전", `<p>${desc}</p>`, [
      { text: "확인", primary: true, action: () => this.modal.close() }
    ]);
  }

  private updateHUD(): void {
    const s = this.game.state;
    document.getElementById('txt-turn-label')!.innerText = `정조 ${s.year - 1776 + 1}년(${s.year}) ${s.seasons[s.seasonIndex]} [${s.turn}/96턴]`;
    document.getElementById('hud-gold')!.innerText = s.gold.toLocaleString();
    document.getElementById('hud-rice')!.innerText = s.rice.toLocaleString();
    document.getElementById('hud-pop')!.innerText = s.pop.toLocaleString();
    document.getElementById('hud-loyalty')!.innerText = `${s.loyalty}%`;
    document.getElementById('hud-authority')!.innerText = s.authority.toString();
    document.getElementById('hud-fortress')!.innerText = `${s.fortressProgress}%`;

    const floodElem = document.getElementById('hud-flood');
    if (floodElem) floodElem.innerText = `${s.floodDefense}%`;

    // 심시티 2000 R-C-A 3색 수요 바 업데이트 (-100 ~ 100 -> 0% ~ 100%)
    const rPct = Math.max(10, Math.min(100, Math.round((s.demandRes + 100) / 2)));
    const cPct = Math.max(10, Math.min(100, Math.round((s.demandCom + 100) / 2)));
    const aPct = Math.max(10, Math.min(100, Math.round((s.demandAgr + 100) / 2)));

    const bRes = document.getElementById('bar-demand-res');
    const bCom = document.getElementById('bar-demand-com');
    const bAgr = document.getElementById('bar-demand-agr');
    if (bRes) bRes.style.height = `${rPct}%`;
    if (bCom) bCom.style.height = `${cPct}%`;
    if (bAgr) bAgr.style.height = `${aPct}%`;
  }

  private getDragTiles(p1: { x: number; y: number }, p2: { x: number; y: number }, tool: string): Array<{ x: number; y: number }> {
    const tiles: Array<{ x: number; y: number }> = [];
    if (tool.startsWith('zone_') || tool === 'demolish') {
      const minX = Math.min(p1.x, p2.x), maxX = Math.max(p1.x, p2.x);
      const minY = Math.min(p1.y, p2.y), maxY = Math.max(p1.y, p2.y);
      for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) tiles.push({ x, y });
      }
    } else {
      let x0 = p1.x, y0 = p1.y, x1 = p2.x, y1 = p2.y;
      let dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0);
      let sx = (x0 < x1) ? 1 : -1, sy = (y0 < y1) ? 1 : -1;
      let err = dx - dy;
      while (true) {
        tiles.push({ x: x0, y: y0 });
        if (x0 === x1 && y0 === y1) break;
        let e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 < dx) { err += dx; y0 += sy; }
      }
    }
    return tiles;
  }
}

window.addEventListener('DOMContentLoaded', () => {
  new HwaseongApp();
});
