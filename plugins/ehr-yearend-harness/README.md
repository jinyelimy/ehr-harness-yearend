# Yearend Harness — 연말정산 작업용 Claude Code 하네스 (MVP)

연말정산(`yjungsan`) 업무에서 개정세법 반영 · 후속조치 hotfix · 특수 케이스 대응을
Claude Code 로 빠르게 조사·영향도 분석·플랜 초안 작성까지 끌고 가기 위한 최소 세트 하네스.

- 작성: 2026-04-24
- 상태: Plugin v0.1.0 (Claude Code 플러그인으로 패키징, TF 배포 가능)
- 근거 문서:
  - 설계 스펙: `docs/superpowers/specs/2026-04-24-yearend-harness-design.md` (로컬 전용, gitignore 대상)
  - 구현 플랜: `docs/superpowers/plans/2026-04-24-yearend-harness-implementation.md` (로컬 전용)
  - 분석 원천: `EHR_HR50/docs/records/연말정산_yjungsan_소스_DB_상세분석_20260423.md`

---

## 1. 왜 만들었나

`yjungsan` 은 단일 모듈이 아니라 **5개 레이어**로 움직이는 플랫폼이다.

1. 기준코드/항목 정의 (`TCPN801`, `TCPN803`)
2. 대상자/상태 (`TCPN811`)
3. 원천자료 (`TCPN813` ~ `TCPN839`, `TCPN887`)
4. 계산결과 (`TCPN841`, `TCPN843`)
5. 오류검증·PDF (`TCPN849`, `TCPN851`, `TCPN855`)

비즈니스 로직은 Java 보다 **Oracle 패키지 본문**에 더 강하게 집중돼 있고
(2026 기준 패키지 본문만 수만 라인), 화면 축도 Spring MVC · 레거시 JSP · REST API 로
3중 혼재한다. 이 구조에서 개정세법 반영이나 장애 분석을 하려면 **"테이블 → 패키지
→ 결과테이블 → 마감상태"** 까지 추적해야 하는데, 기존 범용 `ehr-harness` 플러그인에는
이 추적을 자동화하는 전용 스킬이 없다. 이 하네스는 그 간극을 메운다.

---

## 2. 한 줄 요약

> "**연말정산 도메인 전용 지식(참조 3) + 자동 스킬 2개 + 조립 에이전트 1개**를 묶은 Claude Code 플러그인. 타깃 EHR 프로젝트에서 `/plugin install` 한 줄로 설치하면 Claude Code 가 연말정산 질문에 즉시 반응한다."

---

## 3. 폴더 구조

```
plugins/ehr-yearend-harness/
├── .claude-plugin/
│   └── plugin.json                   ← 플러그인 메타데이터 (name, version)
├── README.md                         ← 본 문서
├── references/
│   ├── yjungsan-tables.md            ← 22개 테이블 사전
│   ├── yjungsan-packages.md          ← 패키지 6 + 독립 프로시저 7 사전
│   └── yjungsan-close-chain.md       ← P_CPN_YEA_CLOSE 마감 체인
├── skills/
│   ├── yearend-domain-map/SKILL.md   ← 도메인 지도 스킬
│   └── yearend-chain-tracer/SKILL.md ← 체인 추적 스킬
└── agents/
    └── yearend-investigator.md       ← 조사 에이전트
```

---

## 4. 구성 요소 책임 분담

```
 사용자 요청
     │
     ▼
┌──────────────────────────────┐
│ Agent: yearend-investigator  │  ← 장애·요구사항 조사 + 플랜 초안 작성
└──────────────────────────────┘
         │ 호출
         ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Skill: yearend-domain-map    │   │ Skill: yearend-chain-tracer  │
│ (정적 지식 조회 전용)        │   │ (화면↔DB 양방향 추적)        │
└──────────────────────────────┘   └──────────────────────────────┘
         │                                      │
         └──────────┬───────────────────────────┘
                    ▼
      ┌──────────────────────────────┐
      │ references/*.md              │
      │ (사실 기반 사전들)           │
      └──────────────────────────────┘
```

### 4.1 `yearend-domain-map` 스킬

- **언제 발동?** "TCPN843 이 뭐야?", "PKG_CPN_YEA_2026_SYNC 는 뭐 해?", "연말정산 전체 구조" 같은 **지식 조회** 질의.
- **무엇 함?** `references/*.md` 에 기록된 사실만 기반으로 답. 추측하지 않음.
- **상세**: `skills/yearend-domain-map/SKILL.md`

### 4.2 `yearend-chain-tracer` 스킬

- **언제 발동?** "`BefComMgr` 수정하면 어디까지 영향?", "`TCPN843` 컬럼 추가 시 체인", "마감에 영향 가?" 같은 **영향 범위** 질의.
- **무엇 함?** 입력(화면/테이블/프로시저/증상) 하나를 받아 관련 파일 + DB 객체 + 마감 상태 영향을 양방향으로 추적.
- **상세**: `skills/yearend-chain-tracer/SKILL.md`

### 4.3 `yearend-investigator` 에이전트

- **언제 호출?** "개정세법 반영 영향도 좀 봐줘", "장애 조사해줘", "출산지원금 반영 플랜 잡아줘" 같은 **서술형·복합** 요청.
- **무엇 함?** 위 두 스킬을 조합해 조사 리포트 + 리스크 체크리스트 + 패치 플랜 초안 을 한 방에 산출. **실제 코드 수정은 하지 않음**.
- **상세**: `agents/yearend-investigator.md`

---

## 5. 설치

본 하네스는 Claude Code 플러그인으로 패키징되어 있다. 타깃 EHR 프로젝트에서
`/plugin` 명령으로 설치한다.

### 5.1 권장: `/plugin install`

타깃 EHR 프로젝트(예: `EHR_HR50`)의 Claude Code 세션에서:

```
/plugin marketplace add C:\yelingg\ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness
```

> `marketplace add` 인자는 본 레포 위치(로컬 경로 또는 GitHub URL).
> `@ehr-harness` 는 marketplace 이름(`./.claude-plugin/marketplace.json` 의 `name`).

설치 결과: 타깃 Claude Code 가 본 패키지의 스킬·에이전트·references 를
자동 인식한다. 별도 정션이나 복사 불필요.

### 5.2 연결 확인

타깃 프로젝트에서 Claude Code 를 켜고 다음을 물어본다.

```
TCPN843 이 뭐야?
```

`yearend-domain-map` 스킬이 자동 호출돼 references 기반 답변이 나오면 설치 정상.

### 5.3 개발 모드 단축키 (선택)

본 패키지를 **직접 수정하면서 즉시 타깃에 반영**하고 싶을 때만 정션 스크립트를 쓴다.
일반 사용자(TF 멤버)는 5.1 만으로 충분하다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/link-to-target.ps1 `
    -SourceRoot   "C:\yelingg\ehr-harness-yearend\plugins\ehr-yearend-harness" `
    -TargetClaudeDir "C:\Users\jinyelimy\isu-hr\EHR_HR50\.claude"
```

정션 불가 환경(권한·DevDrive 미사용 등)에서는 `sync-to-target.ps1` 로 복사 사용.

### 5.4 안전 장치 — DB 변경 자동 차단 (자동 등록)

본 플러그인은 설치 시 **PreToolUse(Bash) 훅 한 개**가 함께 등록되어, `sqlplus`·`sqlcl`·`sqlcmd`·`tibero`·`tbsql`·`impdp`·`expdp`·`rman` 명령으로 들어가는 SQL 중 다음을 자동 차단한다.

| 분류 | 차단 키워드 |
|------|------------|
| DML/DDL | `DROP`, `TRUNCATE`, `DELETE`, `UPDATE`, `INSERT`, `MERGE`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `UPSERT` |
| 실행 | `EXEC`, `EXECUTE`, `CALL` |
| PL/SQL 블록 | `DECLARE`, `BEGIN` |
| 시스템 패키지 | `DBMS_*`, `UTL_*` |
| 스크립트 파일 | `@script.sql` 패턴 (내용 검증 불가 → 보수적 차단) |

허용: `SELECT`, `WITH`, `EXPLAIN`, `DESC` 만. 훅 자체 에러도 차단(fail-closed).

별도 설정 불필요 — `/plugin install ehr-yearend-harness@ehr-harness` 한 번이면 끝.

- 훅 정의: `<plugin>/hooks/hooks.json`
- 훅 스크립트: `<plugin>/scripts/db-read-only.sh` (원본 `ehr-harness` 의 동일 훅)

> 원본 `ehr-harness` 플러그인을 같이 깔아 "하네스 만들어줘" 까지 실행한 경우, 동일 훅이 타깃 프로젝트의 `.claude/hooks/` 에도 한 번 더 복사된다. 같은 검사가 두 번 도는 정도라 안전성에 문제는 없으나, 원본 플러그인을 안 쓰는 환경에서는 본 훅이 단독으로 안전장치를 제공한다.

---

## 6. 범위 제외 (Out of Scope)

- EHR4 지원. EHR5(`EHR_HR50`) 먼저.
- DB 쓰기·DDL 변경 자동화. 본 하네스는 **읽기·분석·플랜**까지만.
- 실제 코드 수정. `superpowers:writing-plans → executing-plans` 경로에 위임.

---

## 7. 7일 파일럿 계획

로컬 트래커: `docs/superpowers/plans/observations/2026-04-24-pilot-tracker.md` (gitignore 대상).

| 일차 | 작업 |
|---|---|
| D0 | 설계 + 구현 완료 ✓ |
| D1~D3 | (D0 에서 이미 끝남) |
| D4 | 실전 업무 1건 선정 |
| D5 | 하네스 투입 (에이전트로 조사 리포트 생성) |
| D6 | 회고 — 부족한 스킬/과한 출력 식별 |
| D7 | 확장 여부 결정 (후보: `yearend-year-rollover`, `yearend-calc-diagnostics`, `yearend-close-simulator`, `yearend-pdf-reflector`) |

### 7.1 성공 기준

다음 중 **2개 이상** 충족 시 2차 확장 진행.

1. 에이전트 조사 리포트가 사람 재작업 30분 이내로 납품 가능.
2. 체인 추적 결과가 실제 코드/DB 구조와 90% 이상 일치.
3. 회고에서 "이 스킬 없었으면 훨씬 느렸다" 평가.

---

## 8. 원본 플러그인과의 관계

이 레포에는 `plugins/ehr-harness/` (참고 전용 원본 플러그인)도 같이 있다.
본 하네스는 그 플러그인을 **의존하지 않는다** — 설치돼 있으면 일부 공통 스킬
(`codebase-navigator`, `procedure-tracer`, `impact-analyzer`, `db-query`)을 선택적으로 위임
호출하고, 없으면 `Grep`/`Glob` + `references/*.md` 로 자체 수행한다. 이식성 우선.

---

## 9. 커밋 이력 (MVP 완성 시점)

```
feat(scripts): add sync-to-target fallback script
test(scripts): add failing smoke test for sync-to-target
feat(scripts): add link-to-target powershell script
test(scripts): add failing smoke test for link-to-target
feat(yearend): add yearend-investigator agent
feat(yearend): add yearend-chain-tracer skill
feat(yearend): add yearend-domain-map skill
docs(yearend): add yjungsan close chain reference
docs(yearend): add yjungsan packages reference
docs(yearend): add yjungsan tables reference
chore: import ehr-harness-plugin as baseline
```
