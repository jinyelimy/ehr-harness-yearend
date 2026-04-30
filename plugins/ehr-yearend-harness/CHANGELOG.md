# Changelog

본 플러그인(`ehr-yearend-harness`)의 변경 이력. 형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 약식, 버전 규칙은 [SemVer](https://semver.org/lang/ko/) 를 따른다.

> 원본 `ehr-harness` 플러그인의 변경 이력은 본 파일에 포함되지 않는다. 같은 marketplace 안의 별개 lifecycle.

---

## [0.3.0] - 2026-04-30

### Added
- `references/yjungsan-customer-variants.md` 신설 — 고객/회사별 분기 사전. 분기 사실 자체가 아니라 *어디를 먼저 봐야 하는지* 만 기록하는 탐색 사전. **public repo 정책**: 기본 슬롯은 익명 고객명(`고객A` ~ `고객E`) + 빈 슬롯, 실명은 사용자 명시 승인 시에만 갱신. 장애 상세·운영 데이터·계약 조건·담당자명·내부 배포 일정 기록 금지. 매칭 없으면 추측 안 함, 단정 표현(`고객X 는 별도 로직 적용됨`) 금지.
- `references/yjungsan-test-data.md` 에 **시나리오별 검증 체크리스트 템플릿** 추가 — 퇴직소득 변경 / 출산지원금 반영 / 종전근무지 합산 / 외국인 분납 4종. 후속조치 처리 후 누락 방지용 표준.
- `agents/yearend-investigator.md` 에 **자유텍스트 후속조치 입력 처리** 케이스 흡수 — 단일 1건과 N건 dump 둘 다 first-class. 정규화는 *2단 구조*(Triage 5필드 → 상세 5필드). N 별 처리 정책(N=1/≤3/4-10/>10)은 *기본 정책*이며 사용자 명시 지시 우선. Triage 표 형식 예시 + 보조 사전 참조 정책 명시. 출력 템플릿 7번 미확인 사항에 `고객/회사별 분기` 라인 추가.
- `agents/yearend-investigator.md` 에 *router/planner* 포지셔닝 명문화 — 후속조치 항목의 실제 수정자가 아니라 정규화·라우팅·플랜화 담당. 실제 코드 수정은 `yearend-plan-first` 정책에 위임.
- `skills/yearend-chain-tracer/SKILL.md` 에 **고객/회사별 분기 보조 확인** sub-step 흡수 — `고객별 분기` / `고객사별` / `회사별` / `선배포` / `커스텀` / `사이트별 예외` 키워드 또는 `customer-variants.md` 등록 식별자 감지 시 보조 reference 확인. 출력 8번 *조건부* 섹션 추가 (감지 + 매칭 있음일 때 정식 4줄, 감지 + 매칭 없음일 때 한 줄, 미감지 시 섹션 자체 생략).
- `skills/yearend-chain-tracer/SKILL.md` description 에 트리거 어휘 보강 (`고객별 분기`, `고객사별`, `회사별`, `선배포`, `커스텀`, `사이트별 예외`).
- 플러그인 README 에 **후속조치 배정 건 처리 — 권장 프롬프트** 섹션 추가 (담당자가 본인 배정 건을 짧게 붙여넣어 처리하는 표준 형식).

### Changed
- 루트 README / 플러그인 README / NOTICE 의 references 표기를 6개 → 7개로 동기화 (`customer-variants.md` 신설 반영). 루트 README 의 references 4↔6 혼재 표기도 정리.
- 루트 README 폴더 구조의 `v0.2.0` 표기를 `v0.3.0` 으로 갱신.
- 루트 `.claude-plugin/marketplace.json` 과 플러그인 `plugin.json` 의 `ehr-yearend-harness` 버전을 둘 다 `0.3.0` 으로 동기화.

### Notes
- 신규 스킬, 신규 훅, slash command, DB/DDL 변경 **없음**. 기존 책임을 새 컴포넌트로 만들지 않고 `yearend-investigator` 와 `yearend-chain-tracer` 에 흡수해 경량성을 유지 (v0.2.0 의 설계 철학 계승).
- `customer-variants.md` 는 출시 직후 빈 슬롯이 기본 — chain-tracer 8번 섹션은 `매칭 없음 — 추측 안 함` 한 줄 출력이 기본 동작. 슬롯은 실전 케이스로 점진 채움 (PR 환영).
- 실제 코드 수정은 여전히 `yearend-plan-first` 정책에 따라 사용자 승인 후 진행. DB 쓰기/DDL/PLSQL 실행은 `db-read-only` 훅이 차단.
- 익명화는 이름 직접 노출만 막고 업계 추측까지 차단하지는 않는다. 분기 *내용* 도 일반 코드 식별자 수준으로 유지해 차폐 강화.

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
