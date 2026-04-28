# ehr-yearend-harness

연말정산(`yjungsan`) 도메인 전용 Claude Code 플러그인.

> 본 플러그인은 [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin) fork 안에 들어있는 *yearend 추가 패키지* 입니다. 자세한 출처: [NOTICE.md](../../NOTICE.md)

---

## 설치 (한 줄)

타깃 EHR 프로젝트(예: `EHR_HR50`)에서 Claude Code 를 켠 뒤:

```
/plugin marketplace add https://github.com/jinyelimy/ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

> 끝의 `@ehr-harness-yearend` 는 *marketplace 이름*, 그 앞이 *플러그인 이름* 이다.

## 검증

```
TCPN843 이 뭐야?
```

→ `yearend-domain-map` 스킬이 자동 발동해서 references 기반 답변이 나오면 설치 정상.

차단 훅도 함께 검증:

```
sqlplus 로 "DELETE FROM TCPN843 WHERE 1=1" 실행해봐
```

→ `⛔ DB 변경/실행 SQL 감지: DELETE` 메시지로 차단되어야 정상.

---

## 구성 요소

본 플러그인을 깔면 다음이 같이 등록·동작합니다. **별도 설정 불필요** — `/plugin install` 한 번이면 끝.

### 스킬 (자동 발동)

**`yearend-domain-map`** — 도메인 지도

> "TCPN843 이 뭐야?", "PKG_CPN_YEA_2026_SYNC 는?", "yjungsan 전체 구조" 같은 **지식 조회** 질의에서 발동. 답변은 references 사실 사전(`yjungsan-tables.md`, `yjungsan-packages.md`, `yjungsan-close-chain.md`)에 기록된 내용만 권위 출처로 사용한다 — Claude 의 일반 지식이나 추측은 사용하지 않는다. 분석·수정 X, 단순 조회용.
>
> 정의: [`skills/yearend-domain-map/SKILL.md`](skills/yearend-domain-map/SKILL.md)

**`yearend-chain-tracer`** — 영향 범위 추적

> "`BefComMgr` 수정하면 어디 영향?", "`TCPN843` 컬럼 추가 시 체인", "마감에 영향 가?" 같은 **영향 범위** 질의에서 발동. 입력 하나(화면 / 테이블 / 프로시저 / 증상)를 받아 양방향으로 추적: 화면 → 매퍼 → 테이블 → 패키지 → 결과테이블 → 마감상태. 회귀 위험까지 짚어준다. 분석 전용, 수정 X.
>
> 정의: [`skills/yearend-chain-tracer/SKILL.md`](skills/yearend-chain-tracer/SKILL.md)

**`yearend-plan-first`** ★ — 변경 작업 정책 (핵심 안전장치)

> "고쳐줘", "반영해줘", "hotfix 해줘" 같은 **변경 작업** 요청에서 발동. *Step 0 (현 상태 확인)* 부터 거친다 — git 이력 확인 → 도메인 동의어 확장 → 변경 흔적 grep → 트리거 단어 감지. 결과에 따라 (a) 이미 반영됐으면 위치(파일:line) + 커밋 + 추정 원인 보고 후 종료 / (b) 미반영이면 영향 분석 → plan 제시 → "이대로 진행할까요?" → 사용자 명시적 승인 → Edit/Write. **사용자 동의 없이 코드가 자동 변경되는 것을 방지** + **이미 반영된 사항을 또 고치는 헛수고를 방지**.
>
> 정의: [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md)

### 에이전트

**`yearend-investigator`** — 조사·플랜 초안

> "장애 조사해줘", "개정세법 영향도 봐줘", "출산지원금 반영 플랜 잡아줘" 같은 **서술형·복합** 요청에서 호출. 위 스킬들을 조합해 (1) 요구사항/증상 요약, (2) 도메인 영향 범위, (3) 확인한 git 이력, (4) 실행 체인, (5) 영향도 표, (6) 리스크 체크리스트, (7) 패치 플랜 초안을 한 번에 산출한다. **실제 코드/DDL 수정은 하지 않음** — 산출물은 `superpowers:writing-plans` 에 넘기는 정제된 입력. 본 에이전트도 내부적으로 plan-first 정책(Step 0 부터)을 따름.
>
> 정의: [`agents/yearend-investigator.md`](agents/yearend-investigator.md)

### 훅 (자동 등록 — `/plugin install` 한 번이면 적용)

**`db-read-only`** — DB 변경 자동 차단 (fail-closed)

> Claude Code 의 PreToolUse(Bash) 매처로 동작. `sqlplus` / `sqlcl` / `sqlcmd` / `tibero` / `tbsql` / `impdp` / `expdp` / `rman` 명령으로 들어가는 SQL 을 가로채서 다음을 차단한다:
>
> - DML/DDL: `DROP`, `TRUNCATE`, `DELETE`, `UPDATE`, `INSERT`, `MERGE`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `UPSERT`
> - 실행: `EXEC`, `EXECUTE`, `CALL`
> - PL/SQL 블록: `DECLARE`, `BEGIN`
> - 시스템 패키지: `DBMS_*`, `UTL_*`
> - 스크립트 파일: `@script.sql` 패턴 (내용 검증 불가 → 보수적 차단)
>
> 허용: `SELECT`, `WITH`, `EXPLAIN`, `DESC` 만. 훅 자체 에러가 발생해도 차단으로 떨어진다 (fail-closed). 사용자가 `.claude/settings.json` 을 손댈 필요 없음.
>
> 등록: [`hooks/hooks.json`](hooks/hooks.json), 스크립트: [`scripts/db-read-only.sh`](scripts/db-read-only.sh)

### References (사실 사전 4개)

스킬·에이전트가 답변할 때 *권위 있는 출처* 로 사용하는 사전. 사람이 직접 읽어도 도메인 빠른 학습용으로 유용하다.

**`yjungsan-tables.md`** — 테이블 22개 사전

> 연말정산 핵심 테이블(`TCPN8##`, `TYEA8##`) 의 컬럼·키·용도. 5 레이어(기준코드 / 대상자·상태 / 원천자료 / 계산결과 / 오류검증·PDF) 별로 분류되어 있어, 어느 레이어에 무슨 객체가 있는지 한 눈에 파악 가능.
>
> 위치: [`references/yjungsan-tables.md`](references/yjungsan-tables.md)

**`yjungsan-packages.md`** — 패키지 6개 + 독립 프로시저 7개 사전

> Oracle 패키지(`PKG_CPN_YEA_{YY}_SYNC`, `_CALC`, `_EMP` 등) 와 독립 프로시저(`P_CPN_YEA_CLOSE`, `P_YEA_EMPDC_INS` 등)의 책임 분담·호출 관계. 어느 패키지가 어느 테이블을 읽고 쓰는지, 마감 체인이 어떻게 흐르는지 정리.
>
> 위치: [`references/yjungsan-packages.md`](references/yjungsan-packages.md)

**`yjungsan-close-chain.md`** — 마감 체인 상세

> `P_CPN_YEA_CLOSE` 마감 절차의 단계·게이트·상태(`INPUT_CLOSE_YN`)·재계산(`ADJUST_TYPE='88'`) 흐름. "마감 후에 이걸 고치면 되돌아가는가?" 같은 질문의 답이 여기 있다.
>
> 위치: [`references/yjungsan-close-chain.md`](references/yjungsan-close-chain.md)

**`yjungsan-glossary.md`** — 표면 표현 ↔ 코드 식별자 동의어 사전

> 사용자가 자연어로 던진 키워드(예: "사업장코드")를 코드 식별자(`BUSINESS_PLACE_CD`, `BP_CD`, `ENTER_CD`, `F_COM_GET_BP_CD`)로 확장하는 매핑. 추가로 *변경 흔적 패턴*(`(YYYY.MM.DD)`, `// 추가`)과 *트리거 단어*("추가", "이미", "개선") 도 정리. `yearend-plan-first` / `yearend-investigator` 의 Step 0-B (도메인 동의어 확장)·Step 0-C (변경 흔적 grep)·Step 0-D (트리거 단어 감지) 에서 사용된다. 누락된 동의어는 점진적으로 추가.
>
> 위치: [`references/yjungsan-glossary.md`](references/yjungsan-glossary.md)

---

## Plan-First 정책 (변경 작업 시 자동 발동)

yearend 도메인의 코드/DDL/스키마 변경 요청은 자동으로 다음 흐름:

```
사용자 요청
    │
    ▼
[Step 0] 현 상태 확인 (git 이력 + 동의어 확장 + 변경 흔적 grep + 트리거 단어)
    │
    ├─ 이미 반영됨 → 위치(파일:line) + 커밋 + 추정 원인 보고 후 종료 (수정 X)
    │
    └─ 반영 안 됨
            │
            ▼
        [Step 1] 영향 분석
        [Step 2] 변경 plan 제시
        [Step 3] 사용자 명시적 승인 ("이대로 진행할까요?")
        [Step 4] Edit/Write + 검증 가이드
```

목적: (1) 사용자 동의 없이 코드가 자동 수정되는 것 방지, (2) 이미 반영된 사항을 또 고치는 헛수고 방지.

> 우회: 진짜 비상 시 사용자가 직접 `Edit`/`Write` 도구를 호출하거나 메시지에 `[plan-first 우회]` 라고 명시한 경우.

자세한 절차는 [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md) 참고.

---

## 업데이트

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

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|------------|
| `Plugin "ehr-yearend-harness" not found in any marketplace` | marketplace 이름은 **`ehr-harness-yearend`** (뒤가 `-yearend`). `@ehr-harness` 가 아니다. 또는 marketplace 캐시 stale → `marketplace remove` → `add` → `install` |
| `Your organization does not have access to Claude` | 본 플러그인 무관, **Claude API 인증 문제**. CLI 에서 `claude` → `/logout` → `/login` 또는 IT 문의 |
| IntelliJ Claude Code 에서 스킬이 발동 안 함 | IntelliJ 익스텐션이 marketplace plugin 을 일부만 인식할 가능성. CLI/Desktop App 에서 비교 검증 |
| `db-read-only` 훅이 정상 SELECT 까지 차단 | 컬럼명에 `CREATE_DATE`, `UPDATE_TM` 등이 들어 있으면 false positive 가능. issue 로 알려주면 정밀화 |

---

## (선택) `ehr-harness` 원본 플러그인과 같이 쓰면

본 fork 의 marketplace 안에는 원본 `ehr-harness` (EHR4/5 *범용* 하네스 자동 생성기) 도 같이 들어있다. 같이 깔면 yearend 가 원본의 공통 스킬(`codebase-navigator`, `procedure-tracer`, `db-query` 등)을 *위임 호출* 하여 시너지가 난다.

같이 깔고 싶다면 한 줄 추가:

```
/plugin install ehr-harness@ehr-harness-yearend
/plugin install superpowers@claude-plugins-official    # ehr-harness 사용 시 필수
```

원본 사용법은 [루트 README 의 본 매뉴얼](../../README.md) 참고.

