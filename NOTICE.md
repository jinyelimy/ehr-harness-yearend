# NOTICE

이 프로젝트는 아래 오픈 소스 프로젝트를 기반으로 하여, 연말정산(Year-End Tax Settlement) 도메인 지식과 스킬을 보강한 파생 프로젝트입니다.

- **원본 프로젝트**: [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin)
- **원 저작자**: qoxmfaktmxj

## 라이선스

본 fork 전체가 **MIT 라이선스** 하에 배포됩니다. 원본과 본 fork 추가분 모두 MIT 입니다.

### 원본 자산 — MIT (Copyright © 2026 김민석)

`plugins/ehr-harness/` 는 원본 저장소(`qoxmfaktmxj/ehr-harness-plugin`)에서 가져온 자산이며, 원본의 [LICENSE](https://github.com/qoxmfaktmxj/ehr-harness-plugin/blob/main/LICENSE)에 따라 MIT 라이선스로 배포됩니다. 원 저작자 표기(Copyright © 2026 김민석)는 그대로 유지됩니다.

### 본 fork 추가분 — MIT (Copyright © 2026 yelim-jin)

루트 [`LICENSE`](./LICENSE) 의 MIT 라이선스는 yelim-jin 이 본 fork 에서 새로 작성한 다음 파일에 적용됩니다.

- `plugins/ehr-yearend-harness/` — 연말정산 도메인 패키지 전체
- `scripts/install-all.ps1`, `scripts/install-all.sh`, `scripts/bump-version.ps1`
- `scripts/tests/` — 본 fork 에서 추가한 테스트 헬퍼
- `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json` 의 yearend 항목
- `LICENSE`, `NOTICE.md`, `README.md`
- `.codex/config.toml`

두 부분 모두 MIT 이므로, 본 fork 전체를 MIT 조건(저작권 표기 + 라이선스 전문 동봉) 하에 자유롭게 사용·수정·재배포할 수 있습니다.

## 보강 사항

- `plugins/ehr-yearend-harness/` 하위에 연말정산 도메인 패키지 추가 — Claude용 스킬 3개(`yearend-domain-map` / `yearend-chain-tracer` / `yearend-plan-first`) + 에이전트 1개(`yearend-investigator`), Codex용 스킬 4개(`yearend-investigator` wrapper 포함), 훅 1개(`db-read-only`), references 7개(`tables` / `packages` / `close-chain` / `glossary` / `tax-calc-rules` / `test-data` / `customer-variants`)
- `scripts/install-all.ps1` / `scripts/install-all.sh` — Claude 와 Codex 양쪽 런타임을 한 번에 idempotent 하게 구성하는 repo-level installer
- 소득공제·세액공제 규칙, 원천징수영수증 생성, 국세청 간소화자료 스키마 등은 점진적 보강 (PR 환영)
