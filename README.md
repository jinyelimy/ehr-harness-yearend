# ehr-harness-yearend

연말정산(`yjungsan`) 도메인 보강 Claude Code / Codex 플러그인 모음.

> 본 레포는 [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin) 의 fork 입니다.
> 원본의 `ehr-harness` 플러그인은 그대로 보존하고, 그 옆에 연말정산 도메인 전용 패키지 `ehr-yearend-harness` 를 같이 묶었습니다.
> 자세한 출처: [NOTICE.md](./NOTICE.md)

---

## 무엇이 들어있나

이 레포의 marketplace(`ehr-harness-yearend`) 안에는 두 플러그인이 들어있습니다.

| 플러그인 | 역할 | 상세 매뉴얼 |
|---|---|---|
| **`ehr-yearend-harness`** ★ | 연말정산 도메인 전용 (Claude: 스킬 3 + 에이전트 1 / Codex: 스킬 4 + 훅 1 + references 7) — *본 fork 의 메인 산출물* | [`plugins/ehr-yearend-harness/README.md`](./plugins/ehr-yearend-harness/README.md) |
| `ehr-harness` | EHR4/5 범용 하네스 자동 생성기 — *"하네스 만들어줘"* 한 마디로 EHR 프로젝트 분석 + 맞춤 하네스 생성 (원본 그대로) | [`plugins/ehr-harness/README.md`](./plugins/ehr-harness/README.md) |

> 두 플러그인은 코드를 합친 게 아니라 같은 marketplace 안에 *공존* 하며, 각자 독립적으로 동작합니다. 사용자는 둘 중 원하는 것만 골라 설치할 수 있습니다.

---

## `ehr-yearend-harness` 구성 요소 (요약)

| 종류 | 이름 | 한 줄 |
|------|------|------|
| 스킬 | `yearend-domain-map` | 도메인 지식 조회 ("TCPN843 이 뭐야?") |
| 스킬 | `yearend-chain-tracer` | 영향 범위 추적 ("이 컬럼 고치면 어디 영향?") |
| 스킬 | `yearend-plan-first` ★ | 변경 작업 정책 (Step 0~4, 사용자 승인 후 수정) |
| 스킬(Codex) / 에이전트(Claude) | `yearend-investigator` | 서술형 조사·플랜 초안 ("개정세법 영향도 봐줘") |
| 훅 | `db-read-only` (자동 등록) | DB 변경 자동 차단, `SELECT`/`WITH`/`EXPLAIN`/`DESC` 만 허용 |
| references | tables / packages / close-chain / glossary / tax-calc-rules / test-data / customer-variants | yjungsan 사실 사전 7개 |

> 각 컴포넌트의 자세한 발동 시점·동작·정의 위치는 [`plugins/ehr-yearend-harness/README.md`](./plugins/ehr-yearend-harness/README.md) 의 *구성 요소* 섹션 참고.

---

## Claude와 Codex 구조 차이

Claude Code 는 플러그인 폴더 convention 으로 `skills/*/SKILL.md`, `agents/*.md`, `hooks/hooks.json` 을 인식한다. 그래서 [`agents/yearend-investigator.md`](./plugins/ehr-yearend-harness/agents/yearend-investigator.md) 는 Claude 에서 직접 agent 진입점이다.

Codex 는 [`.codex-plugin/plugin.json`](./plugins/ehr-yearend-harness/.codex-plugin/plugin.json) 에 선언된 `"skills": "./skills/"` 와 `"hooks": "./hooks/codex-hooks.json"` 을 진입점으로 본다. 이 플러그인은 Codex에 `agents/`를 직접 노출하지 않는다.

그래서 `yearend-investigator`는 Codex에서 별도 subagent가 아니라 [`skills/yearend-investigator/SKILL.md`](./plugins/ehr-yearend-harness/skills/yearend-investigator/SKILL.md) wrapper skill 로 제공된다. 이 wrapper가 기존 Claude agent 지침을 읽어 같은 조사 절차를 메인 Codex 흐름 안에서 수행한다.

이렇게 둔 이유는 단순하다. `yearend-investigator`의 주 역할은 병렬 작업자라기보다 후속조치 정리, 현 상태 확인, 영향 조사, 플랜 초안 작성이라는 **업무 절차**다. Codex에서는 이런 단일 흐름은 skill이 더 가볍고, 여러 건을 독립 조사자로 병렬 분석할 때만 native subagent가 더 어울린다.

---

## 설치 — `ehr-yearend-harness` 단독

### 한 번에 Claude + Codex 적용 (권장)

이 레포를 clone 한 뒤 설치자를 한 번 실행한다.

```powershell
git clone https://github.com/jinyelimy/ehr-harness-yearend
cd ehr-harness-yearend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-all.ps1
```

이 설치자는 같은 구조화 묶음을 양쪽 런타임에 동시에 적용한다.

| 대상 | 설치자가 하는 일 |
|---|---|
| Claude Code | `ehr-yearend-harness@ehr-harness-yearend` 를 user plugin 으로 enable 하고, 현재 plugin version cache 를 구성 |
| Codex | `~/.codex/config.toml` 에 local marketplace, plugin enable, `codex_hooks = true` 를 기록 |

실행 후 Claude Code 와 Codex 를 새로 시작하면 된다. 다시 실행해도 중복 블록을 만들지 않고 같은 상태로 갱신된다.

### 수동 설치: Claude Code

타깃 EHR 프로젝트(예: `EHR_HR50`)에서 Claude Code 를 켠 뒤:

```
/plugin marketplace add https://github.com/jinyelimy/ehr-harness-yearend
/plugin install ehr-yearend-harness@ehr-harness-yearend
```

> 끝의 `@ehr-harness-yearend` 는 *marketplace 이름*, 그 앞이 *플러그인 이름*. 헷갈리기 쉬우니 주의.

### 수동 설치: Codex

현재 확인한 Codex CLI `0.120.0` 기준으로는 `codex plugin marketplace add ...` 명령이 없다. Codex 에서는 이 저장소를 로컬 marketplace 로 읽도록 전역 설정에 등록한다.

```toml
# ~/.codex/config.toml

[marketplaces.ehr-harness-yearend]
source_type = "local"
source = 'C:\yelingg\ehr-harness-yearend'

[plugins."ehr-yearend-harness@ehr-harness-yearend"]
enabled = true
```

다른 PC나 다른 clone 경로에서는 `source` 만 해당 저장소 경로로 바꾼다. 설정 후 Codex 를 새로 시작하면 이 저장소의 Codex용 marketplace 파일([`.agents/plugins/marketplace.json`](./.agents/plugins/marketplace.json))과 plugin manifest([`plugins/ehr-yearend-harness/.codex-plugin/plugin.json`](./plugins/ehr-yearend-harness/.codex-plugin/plugin.json))를 읽는다.

DB 차단 hook 까지 쓰려면 Codex 설정에 hooks feature flag 를 켠다. 이 저장소에는 프로젝트 로컬 설정([`.codex/config.toml`](./.codex/config.toml))을 포함해 두었다. 다른 EHR 프로젝트에서 쓰려면 해당 프로젝트에도 같은 파일을 만들거나, 전역 설정(`~/.codex/config.toml`)에 추가한다.

```toml
[features]
codex_hooks = true
```

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
│   └── ehr-yearend-harness/          ← yearend 도메인 전용 v0.4.1
│       ├── README.md                 ← yearend 자체 안내 (단독 사용자 가이드)
│       ├── .codex-plugin/            ← Codex plugin manifest
│       ├── references/               ← yjungsan 사실 사전 (tables, packages, close-chain, glossary, tax-calc-rules, test-data, customer-variants)
│       ├── skills/                   ← yearend-domain-map / yearend-chain-tracer / yearend-plan-first / yearend-investigator(Codex wrapper)
│       ├── agents/                   ← yearend-investigator(Claude agent)
│       ├── hooks/                    ← Claude/Codex PreToolUse(Bash) 훅
│       └── scripts/                  ← db-read-only.sh / db-read-only.ps1
├── scripts/                           ← (개발 모드) 정션 스크립트 — TF 일반 사용자는 불필요
├── README.md                          ← 본 문서
└── NOTICE.md                          ← 원본 출처 표기
```

---

## 업데이트

Claude Code:

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

Codex:

```powershell
git -C C:\yelingg\ehr-harness-yearend pull --ff-only
```

그 뒤 Codex 를 새로 시작한다. `~/.codex/config.toml` 의 marketplace `source` 가 이 clone 경로를 가리키므로 별도 `plugin update` 명령은 쓰지 않는다.

---

## 라이선스 / 출처

원본 저장소(`qoxmfaktmxj/ehr-harness-plugin`)에 LICENSE 가 명시되어 있지 않아, 추후 원 저작자 방침 확인 후 갱신합니다. 자세한 출처와 보강 사항은 [NOTICE.md](./NOTICE.md) 참고.
