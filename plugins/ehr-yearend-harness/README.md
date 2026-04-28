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

## 무엇이 같이 깔리나

| 종류 | 이름 | 발동 시점 / 역할 |
|------|------|-----------------|
| 스킬 | `yearend-domain-map` | "TCPN843 이 뭐야?", "마감 체인 정리" 같은 **지식 조회** |
| 스킬 | `yearend-chain-tracer` | "이 컬럼 추가하면 어디 영향?" 같은 **영향 범위** 추적 |
| 스킬 | `yearend-plan-first` | "이거 고쳐줘", "반영해줘" 같은 **변경 작업** 시 Step 0 ~ 4 가이드 |
| 에이전트 | `yearend-investigator` | "장애 조사해줘", "개정세법 영향도 봐줘" 같은 **서술형·복합** 요청 |
| 훅 | `db-read-only` (자동 등록) | `sqlplus`/`sqlcl` 등으로 들어가는 SQL 중 DML/DDL/PL-SQL 차단, SELECT 만 허용 |
| references (4개) | `tables`, `packages`, `close-chain`, `glossary` | yjungsan 테이블·패키지·마감 체인·동의어 사전 |

별도 설정 불필요 — `/plugin install` 한 번이면 위가 다 자동 등록·동작.

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

---

## 부록: 직접 살펴볼 파일

- 스킬 정의: [`skills/yearend-domain-map/SKILL.md`](skills/yearend-domain-map/SKILL.md), [`skills/yearend-chain-tracer/SKILL.md`](skills/yearend-chain-tracer/SKILL.md), [`skills/yearend-plan-first/SKILL.md`](skills/yearend-plan-first/SKILL.md)
- 에이전트: [`agents/yearend-investigator.md`](agents/yearend-investigator.md)
- 훅: [`hooks/hooks.json`](hooks/hooks.json), [`scripts/db-read-only.sh`](scripts/db-read-only.sh)
- 도메인 사전: [`references/`](references/) (4개 파일)
