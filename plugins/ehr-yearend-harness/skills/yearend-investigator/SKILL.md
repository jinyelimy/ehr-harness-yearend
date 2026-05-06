---
name: yearend-investigator
description: Codex에서 연말정산(yjungsan) 도메인의 서술형·복합 조사, 후속조치/JIRA/메신저 원문 정리, 개정세법 영향도, 장애 원인 후보, 패치 플랜 초안을 처리하는 워크플로우 스킬. "후속조치 건 정리", "기존 반영 여부 확인", "개정세법 영향도", "장애 조사", "출산지원금 반영 플랜", "연말정산 이슈 조사" 요청에 사용. 실제 코드/DDL 수정은 하지 않고 yearend-plan-first 정책으로 넘긴다.
---

# Yearend Investigator (Codex wrapper)

> ⚠️ **이 파일은 thin wrapper 이다 — 절차의 정본이 아니다.** ⚠️
>
> 절차·정책·출력 템플릿의 *유일한 정본* 은 `../../agents/yearend-investigator.md` 다.
> 새 정책은 정본 파일에서만 수정한다. 이 SKILL.md 에 절차를 복제·재기술하지 말 것 (drift 방지).
> 이 파일의 역할은 ① Codex 진입을 받음 ② 정본 파일을 읽으라고 지시함 ③ Codex 환경의 도구 매핑을 안내함, 세 가지뿐이다.

Codex용 `yearend-investigator`는 Claude의 `agents/yearend-investigator.md`를
별도 subagent로 띄우지 않고, **메인 Codex가 그대로 따르는 조사 워크플로우**로 적용하는
스킬이다.

## 왜 스킬인가

이 워크플로우의 주 역할은 독립 실행자가 아니라 라우터/조사자/플랜 초안 작성자다.
단일 후속조치 건, 장애 조사, 개정세법 영향도처럼 메인 Codex가 이어서 대화하고
근거를 통합해야 하는 작업은 subagent보다 스킬이 가볍고 안정적이다.

Codex native subagent는 사용자가 명시적으로 병렬 조사를 요청할 때만 고려한다.
예: "아래 5건을 각각 별도 조사자로 병렬 분석해줘."

## 시작 절차

1. 먼저 `../../agents/yearend-investigator.md`를 읽고 그 절차를 이 스킬의 상세 지침으로 사용한다.
2. Claude 전용 도구명은 Codex 환경에 맞춰 해석한다.
   - `Read` -> 파일 읽기
   - `Grep`/`Glob` -> `Get-ChildItem`, `Select-String`, `rg` 가능 시 `rg`
   - `Bash` -> 현재 Codex shell
   - `superpowers:writing-plans` -> Codex에서는 패치 플랜 초안 산출물
3. `yearend-domain-map`, `yearend-chain-tracer`, `yearend-plan-first` 스킬 정의를 필요한 경우에만 추가로 읽는다.
4. 도메인 사실은 `../../references/*.md`에 있는 내용만 권위 출처로 사용한다. 없으면 "참조 문서에 없음" 또는 "확인 필요"라고 표시한다.

## 처리 원칙

- 실제 코드, DDL, DB 데이터 수정은 이 스킬의 범위가 아니다.
- 변경 요청이 포함되면 `yearend-plan-first` 절차로 넘긴다.
- 조사 시작 시 항상 Step 0 현 상태 확인을 먼저 수행한다.
- 이미 반영된 정황이 있으면 수정 계획을 만들지 말고 파일/라인/커밋 근거와 함께 보고한다.
- DB는 SELECT, WITH, EXPLAIN, DESC 성격의 조회만 허용한다. DML/DDL/PLSQL 실행은 금지한다.
- `.mrd`, `.pdf`, `.zip`, `.jar`, `.class` 등 binary 파일은 1회 확인 후 외부 도구 필요로 표시한다.
- 고객/회사명, 운영 데이터, 계약 조건, 담당자명, 내부 배포 일정은 공개 가능 여부가 명확하지 않으면 기록하지 않는다.

## 출력

기본 출력 형식은 `../../agents/yearend-investigator.md`의 "출력 템플릿"을 따른다.
다만 Codex에서는 마지막에 다음을 함께 남긴다.

- 사용한 references 목록
- 확인한 파일/커밋 근거
- 실제 수정 없음 여부
- 다음 단계가 `yearend-plan-first`인지, 단순 추가 조사인지
