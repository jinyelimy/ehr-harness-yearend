# ehr-yearend-harness

연말정산(`yjungsan`) 도메인 전용 Claude Code / Codex 플러그인.

> 본 플러그인은 [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin) fork 안에 들어있는 *yearend 추가 패키지* 입니다. 자세한 출처: [NOTICE.md](../../NOTICE.md)

---

## 설치

레포 루트에서 OS 에 맞는 통합 설치자를 한 번 실행한다.

**Windows (PowerShell)**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-all.ps1
```

**macOS / Linux (bash)**
```bash
bash scripts/install-all.sh
```

이 설치자는 같은 `ehr-yearend-harness` 구조를 양쪽에 동시에 적용한다.

| 대상 | 설치자가 하는 일 |
|---|---|
| Claude Code | `ehr-yearend-harness@ehr-harness-yearend` 를 user plugin 으로 enable 하고, 현재 plugin version cache 를 구성 |
| Codex | `~/.codex/config.toml` 에 local marketplace(`source` 자동 산출), plugin enable, `codex_hooks = true` 를 기록 |

실행 후 Claude Code 와 Codex 를 새로 시작하면 된다. 다시 실행해도 중복 블록을 만들지 않고 같은 상태로 갱신된다.

> Codex용 manifest 는 [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json) 이고,
> Claude용 manifest 는 [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) 이다.
>
> **수동 설치는 비권장** — 과거 안내하던 `/plugin marketplace add` (Claude) / `~/.codex/config.toml` 직접 편집 (Codex) 흐름은 경로·feature flag 누락 함정이 많아 더 이상 메인 경로로 안내하지 않는다. 양쪽 런타임을 일관되게 구성하는 *유일한 권장 경로* 는 위의 통합 설치자다.

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

## Claude와 Codex 구조 차이

Claude Code 에서는 플러그인 루트의 `skills/*/SKILL.md`, `agents/*.md`, `hooks/hooks.json` 이 convention 으로 인식된다. 그래서 [`agents/yearend-investigator.md`](agents/yearend-investigator.md) 는 Claude 에서 직접 agent 로 로딩된다.

Codex 에서는 [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json) 이 노출 경로를 선언한다. 현재 Codex manifest 는 `"skills": "./skills/"` 와 `"hooks": "./hooks/codex-hooks.json"` 만 선언하고, `agents/` 는 선언하지 않는다.

따라서 Codex 에서 `yearend-investigator`의 진입점은 [`skills/yearend-investigator/SKILL.md`](skills/yearend-investigator/SKILL.md) 이다. 이 wrapper skill 이 [`agents/yearend-investigator.md`](agents/yearend-investigator.md) 를 상세 지침으로 읽고, Claude agent 와 같은 조사 절차를 메인 Codex 흐름 안에서 실행한다.

이 구조를 택한 이유는 `yearend-investigator`가 보통 별도 병렬 작업자라기보다 후속조치 정리, 기존 반영 여부 확인, 영향 분석, 패치 플랜 초안을 만드는 **업무 절차**이기 때문이다. Codex 에서는 단일 조사 요청은 skill이 가볍고 자연스럽다. 여러 건을 각각 독립 조사자로 나눠야 할 때만 Codex native subagent 를 추가 surface 로 고려한다.

---

## 구성 요소

본 플러그인을 깔면 다음이 같이 등록·동작합니다. **별도 설정 불필요** — `/plugin install` 한 번이면 끝.

### 스킬 (자동 발동)

**`yearend-domain-map`** — 도메인 지도

> "TCPN843 이 뭐야?", "PKG_CPN_YEA_2026_SYNC 는?", "yjungsan 전체 구조" 같은 **지식 조회** 질의에서 발동. 답변은 references 사실 사전(`yjungsan-tables.md`, `yjungsan-packages.md`, `yjungsan-close-chain.md`)에 기록된 내용만 권위 출처로 사용한다 — Claude 의 일반 지식이나 추측은 사용하지 않는다. 분석·수정 X, 단순 조회용.
>
> 정의: [`skills/yearend-domain-map/SKILL.md`](skills/yearend-domain-map/SKILL.md)

**`yearend-chain-tracer`** — 영향 범위 추적 + DB 컬럼 검증 + 테스트 데이터 안내 + 고객/회사별 분기 보조 확인

> "`BefComMgr` 수정하면 어디 영향?", "`TCPN843` 컬럼 추가 시 체인", "마감에 영향 가?", "조회 쿼리 짜줘", "이 데이터 확인", "테스트 데이터 어디 있어", "고객별 분기 있나" 같은 질의에서 발동. 입력 하나(화면 / 테이블 / 프로시저 / 증상 / 고객사명)를 받아 양방향으로 추적: 화면 → 매퍼 → 테이블 → 패키지 → 결과테이블 → 마감상태. 회귀 위험까지 짚어준다.
>
> **[v0.2.0]** 쿼리 작성·컬럼 인용 전 **DB 컬럼 검증 게이트** 를 자동 수행: 매퍼 XML grep → `DESC` → references 사전 순으로 컬럼 존재 확인, 미검증 컬럼은 `⚠️ 확인 필요` 플래그. 또한 시나리오에 맞는 **테스트 데이터 위치**를 `yjungsan-test-data.md` 에서 조회해 안내한다.
>
> **[v0.3.0]** 입력에 고객사명/`선배포`/`커스텀`/`사이트별 예외` 키워드가 있으면 `yjungsan-customer-variants.md` 를 보조 reference 로 확인해 *고객/회사별 분기 가능성* 을 출력 8번 조건부 섹션으로 표시한다. 매칭이 없으면 추측하지 않고 "매칭 없음 — 추측 안 함" 으로 명시.
>
> **[v0.3.1]** *Binary 파일 fail-fast 정책* 흡수 — `.mrd`/`.pdf`/`.zip`/`.jar`/`.class` 등은 1회 시도 후 즉시 "외부 도구 필요" 표시. `strings`/hex/iconv 다단계 추출 시도 금지. `yearend-investigator` 의 Step 0 시간 가드와 연동.
>
> 분석 전용, 수정 X.
>
> 정의: [`skills/yearend-chain-tracer/SKILL.md`](skills/yearend-chain-tracer/SKILL.md)

**`yearend-plan-first`** ★ — 변경 작업 정책 (핵심 안전장치)

> "고쳐줘", "반영해줘", "hotfix 해줘" 같은 **변경 작업** 요청에서 발동. *Step 0 (현 상태 확인)* 부터 거친다 — git 이력 확인 → 도메인 동의어 확장 → 변경 흔적 grep → 트리거 단어 감지. 결과에 따라 (a) 이미 반영됐으면 위치(파일:line) + 커밋 + 추정 원인 보고 후 종료 / (b) 미반영이면 영향 분석 → plan 제시 → "이대로 진행할까요?" → 사용자 명시적 승인 → Edit/Write. **사용자 동의 없이 코드가 자동 변경되는 것을 방지** + **이미 반영된 사항을 또 고치는 헛수고를 방지**.
>
> 정의: [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md)

**`yearend-investigator`** — Codex용 조사 워크플로우 wrapper

> Codex에서는 Claude의 `agents/yearend-investigator.md` 를 별도 subagent로 띄우지 않고, 메인 Codex가 그대로 따르는 스킬로 사용한다. 후속조치/JIRA/메신저 원문 정리, 개정세법 영향도, 장애 조사, 패치 플랜 초안 작성에 사용한다. 실제 수정은 하지 않고 `yearend-plan-first` 정책으로 넘긴다.
>
> 정의: [`skills/yearend-investigator/SKILL.md`](skills/yearend-investigator/SKILL.md)

### 에이전트 (Claude Code)

**`yearend-investigator`** — 조사·플랜 초안 + 자유텍스트 후속조치 정규화

> "장애 조사해줘", "개정세법 영향도 봐줘", "출산지원금 반영 플랜 잡아줘" 같은 **서술형·복합** 요청에서 호출. 위 스킬들을 조합해 (1) 요구사항/증상 요약, (2) 도메인 영향 범위, (3) 확인한 git 이력, (4) 실행 체인, (5) 영향도 표, (6) 리스크 체크리스트, (7) 패치 플랜 초안을 한 번에 산출한다. **실제 코드/DDL 수정은 하지 않음** — 산출물은 `superpowers:writing-plans` 에 넘기는 정제된 입력. 본 에이전트도 내부적으로 plan-first 정책(Step 0 부터)을 따름.
>
> **[v0.3.0]** 엑셀/JIRA/메신저에서 복사된 **자유텍스트 후속조치 입력**을 처리한다. 단일 1건과 N건 dump 둘 다 first-class 로 지원. 정규화는 *2단 구조* (Triage 5필드 → 상세 5필드) 로 분리해 N=20 dump 도 무리 없이 소화. N 별 처리 정책(N≤3 풀 분석 / 4-10 triage 우선 / >10 triage 만)은 *기본 정책*이며 사용자 명시 지시 우선. 본 에이전트는 *router/planner* 로 작동 — 정규화·라우팅·플랜화까지가 종착점이고, 실제 수정은 `yearend-plan-first` 정책에 위임.
>
> **[v0.3.1]** Step 0 강화 — (1) **의무 사전 조회**: 회사 키워드 감지 시 `customer-variants.md`, 검증 시 `test-data.md` 를 Step 0 즉시 자동 조회하고 출력 7번에 매칭 결과 라인 의무 명시. (2) **시간 가드**: 검색 4 batch / 파일 read 5개 / binary 1회 한도, 초과 시 사용자 동의 묻고 멈춤. (3) **회사 키워드 우선 좁히기**: `*_<KEYWORD>*` 파일명 매칭 우선, 광범위 grep 진입 금지. (4) **customer-variants 슬롯 자동 등록 제안**: 회사 키워드 + 분기 코드 발견 + 사전 미등록 3조건 충족 시 출력 마지막에 자동 제안 (사용자 동의 시에만 채움).
>
> 정의: [`agents/yearend-investigator.md`](agents/yearend-investigator.md)

### 훅 (자동 등록 — `/plugin install` 한 번이면 적용)

**`db-read-only`** — DB 변경 자동 차단 (fail-closed)

> Claude Code 와 Codex 의 PreToolUse(Bash) 매처로 동작. `sqlplus` / `sqlcl` / `sqlcmd` / `tibero` / `tbsql` / `impdp` / `expdp` / `rman` 명령으로 들어가는 SQL 을 가로채서 다음을 차단한다:
>
> - DML/DDL: `DROP`, `TRUNCATE`, `DELETE`, `UPDATE`, `INSERT`, `MERGE`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `UPSERT`
> - 실행: `EXEC`, `EXECUTE`, `CALL`
> - PL/SQL 블록: `DECLARE`, `BEGIN`
> - 시스템 패키지: `DBMS_*`, `UTL_*`
> - 스크립트 파일: `@script.sql` 패턴 (내용 검증 불가 → 보수적 차단)
>
> 허용: `SELECT`, `WITH`, `EXPLAIN`, `DESC` 만. 훅 자체 에러가 발생해도 차단으로 떨어진다 (fail-closed).
>
> Claude 등록: [`hooks/hooks.json`](hooks/hooks.json), 스크립트: [`scripts/db-read-only.sh`](scripts/db-read-only.sh)  
> Codex 등록: [`hooks/codex-hooks.json`](hooks/codex-hooks.json), PowerShell 검증 스크립트: [`scripts/db-read-only.ps1`](scripts/db-read-only.ps1)

### References (사실 사전 7개)

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

**`yjungsan-tax-calc-rules.md`** — 세액 계산 규칙 (용어 정의·가산세·절사)

> 사업소세(종업원분)·원천세 등 세액 계산 시 **용어 혼동으로 인한 오계산을 방지**하기 위한 규칙 사전. 핵심: "과세급여 = 이미 비과세 제외된 금액 = 산출과표"이므로 과세제외급여를 다시 빼면 안 된다. 가산세(무신고/과소신고/납부지연) 계산식, 시기별 가산율, 경과 기간별 감면비율, 10원 미만 절사 규칙을 정리. 세액 계산 질의 시 `yearend-domain-map` 스킬이 자동 참조.
>
> 위치: [`references/yjungsan-tax-calc-rules.md`](references/yjungsan-tax-calc-rules.md)

**`yjungsan-test-data.md`** — 테스트 데이터 위치 사전 + 검증 체크리스트 템플릿

> 영향 분석·쿼리 작성 결과를 사용자가 직접 검증할 때 사용할 **테스트 데이터의 위치 인덱스**. 데이터 *내용* 이 아니라 *어디 있고 어떻게 쓰는지* 만 기록. 시나리오별 슬롯(일반/중도/재계산/외국인 분납/출산지원금/PDF 반영/마감 블로킹 등)과 표준 탐색 경로(`src/test/resources/**`, 사내 sample SQL 폴더 등)를 정리. 첫 사용 시 비어 있는 슬롯을 사용자/AI 가 점진적으로 채워간다. `yearend-chain-tracer` 의 *테스트 데이터 위치 안내* 단계에서 자동 참조. **신규 INSERT/UPDATE/DELETE 실행은 db-read-only 훅이 자동 차단** — 데이터 생성은 사용자가 수동.
>
> **[v0.3.0]** 시나리오별 *검증 체크리스트 템플릿* (퇴직소득 변경 / 출산지원금 반영 / 종전근무지 합산 / 외국인 분납) 추가. 후속조치 처리 후 누락 방지용 표준.
>
> 위치: [`references/yjungsan-test-data.md`](references/yjungsan-test-data.md)

**`yjungsan-customer-variants.md`** — 고객/회사별 분기 사전 ★ v0.3.0 신규

> 연말정산 도메인에서 고객사·회사별·그룹별 분기 로직(선배포 · 커스텀 · 예외)이 있을 *가능성* 을 탐색하기 위한 reference. 분기 사실 자체가 아니라 *어디를 먼저 봐야 하는지* 만 기록. **public repo 정책**: 기본 슬롯은 익명 고객명(`고객A`, `고객B`, …) 으로 시작하고, 실명은 사용자가 *공개 가능* 하다고 명시한 경우에만 갱신. 장애 상세, 운영 데이터, 계약 조건, 담당자명, 내부 배포 일정은 기록 X. 매칭이 없으면 추측 안 함 — 단정 표현("고객X 는 별도 로직 적용됨") 금지. `yearend-chain-tracer` 의 *고객/회사별 분기 보조 확인* 단계와 `yearend-investigator` 의 *자유텍스트 후속조치 입력 처리* 단계에서 자동 참조.
>
> 위치: [`references/yjungsan-customer-variants.md`](references/yjungsan-customer-variants.md)

---

## 후속조치 배정 건 처리 — 권장 프롬프트

후속조치 시트/JIRA/메신저에서 본인 배정 건을 복사한 뒤 Claude 또는 Codex 에게 다음 형태로 요청한다. 가장 짧게는 한 줄이면 충분하다.

```text
다음 후속조치 건 정리하고 기존 반영 여부부터 확인해줘.

<원문 붙여넣기>
```

알고 있는 정보가 있으면 아래 정도만 추가한다 (없어도 됨 — 부족하면 `yearend-investigator` 가 역질문).

```text
- 고객/회사:
- 귀속연도:
- 정산구분:
```

`yearend-investigator` 가 자유텍스트를 *Triage 5필드 → 상세 5필드* 로 정규화하고, Step 0(현 상태 확인) 부터 진행한다. **수정은 `yearend-plan-first` 정책에 따라 사용자 승인 후**. DB 는 SELECT/DESC 만 허용 (`db-read-only` 훅).

N건 dump (엑셀 행 복사 / JIRA dump) 도 그대로 붙여넣으면 된다. N 에 따라 처리 깊이가 자동 조정 (≤3 풀 분석 / 4-10 triage 우선 / >10 triage 만).

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

Claude Code:

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

Codex:

```powershell
git -C C:\yelingg\ehr-harness-yearend pull --ff-only
```

그 뒤 Codex 를 새로 시작한다. `~/.codex/config.toml` 의 marketplace `source` 가 이 clone 경로를 가리키므로 별도 `plugin update` 명령은 쓰지 않는다.

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|------|------------|
| `Plugin "ehr-yearend-harness" not found in any marketplace` | marketplace 이름은 **`ehr-harness-yearend`** (뒤가 `-yearend`). `@ehr-harness` 가 아니다. 또는 marketplace 캐시 stale → `marketplace remove` → `add` → `install` |
| `Your organization does not have access to Claude` | 본 플러그인 무관, **Claude API 인증 문제**. CLI 에서 `claude` → `/logout` → `/login` 또는 IT 문의 |
| `error: unexpected argument 'marketplace' found` | 현재 Codex CLI `0.120.0` 에는 `codex plugin marketplace add` 서브커맨드가 없다. `~/.codex/config.toml` 에 `[marketplaces.ehr-harness-yearend]` 와 `[plugins."ehr-yearend-harness@ehr-harness-yearend"]` 를 직접 추가한다. |
| Codex 에서 플러그인이 안 보임 | repo-local marketplace 를 쓰려면 `.agents/plugins/marketplace.json` 이 필요하다. 이 저장소에는 포함되어 있으므로 `~/.codex/config.toml` 의 `source` 경로가 이 저장소를 가리키는지 확인하고 Codex 를 재시작한다. |
| Codex 에서 DB 차단 hook 이 안 도는 것 같음 | Codex hooks 는 feature flag 뒤에 있다. `~/.codex/config.toml` 또는 프로젝트 `.codex/config.toml` 에 `[features] codex_hooks = true` 를 추가하고 Codex 를 재시작한다. |
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

