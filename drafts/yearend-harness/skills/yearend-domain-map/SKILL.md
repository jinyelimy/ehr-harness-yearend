---
name: yearend-domain-map
description: 연말정산(yjungsan) 도메인의 정적 지도와 도메인 구조를 제공하는 참조형 스킬. 테이블(TCPN8##), 패키지(PKG_CPN_YEA_{YY}_*), 마감 체인, 계산 결과 구조를 질문받았을 때 발동한다. "연말정산 테이블", "TCPN843 뭐야", "연말정산 패키지 구조", "마감 체인", "yjungsan 도메인 구조", "연말정산 전체 그림" 같은 요청에 사용.
---

# Yearend Domain Map

연말정산 도메인의 테이블·패키지·마감 체인을 통합해 설명하는 참조 스킬이다.
별도 동작(스캔/추적)을 수행하지 않는다. 정적 지식 조회 전용.

---

## 목적

연말정산 관련 질문에 대해 **일관되고 검증된 도메인 지식**을 되돌려주는 것이 목적이다.
사용자 개인 기억이나 Claude 의 일반 지식이 아니라, 본 스킬이 참조하는 `references/*.md`
에 기록된 사실만 기반으로 답한다.

---

## 사용 시점

다음 유형의 요청에 이 스킬이 발동한다.

- "TCPN843 이 뭐야?" / "TCPN811 의 상태 컬럼 종류는?"
- "연말정산 테이블 레이어 좀 정리해줘"
- "PKG_CPN_YEA_2026_SYNC 는 뭘 하는 패키지야?"
- "마감할 때 어떤 프로시저가 돌아?"
- "yjungsan 전체 구조 한 장에 정리해줘"

---

## 사용하지 않을 시점

다음은 이 스킬의 범위가 아니다.

- 특정 파일·행 단위 코드 분석 → `yearend-chain-tracer` 또는 `codebase-navigator` 사용.
- 운영 장애의 원인 추적 → `yearend-investigator` 에이전트 사용.
- DB 에 직접 쿼리 실행 → `db-query` 스킬 사용 (설치되어 있을 때).
- 코드 수정 / 테이블 DDL 변경 → 본 스킬 범위 밖. `superpowers:writing-plans` 로 넘어간다.

---

## 동작 방법

사용자 질의가 들어오면 다음 순서로 참조 문서를 조회한다.

1. 질의에서 테이블·패키지·프로시저 이름을 추출한다.
2. 이름이 `TCPN` 계열이면 `../../references/yjungsan-tables.md` 의 해당 섹션을 읽는다.
3. 이름이 `PKG_CPN_YEA_` 또는 `P_CPN_` 계열이면 `../../references/yjungsan-packages.md` 의 해당 섹션을 읽는다.
4. 질의에 `마감`, `CLOSE`, `INPUT_CLOSE_YN`, `TCPN849` 가 포함되면 `../../references/yjungsan-close-chain.md` 를 추가로 읽는다.
5. **참조 문서에 없는 정보는 "참조 문서에 없음" 이라고 명시**한다. 추측하지 않는다.
6. 연도 의존 객체(`PKG_CPN_YEA_{YY}_*`)를 답변할 때는 귀속연도를 명시하거나 사용자에게 확인한다.

---

## 기본 응답 형식

1. **요약 (1~3줄)** — 질의가 가리키는 대상이 무엇인지.
2. **레이어 위치** — 5레이어(기준/대상자/원천/계산결과/오류검증·PDF) 중 어디에 속하는가.
3. **핵심 사실** — PK, 용도, 업데이트 주체 등 references 에서 가져온 필드.
4. **관련 객체** — 같이 보면 좋은 테이블/패키지 (링크나 이름만).
5. **출처** — 어느 references/*.md 섹션을 읽었는지.

응답은 Markdown 으로. mermaid 다이어그램은 질의가 "구조 그려줘/체인 보여줘" 식일 때만 사용.

---

## 참조하는 문서

- `../../references/yjungsan-tables.md` — 테이블 사전
- `../../references/yjungsan-packages.md` — 패키지·프로시저 사전
- `../../references/yjungsan-close-chain.md` — 마감 체인 상세
