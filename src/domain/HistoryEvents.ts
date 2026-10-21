import { GameState } from '../types';

export interface DilemmaChoice {
  text: string;
  primary?: boolean;
  effect: (state: GameState) => string;
}

export interface InspectorDilemma {
  title: string;
  desc: string;
  choices: DilemmaChoice[];
}

export class HistoryEventManager {
  public static getDilemmaPool(): InspectorDilemma[] {
    return [
      {
        title: "암행어사 서면 보고: 난전 단속",
        desc: "수원 저잣거리에 난전(자유 상인)이 급증하여 시전 상인들이 상소를 올렸습니다. 난전을 허용하시겠습니까?",
        choices: [
          {
            text: "신해통공 발령 (난전 전면 허용)",
            primary: true,
            effect: (state) => {
              if (state.loyalty >= 70) {
                state.gold += 350;
                return "상업이 융성하며 막대한 세수가 들어왔습니다! (+🪙350)";
              } else {
                state.loyalty -= 15;
                return "치안 부재로 난전 폭력배가 상가를 불태웠습니다! (민심 -15%)";
              }
            }
          },
          {
            text: "시전 상인의 독점권 인정",
            primary: false,
            effect: (state) => {
              state.gold += 120;
              state.loyalty -= 5;
              return "상인들의 헌금을 받았으나 물가가 올랐습니다.";
            }
          }
        ]
      },
      {
        title: "암행어사 긴급 보고: 흉년과 환곡",
        desc: "흉년으로 백성들의 굶주림이 극에 달했습니다. 관아 창고의 구휼미를 풀겠습니까?",
        choices: [
          {
            text: "사창을 활짝 열어 무상 방출 (쌀 200석)",
            primary: true,
            effect: (state) => {
              if (state.rice >= 200) {
                state.rice -= 200;
                state.loyalty = Math.min(100, state.loyalty + 25);
                return "정조 대왕의 성덕에 감복하여 백성들이 결속합니다! (민심 +25%)";
              } else {
                state.loyalty -= 20;
                return "창고에 쌀이 부족하여 분노한 백성들이 소요를 일으켰습니다!";
              }
            }
          },
          {
            text: "성역 완공용 예비미이므로 보존",
            primary: false,
            effect: (state) => {
              state.loyalty -= 18;
              state.pop = Math.max(20, state.pop - 20);
              return "유민들이 수원천을 등지고 떠나 인구가 줄었습니다.";
            }
          }
        ]
      },
      {
        title: "군관 급보: 구선복의 사병 훈련",
        desc: "군부 실세 구선복이 은밀히 사병을 모은다는 밀고가 들어왔습니다.",
        choices: [
          {
            text: "백동수의 장용영을 보내 선제 압수수색",
            primary: true,
            effect: (state) => {
              if (state.retainers.baek) {
                state.authority += 15;
                return "백동수가 무혈 진압하여 무기고를 접수했습니다! (왕권 +15)";
              } else {
                state.military -= 30;
                return "군부의 반발로 군사력이 위축되었습니다.";
              }
            }
          },
          {
            text: "군부 안정을 위해 묵인하고 관직 하사",
            primary: false,
            effect: (state) => {
              state.military += 20;
              state.authority -= 10;
              return "군사력은 유지되었으나 왕권이 흔들립니다.";
            }
          }
        ]
      }
    ];
  }

  public static evaluateEnding(state: GameState): { title: string; story: string } {
    if (state.fortressProgress >= 100 && state.authority >= 85 && state.loyalty >= 85 && state.gold >= 3000) {
      return {
        title: "자강(自强)의 신조선 [True Ending]",
        story: "수원화성이 난공불락의 개혁 요새로 완벽히 완공되었습니다! 탕평책과 상공업 부흥이 확고히 뿌리내려, 정조 사후에도 권문세족의 세도정치가 발붙이지 못하고 조선은 동아시아 최고의 근대 문명국가로 도약합니다."
      };
    } else if (state.fortressProgress >= 80 && state.gold >= 5000 && state.retainers.park) {
      return {
        title: "동방의 상업 공화국 [Merchant City]",
        story: "신해통공과 삼남대로 교역의 성공으로 화성은 청나라와 왜를 잇는 거대 상업 메트로폴리스가 되었습니다. 상인과 중인 계층이 의회를 주도하며 경제 중심의 새로운 역사를 개창합니다."
      };
    } else if (state.fortressProgress >= 100 && state.military >= 300 && state.retainers.baek) {
      return {
        title: "철혈의 군사 요새 [Military Bastion]",
        story: "정예 장용외영과 팔달산 서장대, 완벽한 포루·치성이 북방과 해안을 철통 수호합니다. 훗날 외세의 침략을 압도적으로 격퇴하는 자주 국방의 보루가 완성되었습니다."
      };
    } else if (state.fortressProgress >= 90 && state.research.seed && state.research.gwanong) {
      return {
        title: "문예부흥의 르네상스 [Cultural Renaissance]",
        story: "규장각 실학과 만석거 관개, 《화성성역의궤》가 완비되어 세계에서 가장 아름답고 과학적인 성곽 도시로 유네스코 세계문화유산의 금자탑을 쌓았습니다."
      };
    } else if (state.loyalty <= 30) {
      return {
        title: "민란과 잿더미 [Peasant Revolt]",
        story: "가혹한 부역과 군량 부족으로 굶주린 백성들이 횃불을 들고 봉기했습니다. 공사 중이던 화성은 화염에 휩싸이고 정조의 원대한 개혁은 잿더미가 되었습니다."
      };
    } else if (state.gold < 0 || state.retainers.hong) {
      return {
        title: "세도 가문의 손아귀 [Oligarchy Puppet]",
        story: "무리한 차관과 세도가와의 타협으로 화성의 모든 이권이 노론 척신들에게 넘어갔습니다. 정조 승하 후 안동 김씨의 세도정치가 60년간 조선을 집어삼킵니다."
      };
    } else if (state.fortressProgress >= 100) {
      return {
        title: "미완의 개혁 [Historical Ending]",
        story: "웅장하고 수려한 수원화성은 우뚝 섰으나, 정조의 갑작스러운 승하와 함께 수구 세력이 득세하며 역사 그대로 세도정치의 소용돌이로 흘러갑니다."
      };
    } else {
      return {
        title: "모래 위의 누각 [Failed Project]",
        story: "24년의 세월이 흘렀으나 화성은 미완성으로 방치되었습니다. 낭비된 국고와 피폐해진 민심 속에 개혁 군주의 웅지는 역사 속으로 스러져 갑니다."
      };
    }
  }
}
