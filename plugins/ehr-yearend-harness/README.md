# ehr-yearend-harness

> 연말정산(`yjungsan`) 도메인 전용 Claude Code 플러그인. EHR 프로젝트(`EHR_HR50`) 위에 추가 설치하여, 도메인 지식 조회·영향 추적·변경 작업 가이드를 자동 제공한다.

- 버전: `0.1.0`
- 상태: TF 배포 가능 (`/plugin install` 한 줄로 설치)
- 원본 출처: [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin) — 본 플러그인은 그 원본의 *fork* 인 [ehr-harness-yearend](../../README.md) marketplace 안에 *추가로* 들어 있다.

---

## 목차

1. [한눈에](#1-한눈에)
2. [왜 만들었나](#2-왜-만들었나)
3. [폴더 구조](#3-폴더-구조)
4. [구성 요소](#4-구성-요소)
5. [설치](#5-설치)
6. [정책: Plan-First 와 안전 장치](#6-정책-plan-first-와-안전-장치)
7. [범위 제외 (Out of Scope)](#7-범위-제외-out-of-scope)
8. [원본 `ehr-harness` 플러그인과의 관계](#8-원본-ehr-harness-플러그인과의-관계)
9. [트러블슈팅](#9-트러블슈팅)

---

## 1. 한눈에

```
사용자: "TCPN843 이 뭐야?"
  → yearend-domain-map 스킬 자동 발동 → references 기반 답변

사용자: "BefComMgr 수정하면 어디까지 영향?"
  → yearend-chain-tracer 스킬 자동 발동 → 화면↔DB 양방향 추적

사용자: "출산지원금 비과세 반영 플랜 잡아줘"
  → yearend-investigator 에이전트 호출
  → Step 0 (현 상태 확인 — git 이력 + glossary + 변경 흔적) 부터 시작
  → 이미 반영됐으면 보고만 / 안 됐으면 plan 초안 작성

사용자: "이 패키지 본문 고쳐줘"
  → yearend-plan-first 스킬 자동 발동 → 같은 Step 0 분기
  → 미반영이면: 영향 분석 → plan 제시 → "이대로 진행할까요?" → 수정

(추가) sqlplus 등으로 DML/DDL 시도
  → db-read-only 훅이 자동 차단 (SELECT/WITH/EXPLAIN/DESC만 허용)
```

---

## 2. 왜 만들었나

`yjungsan` 은 단일 모듈이 아니라 **5개 레이어**로 움직이는 플랫폼이다.

1. 기준코드/항목 정의 (`TCPN801`, `TCPN803`)
2. 대상자/상태 (`TCPN811`)
3. 원천자료 (`TCPN813` ~ `TCPN839`, `TCPN887`)
4. 계산결과 (`TCPN841`, `TCPN843`, `TYEA850`, `TYEA851`)
5. 오류검증·PDF (`TCPN849`, `TCPN851`, `TCPN855`)

비즈니스 로직 대부분이 Java 보다 **Oracle 패키지 본문** 에 집중되어 있고
(2026 기준 본문만 수만 라인), 화면 축도 Spring MVC · 레거시 JSP · REST API 로 3중 혼재한다.
이 구조에서 개정세법 반영, 후속조치 hotfix, 특수 케이스(겸직·외국인·중도) 대응을 하려면
**"테이블 → 패키지 → 결과테이블 → 마감상태"** 까지 추적이 필요하다.

원본 `ehr-harness` 플러그인은 EHR4/5 *범용* 하네스만 다뤄, 이 yjungsan 추적을 자동화하는
전용 스킬이 없었다. 본 플러그인은 그 간극을 메우고, 또 매년 반복되는 변경 작업에서
**"이미 반영된 것을 또 고치는 헛수고"** 와 **"무단 코드 자동 수정"** 을 막기 위한
plan-first 정책을 함께 제공한다.

---

## 3. 폴더 구조

```
plugins/ehr-yearend-harness/
├── .claude-plugin/
│   └── plugin.json                       ← 플러그인 메타 (name, version)
├── README.md                              ← 본 문서
│
├── references/                            ← 사실 사전 (4개)
│   ├── yjungsan-tables.md                 ← 22개 테이블 사전
│   ├── yjungsan-packages.md               ← 패키지 6 + 독립 프로시저 7 사전
│   ├── yjungsan-close-chain.md            ← P_CPN_YEA_CLOSE 마감 체인
│   └── yjungsan-glossary.md               ← 표면 표현 ↔ 코드 식별자 동의어 사전
│
├── skills/                                ← 스킬 3개 (자동 발동)
│   ├── yearend-domain-map/SKILL.md        ← 도메인 지도 (정적 지식 조회)
│   ├── yearend-chain-tracer/SKILL.md      ← 체인 추적 (영향 분석)
│   └── yearend-plan-first/SKILL.md        ← Plan-First 정책 (변경 작업 라우터)
│
├── agents/
│   └── yearend-investigator.md            ← 조사·플랜 초안 에이전트 (서술형 요청용)
│
├── hooks/
│   └── hooks.json                         ← PreToolUse(Bash) 훅 등록
│
└── scripts/
    └── db-read-only.sh                    ← DML/DDL/PL-SQL 차단 (SELECT만 허용, fail-closed)
```

---

## 4. 구성 요소

본 플러그인 한 번 설치하면 **스킬 3개 + 에이전트 1개 + 훅 1개 + 사실 사전 4개** 가 함께 깔린다.

### 4.1 스킬

| 이름 | 발동 시점 | 책임 |
|------|----------|------|
| **`yearend-domain-map`** | "TCPN843 이 뭐야?", "PKG_CPN_YEA_2026_SYNC 는?", "yjungsan 전체 구조" 같은 **지식 조회** | references/*.md 기반 답변 (추측 금지) |
| **`yearend-chain-tracer`** | "BefComMgr 수정하면 어디까지 영향?", "TCPN843 컬럼 추가 시 체인" 같은 **영향 범위** 질의 | 입력(화면/테이블/프로시저/증상) 하나로 양방향 추적 (관련 파일 + DB 객체 + 마감 영향) |
| **`yearend-plan-first`** | "고쳐줘", "반영해줘", "hotfix 해줘" 같은 **변경 작업** 요청 | Step 0 (현 상태 확인) → 이미 반영됐으면 보고 / 미반영이면 영향 분석 → plan → 사용자 명시적 승인 → 수정 |

### 4.2 에이전트

| 이름 | 호출 시점 | 책임 |
|------|----------|------|
| **`yearend-investigator`** | "개정세법 반영 영향도 봐줘", "장애 조사해줘", "출산지원금 반영 플랜 잡아줘" 같은 **서술형·복합** 요청 | 위 스킬을 조합해 조사 리포트 + 리스크 체크리스트 + 패치 플랜 초안. **실제 코드/DDL 수정 X**. 산출물은 `superpowers:writing-plans` 로 넘기는 정제된 입력. |

### 4.3 훅 (자동 등록)

| 파일 | 매처 | 동작 |
|------|------|------|
| **`hooks/hooks.json` → `scripts/db-read-only.sh`** | `PreToolUse` / `Bash` | `sqlplus`·`sqlcl`·`sqlcmd`·`tibero`·`tbsql`·`impdp`·`expdp`·`rman` 명령으로 들어가는 SQL 검사. DML/DDL/PL-SQL/시스템 패키지(`DBMS_*`, `UTL_*`) 키워드와 `@script.sql` 패턴을 차단. 허용은 `SELECT`/`WITH`/`EXPLAIN`/`DESC` 만. Fail-closed (훅 자체 에러도 차단). |

`/plugin install` 한 번이면 자동으로 등록되어 사용자가 `.claude/settings.json` 손댈 일 없다.

### 4.4 사실 사전 (references/)

| 파일 | 내용 |
|------|------|
| `yjungsan-tables.md` | 22개 핵심 테이블 (`TCPN8##`, `TYEA8##`) 컬럼·용도 사전 |
| `yjungsan-packages.md` | 패키지 6개(`PKG_CPN_YEA_{YY}_*`) + 독립 프로시저 7개의 책임 분담 |
| `yjungsan-close-chain.md` | `P_CPN_YEA_CLOSE` 마감 체인의 단계·게이트·재계산 흐름 |
| `yjungsan-glossary.md` | 표면 표현 ↔ 코드 식별자 동의어 사전 + 변경 흔적 패턴 + 트리거 단어 (Step 0 검색 확장에 사용) |

---

## 5. 설치

본 플러그인은 [ehr-harness-yearend](../../README.md) marketplace 안에 들어 있다. 타깃 EHR 프로젝트의 Claude Code 세션에서:

### 5.1 마켓플레이스 등록 + 설치

```
/plugin marketplace add <fork repo URL 또는 로컬 경로>
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

> 명령어 끝의 **`@ehr-harness-yearend`** 는 marketplace 이름. 그 앞의 `ehr-yearend-harness` 가 플러그인 이름이다.

(원본 `ehr-harness` 플러그인도 같은 marketplace 안에 있으므로 함께 설치 가능. 자세한 절차는 [루트 README 의 방법 3](../../README.md#방법-3-ehr-yearend-harness-연말정산-tf용-추가-설치) 참고.)

### 5.2 설치 검증

타깃 프로젝트(예: `EHR_HR50`)에서 Claude Code 를 켠 뒤:

```
TCPN843 이 뭐야?
```

→ `yearend-domain-map` 스킬이 자동 발동해 `references/yjungsan-tables.md` 기반 답변이 나오면 정상.

훅도 같이 검증해보고 싶다면:

```
sqlplus 로 "DELETE FROM TCPN843 WHERE 1=1" 실행해봐
```

→ db-read-only 훅이 가로채서 다음과 비슷한 메시지로 차단되어야 정상:
```
⛔ DB 변경/실행 SQL 감지: DELETE
   조회(SELECT/WITH/EXPLAIN/DESC)만 허용됩니다.
```

### 5.3 업데이트

플러그인이 갱신되면:

```
/plugin marketplace update ehr-harness-yearend
/plugin update ehr-yearend-harness@ehr-harness-yearend
```

이게 안 먹으면 재설치:

```
/plugin uninstall ehr-yearend-harness@ehr-harness-yearend
/plugin marketplace update ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

### 5.4 (선택) 개발 모드 단축키 — 정션 연결

본 패키지를 **직접 수정하면서 즉시 타깃에 반영**하고 싶을 때만 정션 스크립트를 쓴다 (TF 일반 사용자는 5.1 만으로 충분).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/link-to-target.ps1 `
    -SourceRoot   "<this repo>\plugins\ehr-yearend-harness" `
    -TargetClaudeDir "<target ehr project>\.claude"
```

정션 불가 환경(권한·DevDrive 미사용)에서는 `sync-to-target.ps1` 로 복사. 정션 스크립트는 본 fork 의 `scripts/` 디렉토리에 위치.

---

## 6. 정책: Plan-First 와 안전 장치

본 플러그인은 두 종류의 안전장치를 함께 제공한다.

### 6.1 Plan-First 정책 (코드 변경)

**yearend 도메인의 코드/DDL/스키마 변경 요청** 은 자동으로 다음 흐름을 따른다 (`yearend-plan-first` 스킬이 발동).

```
사용자 요청 ("출산지원금 반영해줘", "이 패키지 본문 고쳐줘" 등)
    │
    ▼
[Step 0] 현 상태 확인  ← 5개 sub-step 모두 거침
    ├─ 0-A 변경 이력: git log/blame 으로 최근 커밋·메시지·날짜 우선 확인
    ├─ 0-B 동의어 확장: yjungsan-glossary.md 로 키워드 확장 (예: "사업장코드" → BUSINESS_PLACE_CD, BP_CD, ENTER_CD)
    ├─ 0-C 변경 흔적 grep: (YYYY.MM.DD), // 추가, // 변경 같은 표기 별도 검색
    ├─ 0-D 트리거 단어: "추가/개선/이미" 단어 감지 시 위 검사 더 깊게
    └─ 0-E 판정: 0% / 부분 / 충분 셋 중 하나로 분류
        │
        ├─ 부분 → 사용자에게 "이런 흔적이 있는데 이게 원하시는 변경인가요?" 우선 확인
        ├─ 충분 → "이미 <파일:line> 에 <방식> 으로 반영됨, 커밋 <hash> (<날짜>)" 보고 후 종료
        └─ 0% → 다음 단계
                │
                ▼
            [Step 1] 영향 분석 (yearend-chain-tracer)
            [Step 2] 변경 plan 제시 (대상 파일:line, 리스크, 검증 방법)
            [Step 3] 사용자 명시적 승인 ("이대로 진행할까요? Y/N")
            [Step 4] Edit/Write + 검증 가이드
```

- 정책 정의: [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md)
- 적용 대상: yearend 도메인의 코드/DDL/스키마 변경 요청
- 적용 외: 단순 조회·도메인 질의·영향 분석 (즉시 답변)

> 정책 우회: 진짜 비상 상황에서 사용자가 직접 `Edit`/`Write` 도구를 호출하거나 메시지에 `[plan-first 우회]` 라고 명시한 경우에만 우회된다.

### 6.2 DB 변경 차단 훅 (자동 등록)

플러그인 설치 시 PreToolUse(Bash) 훅이 함께 등록되어 `sqlplus`·`sqlcl`·`sqlcmd`·`tibero`·`tbsql`·`impdp`·`expdp`·`rman` 명령으로 들어가는 SQL 중 다음을 자동 차단:

| 분류 | 차단 키워드 |
|------|------------|
| DML/DDL | `DROP`, `TRUNCATE`, `DELETE`, `UPDATE`, `INSERT`, `MERGE`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `UPSERT` |
| 실행 | `EXEC`, `EXECUTE`, `CALL` |
| PL/SQL 블록 | `DECLARE`, `BEGIN` |
| 시스템 패키지 | `DBMS_*`, `UTL_*` |
| 스크립트 파일 | `@script.sql` (내용 검증 불가 → 보수적 차단) |

허용: `SELECT`, `WITH`, `EXPLAIN`, `DESC` 만. 훅 자체 에러도 차단(fail-closed).

> 원본 `ehr-harness` 플러그인을 같이 깔아 "하네스 만들어줘" 까지 실행한 경우, 동일 훅이 타깃 프로젝트의 `.claude/hooks/` 에도 한 번 더 복사된다. 같은 검사가 두 번 도는 정도라 안전성에 문제 없다.

---

## 7. 범위 제외 (Out of Scope)

- EHR4 지원. EHR5(`EHR_HR50`) 먼저.
- DB 직접 쓰기·DDL 자동 실행. 본 플러그인은 **읽기·분석·plan** 까지. 실제 DDL 은 사용자가 수동 실행.
- 화면 자동 생성. 그건 원본 `ehr-harness` 의 `screen-builder` 영역.
- yearend 외 EHR 도메인 (근태·급여·인사). 그건 원본 `ehr-harness` 영역.

---

## 8. 원본 `ehr-harness` 플러그인과의 관계

| 항목 | 본 플러그인 | 원본 `ehr-harness` |
|------|------------|------------------|
| 도메인 | 연말정산(`yjungsan`) 전용 | EHR4/5 범용 (화면·프로시저·DB·릴리즈) |
| 의존성 | 원본 없이도 단독 동작 (단, `db-query`/`procedure-tracer` 등 일부 위임 호출 시 fallback) | 단독 사용 가능 |
| 함께 설치 | ✅ 권장 — 두 플러그인 동시 사용 시 시너지 (yearend 가 원본의 공통 스킬을 위임 호출) | |
| 설치 명령 | `/plugin install ehr-yearend-harness@ehr-harness-yearend` | `/plugin install ehr-harness@ehr-harness-yearend` |

자세한 설치 매트릭스는 [루트 README 의 시나리오별 권장](../../README.md#2-플러그인-설치-방법) 참고.

---

## 9. 트러블슈팅

### "Plugin not found in any marketplace"

흔한 원인 두 가지:

1. **marketplace 이름 헷갈림** — 명령어의 `@<name>` 자리에는 *플러그인 이름이 아니라 marketplace 이름* 이 와야 한다. 본 fork 의 marketplace 이름은 `ehr-harness-yearend` (`ehr-harness` 가 아님). 즉 `/plugin install ehr-yearend-harness@ehr-harness-yearend`.
2. **marketplace 캐시 stale** — 새로 추가된 plugin entry 가 캐시에 반영 안 된 경우. 다음 순서로 재등록:
   ```
   /plugin marketplace remove ehr-harness-yearend
   /plugin marketplace add <fork repo URL 또는 로컬 경로>
   /plugin install ehr-yearend-harness@ehr-harness-yearend
   ```

### "Your organization does not have access to Claude"

플러그인 문제가 아니라 **Claude API 인증·권한** 문제다. CLI 에서 `claude` → `/logout` → `/login` 다시 시도. 그래도 안 풀리면 회사 IT/관리자에게 organization 권한 확인 요청.

### IntelliJ Claude Code GUI 에서 스킬이 발동 안 함

IntelliJ 의 Claude Code 익스텐션이 marketplace plugin 의 일부 컴포넌트만 인식할 가능성이 있다. CLI 또는 Desktop App 에서 같은 시도 후 발동 여부 비교.

### Step 0 가 이미 반영된 변경분을 또 놓침

`yjungsan-glossary.md` 의 동의어 사전이 누락되어 검색이 좁게 들어갔을 가능성. 누락된 매핑을 발견하면 PR 로 추가.

또 사용자 메시지에 "추가/개선/이미" 같은 트리거 단어가 없었을 수도 있다. 그럴 땐 메시지에 한 줄 추가하면 도움 — 예: "이미 일부 작업한 후의 추가 요청입니다."

### `db-read-only.sh` 가 정상 SELECT 까지 차단함 (false positive)

SELECT 문 안의 컬럼명이 `CREATE_DATE`, `UPDATE_TM`, `DELETE_YN` 등으로 되어 있으면 키워드 매칭에 걸릴 수 있다. 발견 시 issue 로 알려주면 정밀화 가능.

---

## 부록: 사용자가 직접 살펴볼 위치

- 도메인 지식: [`references/yjungsan-tables.md`](references/yjungsan-tables.md), [`references/yjungsan-packages.md`](references/yjungsan-packages.md), [`references/yjungsan-close-chain.md`](references/yjungsan-close-chain.md), [`references/yjungsan-glossary.md`](references/yjungsan-glossary.md)
- 스킬 정의: [`skills/yearend-domain-map/SKILL.md`](skills/yearend-domain-map/SKILL.md), [`skills/yearend-chain-tracer/SKILL.md`](skills/yearend-chain-tracer/SKILL.md), [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md)
- 에이전트: [`agents/yearend-investigator.md`](agents/yearend-investigator.md)
- 훅 동작: [`scripts/db-read-only.sh`](scripts/db-read-only.sh), [`hooks/hooks.json`](hooks/hooks.json)
