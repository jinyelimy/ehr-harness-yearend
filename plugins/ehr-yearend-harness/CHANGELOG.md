# Changelog

본 플러그인(`ehr-yearend-harness`)의 변경 이력. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 약식, 버전 규칙은 [SemVer](https://semver.org/lang/ko/) 를 따른다.

> 원본 `ehr-harness` 플러그인의 변경 이력은 본 파일에 포함되지 않는다. 같은 marketplace 안의 별개 lifecycle.

---

## [0.2.0] - 2026-04-29

### Added
- `references/yjungsan-test-data.md` — 테스트 데이터 위치 사전 신설. 시나리오 슬롯(일반·중도·재계산·외국인분납·출산지원금·PDF반영·마감블로킹) + 표준 탐색 경로(`src/test/resources/**`, 사내 sample SQL 폴더 등) + 슬롯 채우기 규칙. 첫 사용 시 사용자/AI 가 점진적으로 채워가는 설계.
- `yearend-chain-tracer` 에 **DB 컬럼 검증 게이트** 흡수. 쿼리 작성·컬럼 인용 전 매퍼 XML grep → `DESC` → references 사전 순으로 컬럼 검증, 미검증 컬럼은 `⚠️ 확인 필요` 플래그.
- `yearend-chain-tracer` 에 **테스트 데이터 위치 안내** sub-step 흡수. 시나리오에 맞는 fixture/sample 위치를 `yjungsan-test-data.md` 에서 조회.
- `yearend-chain-tracer` description 에 트리거 어휘 추가: "조회 쿼리 짜줘", "이 데이터 확인", "테스트 데이터 어디 있어".
- `yearend-chain-tracer` 출력 형식에 6·7번 섹션(검증된 컬럼·테스트 데이터 위치) 추가.

### Changed
- 루트 README / plugin README / NOTICE 의 references 표기를 5개 → 6개로 동기화 (`test-data.md` 신설 반영).
- NOTICE 의 "추가 예정" 표현을 현재 상태(스킬 3 + 에이전트 1 + 훅 1 + references 6)로 교체.
- `references/yjungsan-glossary.md` 의 `{YY} = 25, 26` 표현이 `packages.md` 의 "4자리 치환 규칙"과 모순이라 정정 + `packages.md` 참조 링크 추가.

### Notes
- 컴포넌트 수는 그대로 유지 (스킬 3 + 에이전트 1 + 훅 1). 새 책임 2개를 신규 스킬·훅 신설 없이 기존 `yearend-chain-tracer` 에 흡수해 경량성 유지.
- DB 변경/실행은 여전히 `db-read-only` 훅이 자동 차단. 신규 INSERT/UPDATE/DELETE 는 사용자 수동.

---

## [0.1.0] - 초기 공개

### Added
- 스킬 3개:
  - `yearend-domain-map` — 도메인 지식 조회 (참조형, 동작 없음)
  - `yearend-chain-tracer` — 화면·테이블·프로시저 양방향 영향 범위 추적
  - `yearend-plan-first` — 변경 작업 정책 (Step 0 현 상태 확인 → 사용자 명시 승인 후 수정)
- 에이전트 1개: `yearend-investigator` — 서술형 복합 조사·플랜 초안 산출
- 훅 1개: `db-read-only` — PreToolUse Bash matcher, `sqlplus`/`sqlcl`/`tibero` 등에서 DML/DDL/PL-SQL/시스템 패키지 키워드 감지 차단, fail-closed
- references 5개: `yjungsan-tables.md`, `yjungsan-packages.md`, `yjungsan-close-chain.md`, `yjungsan-glossary.md`, `yjungsan-tax-calc-rules.md`
