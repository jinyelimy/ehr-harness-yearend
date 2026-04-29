# ehr-harness-yearend

연말정산(`yjungsan`) 도메인 보강 Claude Code 플러그인 모음.

> 본 레포는 [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin) 의 fork 입니다.
> 원본의 `ehr-harness` 플러그인은 그대로 보존하고, 그 옆에 연말정산 도메인 전용 패키지 `ehr-yearend-harness` 를 같이 묶었습니다.
> 자세한 출처: [NOTICE.md](./NOTICE.md)

---

## 무엇이 들어있나

이 레포의 marketplace(`ehr-harness-yearend`) 안에는 두 플러그인이 들어있습니다.

| 플러그인 | 역할 | 상세 매뉴얼 |
|---|---|---|
| **`ehr-yearend-harness`** ★ | 연말정산 도메인 전용 (스킬 3 + 에이전트 1 + 훅 1 + references 4) — *본 fork 의 메인 산출물* | [`plugins/ehr-yearend-harness/README.md`](./plugins/ehr-yearend-harness/README.md) |
| `ehr-harness` | EHR4/5 범용 하네스 자동 생성기 — *"하네스 만들어줘"* 한 마디로 EHR 프로젝트 분석 + 맞춤 하네스 생성 (원본 그대로) | [`plugins/ehr-harness/README.md`](./plugins/ehr-harness/README.md) |

> 두 플러그인은 코드를 합친 게 아니라 같은 marketplace 안에 *공존* 하며, 각자 독립적으로 동작합니다. 사용자는 둘 중 원하는 것만 골라 설치할 수 있습니다.

---

## `ehr-yearend-harness` 구성 요소 (요약)

| 종류 | 이름 | 한 줄 |
|------|------|------|
| 스킬 | `yearend-domain-map` | 도메인 지식 조회 ("TCPN843 이 뭐야?") |
| 스킬 | `yearend-chain-tracer` | 영향 범위 추적 ("이 컬럼 고치면 어디 영향?") |
| 스킬 | `yearend-plan-first` ★ | 변경 작업 정책 (Step 0~4, 사용자 승인 후 수정) |
| 에이전트 | `yearend-investigator` | 서술형 조사·플랜 초안 ("개정세법 영향도 봐줘") |
| 훅 | `db-read-only` (자동 등록) | DB 변경 자동 차단, `SELECT`/`WITH`/`EXPLAIN`/`DESC` 만 허용 |
| references | tables / packages / close-chain / glossary / tax-calc-rules / test-data | yjungsan 사실 사전 6개 |

> 각 컴포넌트의 자세한 발동 시점·동작·정의 위치는 [`plugins/ehr-yearend-harness/README.md`](./plugins/ehr-yearend-harness/README.md) 의 *구성 요소* 섹션 참고.

---

## 설치 — `ehr-yearend-harness` 단독 (한 줄)

타깃 EHR 프로젝트(예: `EHR_HR50`)에서 Claude Code 를 켠 뒤:

```
/plugin marketplace add https://github.com/jinyelimy/ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

> 끝의 `@ehr-harness-yearend` 는 *marketplace 이름*, 그 앞이 *플러그인 이름*. 헷갈리기 쉬우니 주의.

검증:

```
TCPN843 이 뭐야?
```

→ `yearend-domain-map` 스킬이 자동 발동해 references 기반 답변이 나오면 정상.

자세한 내부 구조 · plan-first 정책 · 트러블슈팅: [`plugins/ehr-yearend-harness/README.md`](./plugins/ehr-yearend-harness/README.md)

---

## (선택) 원본 `ehr-harness` 도 같이 쓰면

`ehr-harness` 는 EHR 프로젝트에 *범용 하네스를 자동 생성* 하는 별도 플러그인. yearend 와 같이 깔면 yearend 가 원본의 공통 스킬(`codebase-navigator`, `procedure-tracer`, `db-query` 등)을 위임 호출해 시너지가 난다.

```
/plugin install ehr-harness@ehr-harness-yearend
/plugin install superpowers@claude-plugins-official    # ehr-harness 사용 시 필수
```

원본의 자체 매뉴얼(설치·사용·프로파일·EHR Cycle 등 1100+ 줄): [`plugins/ehr-harness/README.md`](./plugins/ehr-harness/README.md)

---

## 폴더 구조

```
ehr-harness-yearend/
├── .claude-plugin/
│   └── marketplace.json              ← 두 플러그인 등록 (marketplace 이름: ehr-harness-yearend)
├── plugins/
│   ├── ehr-harness/                  ← 원본 범용 하네스 자동 생성기 v1.9.4
│   │   ├── README.md                 ← (원본) 자체 매뉴얼
│   │   ├── profiles/                 ← EHR4 / EHR5 프로파일
│   │   ├── scripts/
│   │   └── skills/
│   └── ehr-yearend-harness/          ← yearend 도메인 전용 v0.2.0
│       ├── README.md                 ← yearend 자체 안내 (단독 사용자 가이드)
│       ├── references/               ← yjungsan 사실 사전 (tables, packages, close-chain, glossary)
│       ├── skills/                   ← yearend-domain-map / yearend-chain-tracer / yearend-plan-first
│       ├── agents/                   ← yearend-investigator
│       ├── hooks/                    ← PreToolUse(Bash) 훅
│       └── scripts/                  ← db-read-only.sh
├── scripts/                           ← (개발 모드) 정션 스크립트 — TF 일반 사용자는 불필요
├── README.md                          ← 본 문서
└── NOTICE.md                          ← 원본 출처 표기
```

---

## 업데이트

```
/plugin marketplace update ehr-harness-yearend
/plugin update ehr-yearend-harness@ehr-harness-yearend
```

이게 안 먹으면:

```
/plugin uninstall ehr-yearend-harness@ehr-harness-yearend
/plugin marketplace update ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

---

## 라이선스 / 출처

원본 저장소(`qoxmfaktmxj/ehr-harness-plugin`)에 LICENSE 가 명시되어 있지 않아, 추후 원 저작자 방침 확인 후 갱신합니다. 자세한 출처와 보강 사항은 [NOTICE.md](./NOTICE.md) 참고.
