# BerufeTracker

[English](README.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

전문 기술을 300까지 올리려면 구리 광석, 리넨 옷감, 평온초 꽃잎이 아직 얼마나 필요할까요? BerufeTracker가 계산해 드립니다. 모든 전문 기술을 기본 재료까지, 모든 캐릭터와 은행을 통틀어서요.

**WoW Forever**용이며, 게임 클라이언트의 언어로 표시됩니다: 영어, 독일어, 프랑스어, 스페인어, 포르투갈어, 이탈리아어, 러시아어, 한국어, 중국어(간체 및 번체).

## 기능

**재료**
- 모든 전문 기술의 전체 필요량을 기본 재료까지 분해합니다. 예를 들어 청동 주괴는 구리 주괴와 주석 주괴로, 이는 다시 광석으로 계산됩니다.
- 현재 진영의 모든 캐릭터가 가방, 은행, 우편함에 가진 수량을 차감합니다. [BagBrother/Bagnon](https://www.curseforge.com/wow/addons/bagnon)이 설치되어 있으면 BerufeTracker가 아직 모르는 캐릭터도 포함됩니다.
- 필터: “모든 전문 기술”은 진영의 모든 캐릭터를 각자의 전문 기술과 숙련도로 합산합니다. “배운 전문 기술”은 배운 전문 기술을 하나씩 한 번, “전문 기술마다 한 번”은 배우지 않은 것까지 포함해 모든 전문 기술을 한 번씩 계산하며, 캐릭터 하나만 선택할 수도 있습니다. 채집 기술은 제외할 수 있습니다.
- 마우스를 올리면 전문 기술별 필요량, 가격과 구매 비용, 캐릭터별 보유량, 재료를 얻는 곳이 표시됩니다: 지역별 채집 지점, 레벨별 몬스터, 진영의 가장 가까운 상인.
- 경매장 검색으로 직접 모으는 대신 전부 구매하면 얼마가 드는지 볼 수 있습니다.

**경로**
- 각 전문 기술의 단계별 경로와 아직 남은 양.
- 가이드 선택: Metabot, RankedBoost, Wowhead, wowtbc.gg, GoldGoblin 또는 wow-professions, 전문 기술별로 또는 전체에 한 번에.
- 없는 제조법은 얻는 곳과 함께 표시됩니다.
- 기술 전문가 방문은 경로의 알맞은 지점에, 다음 등급을 가르쳐 주는 가장 가까운 기술 전문가와 함께 표시됩니다.

**경유지**
- 기술 전문가나 재료를 Ctrl+클릭하면 가장 가까운 기술 전문가나 상인으로 경유지가 설정됩니다.
- 방향 화살표와 설명이 있는 막대가 목표를 보여 줍니다. 클릭하면 목표 위치에서 지도가 열립니다.
- 지도에도 이름표가 표시됩니다. 지도 핀을 대화창에 공유하면 설명도 함께 전송됩니다.
- NPC에게 말을 걸면 경유지가 바로 사라집니다.

**게임 내**
- 아이템 툴팁(가방, 은행, 경매장, 전리품)에 현재 필터 기준으로 아직 필요한 수량이 표시됩니다.
- 월드의 광맥과 약초에 아직 필요한 수량이 표시됩니다.

## 사용법

- `/berufe` 또는 미니맵 버튼으로 창을 엽니다.
- 가격을 보려면 경매장을 열고 “가격 검색”을 클릭하세요(또는 `/berufe scan`).
- `/berufe skill <전문기술> <값>`으로 숙련도가 인식되지 않을 때 직접 설정합니다. 값 없이 입력하면 다시 자동 인식이 적용됩니다.
- 전문 기술이 인식되도록 각 캐릭터는 애드온을 켠 상태로 한 번 접속해야 합니다. 은행은 한 번 열면 바로 기록됩니다.

## 제한 사항

- 아이템, 기술 전문가, 상인, 채집 지점 이름은 게임과 QuestieDB에서 가져옵니다. 이탈리아어와, 제작 아이템이 없는 일부 제조법(마법부여 등)은 이름이 영어로 표시됩니다. 제조법을 얻는 곳은 독일어와 영어로만 제공되므로 한국어에서는 영어로 표시됩니다.
- 거리는 직선거리이며 같은 대륙에서만 적용됩니다.
- 모든 제조법의 획득 장소가 알려져 있지는 않습니다.
- 상인 및 위치 데이터는 QuestieDB에서 가져오므로 일부 오류가 있을 수 있습니다.

## 출처 및 감사

- **경로:** [Metabot](https://metabot.gg/en/wow-forever/professions), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/), [Wowhead](https://www.wowhead.com/forever/profession-leveling-guides), [wowtbc.gg](https://wowtbc.gg/warcraftforever/), [GoldGoblin](https://classic.goldgoblin.net/berufe/), [wow-professions](https://www.wow-professions.com/forever/). 경로는 애드온에 맞게 요약되었습니다. 모든 설명이 담긴 전체 가이드는 각 사이트에서 볼 수 있으며, 링크는 애드온의 가이드 선택에 표시됩니다.
- **기술 전문가, 상인, 위치**는 QuestieDB(GPLv3)에서 생성했습니다. Questie 팀과 모든 기여자에게 감사드립니다. BerufeTracker는 Questie 팀의 프로젝트가 아닙니다.

## 라이선스

GPLv3, `LICENSE.md` 참조.
