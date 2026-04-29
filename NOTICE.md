# NOTICE

이 프로젝트는 아래 오픈 소스 프로젝트를 기반으로 하여, 연말정산(Year-End Tax Settlement) 도메인 지식과 스킬을 보강한 파생 프로젝트입니다.

- **원본 프로젝트**: [qoxmfaktmxj/ehr-harness-plugin](https://github.com/qoxmfaktmxj/ehr-harness-plugin)
- **원 저작자**: qoxmfaktmxj

원본 저장소에는 별도의 LICENSE 파일이 명시되어 있지 않으므로, 추후 원 저작자의 라이선스 방침이 확인되면 본 NOTICE 및 관련 표기를 그에 맞추어 갱신합니다.

## 보강 사항

- `plugins/ehr-yearend-harness/` 하위에 연말정산 도메인 패키지 추가 — 스킬 3개(`yearend-domain-map` / `yearend-chain-tracer` / `yearend-plan-first`), 에이전트 1개(`yearend-investigator`), 훅 1개(`db-read-only`), references 6개(`tables` / `packages` / `close-chain` / `glossary` / `tax-calc-rules` / `test-data`)
- 소득공제·세액공제 규칙, 원천징수영수증 생성, 국세청 간소화자료 스키마 등은 점진적 보강 (PR 환영)
