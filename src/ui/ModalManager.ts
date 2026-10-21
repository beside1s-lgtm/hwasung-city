import { GameState, NewspaperArticle } from '../types';
import { RETAINER_LIST, RetainerInfo } from '../domain/RetainerManager';

export class ModalManager {
  private container: HTMLElement;
  private titleElem: HTMLElement;
  private subtitleElem: HTMLElement;
  private bodyElem: HTMLElement;
  private footerElem: HTMLElement;
  private toastElem: HTMLElement;
  private toastMsgElem: HTMLElement;
  private toastIconElem: HTMLElement;

  constructor() {
    this.container = document.getElementById('modal-container')!;
    this.titleElem = document.getElementById('modal-title')!;
    this.subtitleElem = document.getElementById('modal-subtitle')!;
    this.bodyElem = document.getElementById('modal-body')!;
    this.footerElem = document.getElementById('modal-footer')!;
    this.toastElem = document.getElementById('toast-banner')!;
    this.toastMsgElem = document.getElementById('toast-msg')!;
    this.toastIconElem = document.getElementById('toast-icon')!;

    document.getElementById('modal-close-x')?.addEventListener('click', () => this.close());
  }

  public showToast(msg: string, icon = '📢'): void {
    if (!this.toastElem) return;
    this.toastIconElem.innerText = icon;
    this.toastMsgElem.innerText = msg;
    this.toastElem.classList.remove('opacity-0', '-translate-y-8');
    this.toastElem.classList.add('opacity-100', 'translate-y-0');
    setTimeout(() => {
      this.toastElem.classList.remove('opacity-100', 'translate-y-0');
      this.toastElem.classList.add('opacity-0', '-translate-y-8');
    }, 2600);
  }

  public open(title: string, subtitle: string, bodyHtml: string, buttons: Array<{ text: string; primary?: boolean; action: () => void }>): void {
    this.titleElem.innerText = title;
    this.subtitleElem.innerText = subtitle;
    this.bodyElem.innerHTML = bodyHtml;
    this.footerElem.innerHTML = '';

    buttons.forEach(btn => {
      const b = document.createElement('button');
      b.className = btn.primary ?
        "w-full py-2.5 bg-[#7c2217] hover:bg-[#991b1b] text-[#fef08a] font-bold rounded-lg border border-[#f59e0b] shadow-md transition active:scale-95 text-xs sm:text-sm" :
        "w-full py-2 bg-stone-300 hover:bg-stone-400 text-stone-900 font-bold rounded-lg border border-stone-400 transition active:scale-95 text-xs sm:text-sm";
      b.innerText = btn.text;
      b.addEventListener('click', btn.action);
      this.footerElem.appendChild(b);
    });

    this.container.classList.remove('hidden');
    this.container.classList.add('flex');
  }

  public close(): void {
    this.container.classList.add('hidden');
    this.container.classList.remove('flex');
  }

  // 심시티 2000 비변사 시보 (Newspaper) 모달
  public showNewspaperModal(article: NewspaperArticle, onOpenTax: () => void): void {
    const html = `
      <div class="bg-[#fcf8ee] border-2 border-stone-800 p-4 text-stone-900 font-serif shadow-inner">
        <div class="border-b-4 border-double border-stone-900 pb-2 mb-3 text-center">
          <div class="text-[10px] tracking-widest text-stone-600 uppercase font-sans font-bold">The Hwaseong Chronicle &middot; 비변사 관보</div>
          <h1 class="text-2xl sm:text-3xl font-black font-traditional tracking-tight mt-1">備邊司時報 (화성순보)</h1>
          <div class="flex justify-between items-center text-[11px] font-sans font-semibold border-t border-b border-stone-400 py-1 mt-1.5 px-1">
            <span>${article.dateStr}</span>
            <span>제 ${Math.floor(Math.random() * 80 + 120)}호</span>
            <span>판가: 상평통보 1문</span>
          </div>
        </div>

        <div class="mb-3">
          <h2 class="text-base sm:text-lg font-black font-traditional leading-snug text-stone-950">${article.headline}</h2>
          <p class="text-xs font-semibold text-stone-700 mt-1 italic">${article.subhead}</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs leading-relaxed border-t border-stone-300 pt-2">
          <div class="md:col-span-2 text-stone-800 space-y-2">
            <p>${article.body}</p>
            <div class="bg-stone-200/80 p-2 rounded border border-stone-300 text-[11px] text-stone-700 italic">
              "수원화성은 왕권 강화와 민생 안정을 동시에 달성하는 개혁의 교두보이자 자주국방의 요람이다."
            </div>
          </div>
          <div class="bg-stone-100 p-2.5 rounded border border-stone-400/80 text-[11px] space-y-1.5">
            <div class="font-bold border-b border-stone-400 pb-1 text-stone-900">시보 사설(社說)</div>
            <p class="text-stone-700 leading-snug">${article.editorial}</p>
          </div>
        </div>
      </div>
    `;

    this.open("비변사 시보 (備邊司時報)", article.dateStr, html, [
      { text: "조세 및 시전 대책 열기 (세율 조정)", primary: true, action: () => { this.close(); onOpenTax(); } },
      { text: "시보 접기", primary: false, action: () => this.close() }
    ]);
  }

  // 심시티 2000 스타일 조세 및 예산 패널 (탕평 재정)
  public showTaxModal(state: GameState, onSave: (landTax: number, marketTax: number, militaryTax: number) => void): void {
    let curLand = state.taxRates.landTax;
    let curMarket = state.taxRates.marketTax;
    let curMilitary = state.taxRates.militaryTax;

    const renderSliders = () => `
      <div class="space-y-4 text-xs font-sans">
        <div class="bg-stone-200/70 p-3 rounded-lg border border-stone-300">
          <div class="flex justify-between items-center font-bold mb-1">
            <span class="text-amber-900">🌾 전세(田稅 - 농지 지세)</span>
            <span class="text-sm font-black text-stone-900" id="val-tax-land">${curLand}%</span>
          </div>
          <input type="range" min="0" max="20" value="${curLand}" id="slider-tax-land" class="w-full accent-amber-800 cursor-pointer">
          <div class="text-[10px] text-stone-600 mt-1">대유둔전 벼 수확 시 국고로 환산되는 세율 (낮을수록 농업 수요 증가)</div>
        </div>

        <div class="bg-stone-200/70 p-3 rounded-lg border border-stone-300">
          <div class="flex justify-between items-center font-bold mb-1">
            <span class="text-sky-900">🏪 시전세(市廛稅 - 상업세)</span>
            <span class="text-sm font-black text-stone-900" id="val-tax-market">${curMarket}%</span>
          </div>
          <input type="range" min="0" max="20" value="${curMarket}" id="slider-tax-market" class="w-full accent-sky-800 cursor-pointer">
          <div class="text-[10px] text-stone-600 mt-1">삼남대로 저잣거리 거래세 (낮을수록 보부상 및 상업 수요 증가)</div>
        </div>

        <div class="bg-stone-200/70 p-3 rounded-lg border border-stone-300">
          <div class="flex justify-between items-center font-bold mb-1">
            <span class="text-rose-900">🛡️ 결포·호포세(軍布稅 - 군정세)</span>
            <span class="text-sm font-black text-stone-900" id="val-tax-military">${curMilitary}%</span>
          </div>
          <input type="range" min="0" max="20" value="${curMilitary}" id="slider-tax-military" class="w-full accent-rose-800 cursor-pointer">
          <div class="text-[10px] text-stone-600 mt-1">장용영 유지 및 국방 호포세 (10% 초과 시 백성 충성도 하락)</div>
        </div>

        <div class="p-2.5 bg-amber-50 rounded border border-amber-300 text-[11px] text-amber-950 font-semibold" id="tax-impact-preview">
          평균 세율: 7% &middot; 민심 영향: 안정적
        </div>
      </div>
    `;

    this.open("호조(戶曹) 조세 및 재정 조율", "심시티 2000 스타일 탕평 세무 행정", renderSliders(), [
      {
        text: "세율 윤허 및 반포",
        primary: true,
        action: () => {
          onSave(curLand, curMarket, curMilitary);
          this.close();
          this.showToast("조세율이 개정되어 관보에 고시되었습니다.", "📜");
        }
      },
      { text: "취소", primary: false, action: () => this.close() }
    ]);

    const updatePreview = () => {
      const avg = (curLand + curMarket + curMilitary) / 3;
      const preview = document.getElementById('tax-impact-preview');
      if (preview) {
        if (avg > 10) {
          preview.innerHTML = `평균 세율: ${avg.toFixed(1)}% &middot; <span class="text-red-700 font-bold">과중한 세금으로 민심이 매 계절 하락합니다!</span>`;
        } else if (avg < 7) {
          preview.innerHTML = `평균 세율: ${avg.toFixed(1)}% &middot; <span class="text-emerald-700 font-bold">감세 정책으로 백성 충성도와 이주 수요가 급증합니다!</span>`;
        } else {
          preview.innerHTML = `평균 세율: ${avg.toFixed(1)}% &middot; <span class="text-stone-700 font-bold">적정 탕평 세율 유지 (민심 안정)</span>`;
        }
      }
    };

    const sLand = document.getElementById('slider-tax-land') as HTMLInputElement;
    const sMarket = document.getElementById('slider-tax-market') as HTMLInputElement;
    const sMil = document.getElementById('slider-tax-military') as HTMLInputElement;

    sLand?.addEventListener('input', e => {
      curLand = parseInt((e.target as HTMLInputElement).value, 10);
      document.getElementById('val-tax-land')!.innerText = `${curLand}%`;
      updatePreview();
    });
    sMarket?.addEventListener('input', e => {
      curMarket = parseInt((e.target as HTMLInputElement).value, 10);
      document.getElementById('val-tax-market')!.innerText = `${curMarket}%`;
      updatePreview();
    });
    sMil?.addEventListener('input', e => {
      curMilitary = parseInt((e.target as HTMLInputElement).value, 10);
      document.getElementById('val-tax-military')!.innerText = `${curMilitary}%`;
      updatePreview();
    });
  }

  // RCI 수요 분석 모달
  public showDemandModal(state: GameState, onOpenTax: () => void): void {
    const html = `
      <div class="space-y-3 text-xs">
        <p class="text-stone-700 leading-relaxed">
          심시티 2000의 핵심인 <strong class="text-stone-900">R-C-I 수요 지수</strong>는 수원화성 신도시의 주거(방·리), 상업(저잣거리), 농업(대유둔전) 구획의 자율 발달을 견인합니다.
        </p>

        <div class="p-3 bg-stone-100 rounded-lg border border-stone-300 space-y-2.5">
          <div>
            <div class="flex justify-between font-bold text-emerald-800">
              <span>🏡 방·리 (주거 수요, R)</span>
              <span>${state.demandRes > 0 ? `+${state.demandRes}` : state.demandRes}</span>
            </div>
            <div class="w-full bg-stone-300 h-2 rounded overflow-hidden mt-1">
              <div class="bg-emerald-600 h-full" style="width: ${Math.max(0, (state.demandRes + 100) / 2)}%"></div>
            </div>
            <div class="text-[10px] text-stone-600 mt-0.5">상업/농업 일자리 확충 및 성곽 안전도에 비례하여 유민이 유입됩니다.</div>
          </div>

          <div>
            <div class="flex justify-between font-bold text-sky-800">
              <span>🏪 저잣거리 (상업 수요, C)</span>
              <span>${state.demandCom > 0 ? `+${state.demandCom}` : state.demandCom}</span>
            </div>
            <div class="w-full bg-stone-300 h-2 rounded overflow-hidden mt-1">
              <div class="bg-sky-600 h-full" style="width: ${Math.max(0, (state.demandCom + 100) / 2)}%"></div>
            </div>
            <div class="text-[10px] text-stone-600 mt-0.5">인구 수와 삼남대로 연결망, 박제가 등용 및 감세 정책에 영향을 받습니다.</div>
          </div>

          <div>
            <div class="flex justify-between font-bold text-amber-800">
              <span>🌾 대유둔전 (농업 수요, A/I)</span>
              <span>${state.demandAgr > 0 ? `+${state.demandAgr}` : state.demandAgr}</span>
            </div>
            <div class="w-full bg-stone-300 h-2 rounded overflow-hidden mt-1">
              <div class="bg-amber-600 h-full" style="width: ${Math.max(0, (state.demandAgr + 100) / 2)}%"></div>
            </div>
            <div class="text-[10px] text-stone-600 mt-0.5">식량 소비량 대비 비축량이 부족할수록 농업 개간 수요가 급증합니다.</div>
          </div>
        </div>
      </div>
    `;

    this.open("수원 신도시 R-C-A 구획 수요 분석", "유수부 도지 계획국 평가", html, [
      { text: "세율 조정하기", primary: true, action: () => { this.close(); onOpenTax(); } },
      { text: "확인", primary: false, action: () => this.close() }
    ]);
  }

  public showRetainersModal(state: GameState, onToggle: (id: string, cost: number) => void): void {
    let cardsHtml = `<div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">`;
    RETAINER_LIST.forEach((r: RetainerInfo) => {
      const isHired = (state.retainers as any)[r.id];
      cardsHtml += `
        <div class="p-2.5 rounded-lg border ${isHired ? 'bg-amber-100 border-amber-600' : 'bg-stone-100 border-stone-300'} flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between font-bold text-stone-900">
              <span>${r.icon} ${r.name}</span>
              <span class="text-[10px] px-1.5 py-0.5 rounded ${isHired ? 'bg-emerald-700 text-white' : 'bg-stone-400 text-stone-100'}">${isHired ? '등용 중' : '미등용'}</span>
            </div>
            <div class="text-[10px] text-amber-900 font-semibold mb-1">${r.role}</div>
            <div class="text-[11px] text-stone-700 leading-tight">${r.desc}</div>
          </div>
          <button class="mt-2 py-1 px-2 rounded text-[11px] font-bold ${isHired ? 'bg-rose-800 text-white' : 'bg-amber-800 text-amber-100'}" id="btn-ret-${r.id}">
            ${isHired ? '해임(숙청)' : `등용 (🪙${r.cost})`}
          </button>
        </div>
      `;
    });
    cardsHtml += `</div>`;

    this.open("규장각 및 조정 인사", "탕평책 기반 인재 기용 및 관리", cardsHtml, [
      { text: "닫기", primary: true, action: () => this.close() }
    ]);

    RETAINER_LIST.forEach((r: RetainerInfo) => {
      document.getElementById(`btn-ret-${r.id}`)?.addEventListener('click', () => {
        onToggle(r.id, r.cost);
      });
    });
  }

  // 국책 대역사 공사 발주 모달
  public showMegaProjectsModal(state: GameState, onStartProject: (id: string) => void): void {
    const hasJeong = state.retainers.jeong;
    const hasChae = state.retainers.chae;

    let buffHtml = `<div class="p-2.5 bg-stone-200/80 rounded border border-stone-300 text-[11px] space-y-1 mb-3">`;
    buffHtml += `<div class="font-bold text-stone-900">👑 조정 인재의 국책사업 시너지</div>`;
    buffHtml += `<div>정약용(거중기): <span class="${hasJeong ? 'text-emerald-700 font-bold' : 'text-stone-500'}">${hasJeong ? '등용됨 (공기 35% 단축 활성)' : '미등용 (기본 공기)'}</span></div>`;
    buffHtml += `<div>채제공(총리대신): <span class="${hasChae ? 'text-emerald-700 font-bold' : 'text-stone-500'}">${hasChae ? '등용됨 (공사비 25% 절감 활성)' : '미등용 (기본 예산)'}</span></div>`;
    buffHtml += `</div>`;

    let cardsHtml = buffHtml + `<div class="space-y-3 text-xs">`;

    state.megaProjects.forEach(p => {
      const turnDiscount = hasJeong ? 0.65 : 1.0;
      const costDiscount = hasChae ? 0.75 : 1.0;
      const expectedTurns = Math.max(3, Math.round(p.baseTurns * turnDiscount));
      const expectedGold = Math.round(p.costPerTurn.gold * costDiscount);
      const expectedRice = Math.round(p.costPerTurn.rice * costDiscount);

      const statusBadge = p.isCompleted ? `<span class="bg-emerald-800 text-emerald-100 text-[10px] px-2 py-0.5 rounded font-bold">완공 완료</span>` :
                          p.isStarted ? `<span class="bg-amber-800 text-amber-100 text-[10px] px-2 py-0.5 rounded font-bold">공사 중 (${p.progressTurns}/${p.totalTurns}턴)</span>` :
                                        `<span class="bg-stone-500 text-white text-[10px] px-2 py-0.5 rounded font-bold">미착공</span>`;

      cardsHtml += `
        <div class="p-3 rounded-lg border ${p.isCompleted ? 'bg-emerald-50 border-emerald-300' : p.isStarted ? 'bg-amber-50 border-amber-300' : 'bg-stone-100 border-stone-300'} flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between font-bold text-stone-900">
              <span class="text-sm font-traditional font-black">${p.name}</span>
              ${statusBadge}
            </div>
            <p class="text-stone-700 text-[11px] my-1.5 leading-snug">${p.desc}</p>
            
            <div class="grid grid-cols-2 gap-2 text-[10px] bg-white/70 p-2 rounded border border-stone-200 my-1.5">
              <div><strong>소요 공기:</strong> ${p.isStarted ? `${p.totalTurns}턴` : `${expectedTurns}턴 ${hasJeong ? '(정약용 35% 단축)' : ''}`}</div>
              <div><strong>턴당 소요:</strong> 🪙${expectedGold} / 🌾${expectedRice} ${hasChae ? '(채제공 25% 절감)' : ''}</div>
            </div>

            ${p.isStarted ? `
              <div class="w-full bg-stone-300 h-2 rounded overflow-hidden mt-1.5">
                <div class="bg-amber-600 h-full" style="width: ${(p.progressTurns / p.totalTurns) * 100}%"></div>
              </div>
            ` : ''}
          </div>

          <div class="mt-2.5 flex justify-end">
            ${(!p.isStarted && !p.isCompleted) ? `
              <button class="py-1.5 px-3 rounded font-bold text-white bg-amber-800 hover:bg-amber-900 transition active:scale-95 text-xs" id="btn-project-${p.id}">
                어명 재가 및 착공 (첫 턴 🪙${expectedGold})
              </button>
            ` : p.isCompleted ? `
              <span class="text-emerald-800 font-bold text-[11px]">축조 완료 &middot; 효능 영구 발휘 중</span>
            ` : `
              <span class="text-amber-800 font-bold text-[11px]">현장 비계 및 거중기 가동 중</span>
            `}
          </div>
        </div>
      `;
    });

    cardsHtml += `</div>`;

    this.open("비변사 국책 대역사(國策大役事) 청원", "수원화성 국가 인프라 중장기 공사 계획", cardsHtml, [
      { text: "닫기", primary: true, action: () => this.close() }
    ]);

    state.megaProjects.forEach(p => {
      if (!p.isStarted && !p.isCompleted) {
        document.getElementById(`btn-project-${p.id}`)?.addEventListener('click', () => {
          onStartProject(p.id);
        });
      }
    });
  }

  // 1. 정조 포호(捕虎) 정책 모달
  public showTigerCrisisModal(state: GameState, onResolve: (choice: 'army' | 'clear' | 'bounty') => void): void {
    const html = `
      <div class="space-y-3 text-xs">
        <div class="p-3 bg-amber-100/90 rounded-lg border-2 border-amber-600 text-stone-900 leading-relaxed">
          <strong class="text-sm font-traditional font-black text-rose-900">🚨 팔달산·광교산 호환(虎患) 비상사태</strong>
          <p class="mt-1">
            "산림이 울창한 팔달산 능선에서 사람을 해치는 대호(大虎)가 출몰하여 삼남대로를 지나는 길손과 백성들이 공포에 떨고 있사옵니다!
            선왕 영조 대왕과 과인의 포호(捕虎) 국책에 따라 즉각 결단을 내려야 하옵니다."
          </p>
        </div>

        <div class="space-y-2">
          <div class="p-2.5 rounded-lg border border-stone-300 bg-stone-50 flex items-center justify-between">
            <div>
              <div class="font-bold text-stone-900">1. 장용영 착호군(捉虎軍) 정예 포수 급파</div>
              <div class="text-[11px] text-stone-600">군사력 60 &middot; 군량 100석 소모 &rarr; 맹호 사냥 성공 시 호피 진상 (🪙+500, 👑+15, ❤️+20)</div>
            </div>
            <button class="py-1.5 px-3 rounded font-bold text-white bg-red-800 hover:bg-red-900 text-xs active:scale-95" id="btn-tiger-army">
              착호군 급파
            </button>
          </div>

          <div class="p-2.5 rounded-lg border border-stone-300 bg-stone-50 flex items-center justify-between">
            <div>
              <div class="font-bold text-stone-900">2. 산지 방화 개간 및 서식지 소탕</div>
              <div class="text-[11px] text-stone-600">국고 180냥 투입 &rarr; 서식지 영구 벌채 및 농지 개간 (🌾+200, ❤️+8)</div>
            </div>
            <button class="py-1.5 px-3 rounded font-bold text-white bg-amber-800 hover:bg-amber-900 text-xs active:scale-95" id="btn-tiger-clear">
              산지 개간
            </button>
          </div>

          <div class="p-2.5 rounded-lg border border-stone-300 bg-stone-50 flex items-center justify-between">
            <div>
              <div class="font-bold text-stone-900">3. 민간 명포수 현상금 포고</div>
              <div class="text-[11px] text-stone-600">국고 80냥 투입 &rarr; 관망 (확률 성공, 실패 시 백성 희생)</div>
            </div>
            <button class="py-1.5 px-3 rounded font-bold text-stone-800 bg-stone-300 hover:bg-stone-400 text-xs active:scale-95" id="btn-tiger-bounty">
              현상금 방
            </button>
          </div>
        </div>
      </div>
    `;

    this.open("정조 포호책(捕虎策) 어명", "수원유수부 호환 방비 결단", html, [
      { text: "닫기", primary: false, action: () => this.close() }
    ]);

    document.getElementById('btn-tiger-army')?.addEventListener('click', () => { onResolve('army'); });
    document.getElementById('btn-tiger-clear')?.addEventListener('click', () => { onResolve('clear'); });
    document.getElementById('btn-tiger-bounty')?.addEventListener('click', () => { onResolve('bounty'); });
  }

  // 2. 세자(순조) 책봉 및 시강원 제왕학 서연 모달
  public showCrownPrinceModal(
    state: GameState,
    onInvest: (tutor: 'jeong' | 'chae' | 'classic') => void,
    onStudy: () => void
  ): void {
    const cp = state.crownPrince;
    const isInvested = cp.invested;

    let bodyHtml = `<div class="space-y-3 text-xs">`;

    if (!isInvested) {
      bodyHtml += `
        <div class="p-3 bg-amber-50 rounded-lg border border-amber-300 leading-relaxed text-stone-800">
          <p class="font-bold text-sm text-amber-900 font-traditional">📜 원자(순조 이공) 탄생과 조기 세자 책봉의 결단</p>
          <p class="mt-1 text-[11px]">
            "과인의 건강이 쇠약해질 때를 대비하여 원자를 조기에 세자로 책봉하고, 시강원(侍講院)을 두어 철저한 제왕학 교육을 시켜야만 세도정치의 발호를 막고 사직을 보전할 수 있소.
            다만 조기 책봉은 노론 벽파의 거센 견제와 정치적 파장을 불러올 수 있소."
          </p>
        </div>

        <div class="p-2.5 bg-stone-100 rounded border border-stone-300">
          <div class="font-bold text-stone-900 mb-2">시강원(侍講院) 사부(스승) 선택 및 책봉 (🪙300 소요):</div>
          <div class="space-y-1.5">
            <button class="w-full text-left p-2 rounded bg-white hover:bg-amber-100 border border-stone-300 font-bold flex justify-between items-center text-xs" id="btn-invest-jeong">
              <span>📚 다산 정약용 (실학과 경세유표 전수)</span>
              <span class="text-[10px] text-emerald-700">개혁 군주 양성</span>
            </button>
            <button class="w-full text-left p-2 rounded bg-white hover:bg-amber-100 border border-stone-300 font-bold flex justify-between items-center text-xs" id="btn-invest-chae">
              <span>⚖️ 번암 채제공 (재정 치국과 탕평책 전수)</span>
              <span class="text-[10px] text-sky-700">안정적 국정 계승</span>
            </button>
            <button class="w-full text-left p-2 rounded bg-white hover:bg-amber-100 border border-stone-300 font-bold flex justify-between items-center text-xs" id="btn-invest-classic">
              <span>📜 성균관 대제학 (정통 유학 및 성리학)</span>
              <span class="text-[10px] text-amber-700">벽파 마찰 최소화</span>
            </button>
          </div>
        </div>
      `;
    } else {
      const tutorName = cp.tutor === 'jeong' ? '다산 정약용' : cp.tutor === 'chae' ? '번암 채제공' : '성균관 대제학';
      bodyHtml += `
        <div class="p-3 bg-emerald-50 rounded-lg border border-emerald-300 leading-relaxed text-stone-800">
          <div class="flex justify-between items-center font-bold text-emerald-950 font-traditional text-sm">
            <span>👑 세자(순조) 시강원 서연(書筵) 현황</span>
            <span class="text-xs bg-emerald-700 text-white px-2 py-0.5 rounded">제왕학 진척도: ${cp.educationLevel}%</span>
          </div>
          <p class="mt-1 text-[11px] text-stone-700">
            담당 사부: <strong>${tutorName}</strong> &middot; 서연을 통해 성군의 자질이 완벽히 갖춰지면, 정조 사후 어린 나이에도 노론 세도정치를 제압하고 자주강국을 계승합니다.
          </p>

          <div class="w-full bg-stone-300 h-3 rounded-full overflow-hidden mt-2 border border-stone-400">
            <div class="bg-gradient-to-r from-emerald-600 to-amber-500 h-full transition-all" style="width: ${cp.educationLevel}%"></div>
          </div>
        </div>

        <div class="flex justify-between items-center p-2.5 bg-stone-100 rounded border border-stone-300">
          <div class="text-[11px] text-stone-700">
            <strong>1회 서연 강론 진행:</strong> 국고 100냥 / 군량 40석 소모 (진척도 +20%, 왕권 +5)
          </div>
          <button class="py-2 px-3.5 rounded font-bold text-white bg-emerald-800 hover:bg-emerald-900 transition active:scale-95 text-xs ${cp.educationLevel >= 100 ? 'opacity-50 cursor-not-allowed' : ''}" id="btn-study-cp">
            ${cp.educationLevel >= 100 ? '제왕학 완수' : '서연 강론 열기'}
          </button>
        </div>
      `;
    }

    bodyHtml += `</div>`;

    this.open("원자(순조) 세자 책봉 및 시강원 서연", "조선 왕조 100년 대계를 위한 제왕학 교육", bodyHtml, [
      { text: "닫기", primary: true, action: () => this.close() }
    ]);

    if (!isInvested) {
      document.getElementById('btn-invest-jeong')?.addEventListener('click', () => onInvest('jeong'));
      document.getElementById('btn-invest-chae')?.addEventListener('click', () => onInvest('chae'));
      document.getElementById('btn-invest-classic')?.addEventListener('click', () => onInvest('classic'));
    } else {
      document.getElementById('btn-study-cp')?.addEventListener('click', () => onStudy());
    }
  }

  // 3. 화산 현륭원(顯隆園) 사도세자 묘역 친림 참배 모달
  public showHyoryungwonModal(state: GameState, onVisit: () => void): void {
    const isVisited = state.hyoryungwon.visited;
    const html = `
      <div class="space-y-3 text-xs leading-relaxed text-stone-800">
        <div class="p-3 bg-rose-50 rounded-lg border border-rose-300">
          <p class="font-bold text-sm text-rose-950 font-traditional">🌸 화산(花山) 현륭원(顯隆園) 사도세자 원침</p>
          <p class="mt-1 text-[11px] text-stone-700">
            "정조 대왕께서 뒤주에서 비극적으로 승하하신 부친 사도세자의 묘를 한양 배봉산에서 조선 최고의 명당인 수원 화산으로 천봉하고 현륭원이라 이름 지으셨습니다.
            수원화성 축조의 근본 원동력이자 성역의 뿌리인 이곳을 왕이 친림하여 참배하면 효심에 감동한 온 백성이 왕실을 수호합니다."
          </p>
        </div>

        <div class="p-2.5 bg-stone-100 rounded border border-stone-300 text-[11px] space-y-1">
          <div><strong>현재 참배 상태:</strong> ${isVisited ? '<span class="text-emerald-700 font-bold">금년도 친림 참배 완료 (효심 가호 활성화 중)</span>' : '<span class="text-amber-800 font-bold">미참배 (친림 준비 완료)</span>'}</div>
          <div><strong>참배 효능:</strong> 백성 충성도 ❤️+20%, 왕권 👑+15%, 4턴간 금 세수 보너스</div>
        </div>

        <div class="flex justify-end">
          <button class="py-2 px-4 rounded font-bold text-white bg-rose-900 hover:bg-rose-950 transition active:scale-95 text-xs ${isVisited ? 'opacity-50 cursor-not-allowed' : ''}" id="btn-visit-hyo">
            ${isVisited ? '참배 완료' : '정조 대왕 현륭원 친림 참배'}
          </button>
        </div>
      </div>
    `;

    this.open("화산 현륭원(顯隆園) 친림 참배", "정조 대왕의 지극한 효심과 성역의 성소", html, [
      { text: "닫기", primary: true, action: () => this.close() }
    ]);

    if (!isVisited) {
      document.getElementById('btn-visit-hyo')?.addEventListener('click', () => onVisit());
    }
  }

  // 4. 정조 19년(1795) 을묘년 화성 원행 및 혜경궁 홍씨 봉수당진찬연 궁중 정재 춤 모달
  public showEulmyoWonhaengModal(state: GameState, onSolveGyeokjaeng: (id: number) => void): void {
    const html = `
      <div class="space-y-3 text-xs leading-relaxed text-stone-800">
        <div class="p-3 bg-amber-50 rounded-lg border-2 border-amber-500">
          <p class="font-bold text-sm text-amber-950 font-traditional">🥁 정조 19년(1795) 을묘년 화성 원행 &middot; 봉수당진찬연(奉壽堂進饌宴)</p>
          <p class="mt-1 text-[11px] text-stone-700">
            노량진 주교(배다리)를 건너 8일간 이어진 사상 최대의 왕실 행차!
            백성들의 억울함을 꽹과리로 직접 듣는 <strong class="text-amber-900">격쟁(擊錚)</strong>과 모친 혜경궁 홍씨의 회갑을 축하하는 <strong class="text-rose-900">봉수당진찬연 궁중 정재 춤</strong>이 거행됩니다.
          </p>
        </div>

        <!-- 혜경궁 홍씨 앞 궁중 정재(무고 舞鼓) 춤 캔버스 영상/애니메이션 뷰 -->
        <div class="relative bg-[#1c140d] rounded-lg border-2 border-amber-600 p-2 overflow-hidden flex flex-col items-center">
          <div class="text-[11px] text-amber-300 font-bold mb-1">🎭 봉수당진찬연 궁중 정재 &middot; 무고(舞鼓) 춤사위 재현</div>
          <canvas id="banquetDanceCanvas" width="440" height="180" class="rounded bg-[#2a1b10] border border-amber-900/60 shadow-inner"></canvas>
          <div class="text-[10px] text-amber-200/80 mt-1">여민락(與民樂) 선율에 맞춰 4인의 무희가 북을 에워싸고 꽃신 춤사위를 펼칩니다.</div>
        </div>

        <!-- 백성 격쟁/상언 탄원 직접 판결 -->
        <div class="p-2.5 bg-stone-100 rounded border border-stone-300 space-y-1.5">
          <div class="font-bold text-stone-900">📜 길가에서 꽹과리를 친 백성의 격쟁(擊錚) 탄원:</div>
          <p class="text-[11px] text-stone-700 italic">"소인의 늙은 아비가 환곡(곡식 대여) 이자에 짓눌려 옥에 갇혔사옵니다. 부디 억울함을 굽어살펴 주옵소서!"</p>
          <div class="flex gap-2 justify-end pt-1">
            <button class="py-1 px-2.5 rounded font-bold text-white bg-emerald-800 hover:bg-emerald-900 text-xs active:scale-95" id="btn-gyeokjaeng-accept">
              환곡 폐단 탕감 및 석방 (민심 +15, 왕권 +10)
            </button>
          </div>
        </div>
      </div>
    `;

    this.open("을묘년 화성 원행 &middot; 봉수당진찬연", "어머니를 위한 효심과 백성과 함께한 축제", html, [
      { text: "어명 하사 및 닫기", primary: true, action: () => this.close() }
    ]);

    document.getElementById('btn-gyeokjaeng-accept')?.addEventListener('click', () => {
      onSolveGyeokjaeng(1);
    });

    // 혜경궁 홍씨 앞 궁중 정재 춤(무고 舞鼓) 캔버스 애니메이션 구동
    const cvs = document.getElementById('banquetDanceCanvas') as HTMLCanvasElement;
    if (cvs) {
      const ctx = cvs.getContext('2d');
      if (ctx) {
        let t = 0;
        let animId: number;

        const renderDance = () => {
          t += 0.05;
          ctx.clearRect(0, 0, cvs.width, cvs.height);

          // 화성행궁 봉수당 궁중 멍석 바닥 (붉은 융단)
          ctx.fillStyle = '#7f1d1d';
          ctx.fillRect(20, 20, cvs.width - 40, cvs.height - 40);
          ctx.strokeStyle = '#f59e0b';
          ctx.lineWidth = 2;
          ctx.strokeRect(20, 20, cvs.width - 40, cvs.height - 40);

          // 상단 혜경궁 홍씨와 정조의 옥좌 휘장
          ctx.fillStyle = '#b45309';
          ctx.fillRect(cvs.width / 2 - 40, 24, 80, 16);
          ctx.fillStyle = '#fef08a';
          ctx.font = 'bold 9px sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText("혜경궁 홍씨 회갑 연석", cvs.width / 2, 35);

          // 중앙 대북(무고 舞鼓)
          const centerX = cvs.width / 2;
          const centerY = cvs.height / 2 + 10;
          ctx.fillStyle = '#451a03';
          ctx.beginPath();
          ctx.ellipse(centerX, centerY, 22, 14, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = '#ca8a04';
          ctx.lineWidth = 3;
          ctx.stroke();

          // 4방향 무희(오방색 궁중 한복 - 청, 적, 황, 백) 회전 춤사위
          const dancers = [
            { color: '#2563eb', sleeve: '#60a5fa' }, // 동 (청)
            { color: '#dc2626', sleeve: '#f87171' }, // 남 (적)
            { color: '#eab308', sleeve: '#fef08a' }, // 중 (황)
            { color: '#f8fafc', sleeve: '#cbd5e1' }  // 서 (백)
          ];

          dancers.forEach((d, i) => {
            const angle = t + (i * Math.PI / 2);
            const radiusX = 65;
            const radiusY = 35;
            const dx = centerX + Math.cos(angle) * radiusX;
            const dy = centerY + Math.sin(angle) * radiusY;

            // 치마 (한복 치마 펼침)
            ctx.fillStyle = d.color;
            ctx.beginPath();
            ctx.ellipse(dx, dy + 8, 10, 6, 0, 0, Math.PI * 2);
            ctx.fill();

            // 저고리
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(dx - 4, dy - 2, 8, 8);

            // 한삼(너울거리는 긴 소매) 펄럭임
            const sleeveWave = Math.sin(t * 3 + i) * 8;
            ctx.strokeStyle = d.sleeve;
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(dx - 4, dy + 1); ctx.lineTo(dx - 12, dy + 6 + sleeveWave);
            ctx.moveTo(dx + 4, dy + 1); ctx.lineTo(dx + 12, dy + 6 - sleeveWave);
            ctx.stroke();

            // 머리 (가체/쪽진 머리)
            ctx.fillStyle = '#0f172a';
            ctx.beginPath();
            ctx.arc(dx, dy - 6, 4, 0, Math.PI * 2);
            ctx.fill();
            // 족두리 붉은 점
            ctx.fillStyle = '#ef4444';
            ctx.fillRect(dx - 1, dy - 10, 2, 2);
          });

          // 북채 두드림 파티클
          if (Math.sin(t * 4) > 0.7) {
            ctx.fillStyle = '#fef08a';
            ctx.beginPath();
            ctx.arc(centerX + (Math.random() - 0.5) * 16, centerY + (Math.random() - 0.5) * 8, 2.5, 0, Math.PI * 2);
            ctx.fill();
          }

          if (document.getElementById('banquetDanceCanvas')) {
            animId = requestAnimationFrame(renderDance);
          }
        };

        animId = requestAnimationFrame(renderDance);
      }
    }
  }
}
