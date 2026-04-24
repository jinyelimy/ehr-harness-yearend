# yjungsan 패키지·프로시저 사전

## 연도별 패키지 — PKG_CPN_YEA_{YY}_*

### PKG_CPN_YEA_{YY}

- **책임**: 연말정산 세액 계산 엔진의 본체다. 급여·종전근무지·공제항목 집계와 세액 산식을 구현한다.
- **주요 서브프로그램**:
  - `P_CPN_YEAREND_PAYTOT` — 주현·종전 소득 합산, 비과세·보험·연금 정리
  - `P_CPN_YEAREND_TAX` — 공제·세액 산식 전개, `TCPN841`·`TCPN843` 최종값 기록
- **의존 테이블**:
  - 읽기: `TCPN813` 월별 급여, `TCPN815` 기타소득, `TCPN823` 가족, `TCPN843` 동기화된 항목값
  - 쓰기: `TCPN841` 계산결과 마스터, `TCPN843` 계산결과 상세
- **호출 관계**:
  - 호출자: `P_CPN_YEA_CLOSE`, `PKG_CPN_YEA_{YY}_EMP` (재계산 시)
  - 호출 대상: 자체 내부 서브프로그램만

### PKG_CPN_YEA_{YY}_CODE

- **책임**: 귀속연도의 기준코드·프로세스·항목 정의를 생성한다. `YearEndItemMgr` 화면이 보는 프로세스/항목의 원천이다.
- **주요 서브프로그램**:
  - `P_CPN_CODE_APPLY` — 기준코드·프로세스·항목 일괄 적용
  - `P_CPN_BASE_CODE_INS` — `TSYS005` 공통코드 INSERT
  - `P_PROGRAM_REG` — `TCPN801` 프로세스 정의 INSERT
  - `P_CHECKLIST_REG` — `TCPN803` 항목 정의 INSERT
- **의존 테이블**:
  - 읽기: 없음 (원천 생성자)
  - 쓰기: `TSYS005` 기준코드, `TCPN801` 프로세스, `TCPN803` 항목, `YEA994` 도움말 SUB
- **호출 관계**:
  - 호출자: 기준코드 초기화·연도 롤오버 시 수동 실행 또는 상위 배치
  - 호출 대상: 내부 서브프로그램만

### PKG_CPN_YEA_{YY}_DISK

- **책임**: 연말정산 신고서 및 디스크 출력 자료를 생성한다. 계산결과를 문서 양식으로 변환하는 엔진이다.
- **주요 서브프로그램**:
  - `P_PDF_MAKE` — PDF 기초자료 생성
  - `P_REPORT_MAKE` — 신고서 양식 생성
  - `P_DISK_MAKE` — 디스크 매체 생성
- **의존 테이블**:
  - 읽기: `TCPN811` 대상자, `TCPN841` 결과마스터, `TCPN843` 결과상세, `TCPN851` PDF기초
  - 쓰기: `TCPN851` PDF기초자료, `TCPN855` PDF파일정보
- **호출 관계**:
  - 호출자: 신고서 생성 배치, 디스크 작성 시 수동 실행
  - 호출 대상: 내부 서브프로그램만

### PKG_CPN_YEA_{YY}_EMP

- **책임**: 연말정산 대상자 재생성·재계산 관리다. 특정 대상자 또는 정산구분 세트를 처음부터 다시 만든다.
- **주요 서브프로그램**:
  - `P_MAIN` — 재계산 통합 진입점
  - `DELETE_DATA` — `TCPN811`, `TCPN813`, `TCPN815`, `TCPN843` 삭제
  - `INSERT_DATA` — 종전/주현 자료 재설정
  - `CALC_DATA` — `P_CPN_YEAREND_TAX` 호출 후 재계산 수행
- **의존 테이블**:
  - 읽기: `TCPN811` 상태 보존용, `TCPN816` 인정상여
  - 쓰기: `TCPN811` 상태 유지, `TCPN813`, `TCPN815`, `TCPN843` 재작성
- **호출 관계**:
  - 호출자: `P_CPN_YEA_CLOSE`, 개별 대상자 재계산 화면
  - 호출 대상: `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_TAX`

### PKG_CPN_YEA_{YY}_ERRCHK

- **책임**: 연말정산 오류검증을 수행한다. 계산 후 마감 가능 여부를 판정하는 품질 게이트다.
- **주요 서브프로그램**:
  - `ERROR_CHK` — 전체 대상자 검증 수행
  - `ERROR_INS` — 오류 한 건 등록
- **의존 테이블**:
  - 읽기: `TCPN811` 대상자, `TCPN813` 급여, `TCPN815` 기타소득, `TCPN817` 종전근무지, `TCPN818` 종전근무지 상세, `TCPN823` 가족, `TCPN843` 결과상세
  - 쓰기: `TCPN849` 오류검증결과
- **호출 관계**:
  - 호출자: `P_CPN_YEA_CLOSE`
  - 호출 대상: 내부 서브프로그램만

### PKG_CPN_YEA_{YY}_SYNC

- **책임**: 원천자료를 항목별 계산결과상세 `TCPN843`으로 동기화한다. 가족·의료·교육·카드·보험·기부금·주택 자료를 표준화하는 변환기다.
- **주요 서브프로그램**:
  - `TCPN843_INS` — 항목 기초 행 생성
  - `FAMILY_INS` — 가족정보 `TCPN823` → `TCPN843`
  - `MEDICAL_INS` — 의료비 `TCPN825` → `TCPN843`
  - `EDUCATION_INS` — 교육비 `TCPN829` → `TCPN843`
  - `DONATION_INS` — 기부금 `TCPN827` → `TCPN843`
  - `HOUSE_SAVING_INS` — 주택자금 `TCPN839` → `TCPN843`
  - `MTH_RENT_INS` — 월세 `TCPN839` → `TCPN843`
  - `CARDS_INS` — 카드사용 `TCPN821` → `TCPN843`
  - `INSURANCE_INS` — 보험 `TCPN828` → `TCPN843`
  - `PENSION_INS` — 연금저축 `TCPN830` → `TCPN843`
  - `CHILD_BIRTH_INS` — 출산지원금 `TCPN887` + 근속기간 → `TCPN843`
- **의존 테이블**:
  - 읽기: `TCPN813` 급여, `TCPN815` 기타소득, `TCPN817`·`TCPN818` 종전근무지, `TCPN821` 카드, `TCPN823` 가족, `TCPN825` 의료비, `TCPN827` 기부금, `TCPN828` 보험, `TCPN829` 교육비, `TCPN830` 연금저축, `TCPN839` 주택자금, `TCPN887` 출산지원금
  - 쓰기: `TCPN843` 계산결과 상세
- **호출 관계**:
  - 호출자: 원천자료 동기화 배치, 각 원천 항목 추가·수정 시
  - 호출 대상: 내부 서브프로그램만

## 독립 프로시저

### P_CPN_YEAREND_EMP

- **책임**: 연말정산 대상자 생성 및 기본 결과상세 초기화다.
- **주요 서브프로그램**:
  - 없음 (단일 프로시저)
- **의존 테이블**:
  - 읽기: `TCPN811` (기존 상태), `THRM100` 사원기본
  - 쓰기: `TCPN811` 대상자 생성, `TCPN843` 기본 항목행 생성
- **호출 관계**:
  - 호출자: 대상자 초기화 배치, 연도 롤오버 시
  - 호출 대상: 내부 UPDATE/INSERT 문만

### P_CPN_YEAREND_MONPAY_{YY}

- **책임**: 급여 원천과 기타소득 원천을 생성하는 월별·연간 원천 적재 프로시저다. 계산 이전의 원천소득 데이터 준비 단계다.
- **주요 서브프로그램**:
  - 없음 (단일 프로시저)
- **의존 테이블**:
  - 읽기: `TCPN811` 대상자, `TCPN816` 인정상여, 급여 원천 (외부 시스템 연동)
  - 쓰기: `TCPN813` 월별 급여, `TCPN815` 기타소득, 호출 후 `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_PAYTOT` 실행
- **호출 관계**:
  - 호출자: 원천 적재 배치
  - 호출 대상: `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_PAYTOT`

### P_CPN_YEA_CLOSE

- **책임**: 입력 마감 처리의 오케스트레이터다. 계산·검증·마감을 순차 제어한다.
- **주요 서브프로그램**:
  - 없음 (오케스트레이터)
- **의존 테이블**:
  - 읽기: `TCPN849` 오류 검증결과
  - 쓰기: `TCPN811.INPUT_CLOSE_YN = 'Y'` (오류 없을 시)
- **호출 관계**:
  - 호출자: 마감 버튼 클릭 (화면)
  - 호출 대상: `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_TAX`, `PKG_CPN_YEA_{YY}_EMP.P_MAIN`, `PKG_CPN_YEA_{YY}_ERRCHK.ERROR_CHK`

### P_CPN_YEA_CLOSE_ALL

- **책임**: 여러 연도 또는 다중 정산구분 대상자를 일괄 마감한다. `P_CPN_YEA_CLOSE`의 배치 버전이다.
- **주요 서브프로그램**:
  - 없음 (배치 루프)
- **의존 테이블**:
  - 읽기: `TCPN811` 다중 행
  - 쓰기: `TCPN811.INPUT_CLOSE_YN` (각 행별)
- **호출 관계**:
  - 호출자: 일괄 마감 배치
  - 호출 대상: `P_CPN_YEA_CLOSE` (반복 호출)

### P_CPN_YEA_RESULT_CONFIRM

- **책임**: 본인 결과확인 완료 처리다.
- **주요 서브프로그램**:
  - 없음 (단일 프로시저)
- **의존 테이블**:
  - 읽기: `TCPN811` (현재 상태)
  - 쓰기: `TCPN811.RESULT_CONFIRM_YN = 'Y'`
- **호출 관계**:
  - 호출자: 결과확인 버튼 클릭 (화면)
  - 호출 대상: 없음

### P_CPN_YEA_PDF_ERRCHK_{YY}

- **책임**: PDF 기초자료와 파일정보를 검증한다. 양식코드별 유효성과 가족정보 대조를 수행한다.
- **주요 서브프로그램**:
  - 없음 (단일 프로시저)
- **의존 테이블**:
  - 읽기: `TCPN851` PDF기초자료, `TCPN855` PDF파일정보, `TCPN823` 가족정보
  - 쓰기: `TCPN851`·`TCPN855`의 `STATUS_CD`·`ERROR_LOG` 업데이트
- **호출 관계**:
  - 호출자: PDF 업로드 후 검증 배치
  - 호출 대상: `P_CPN_YEA_PDF_ERRUPD_{YY}` (필요 시)

### P_CPN_YEA_PDF_ERRUPD_{YY}

- **책임**: 검증된 PDF 자료를 실제 연말정산 원천자료로 반영한다. PDF 자료 → 원천테이블 최종 변환 단계다.
- **주요 서브프로그램**:
  - 없음 (오케스트레이터)
- **의존 테이블**:
  - 읽기: `TCPN851` PDF기초자료
  - 쓰기: `TCPN815`, `TCPN817`, `TCPN818`, `TCPN821`, `TCPN825`, `TCPN827`, `TCPN828`, `TCPN829`, `TCPN830`, `TCPN839`, `TCPN843` (각 원천 자료 반영)
- **호출 관계**:
  - 호출자: `P_CPN_YEA_PDF_ERRCHK_{YY}` (검증 성공 시)
  - 호출 대상: `PKG_CPN_YEA_{YY}_SYNC`의 각 서브프로그램 (`EDUCATION_INS`, `PENSION_INS`, `CARDS_INS`, `HOUSE_SAVING_INS`, `MTH_RENT_INS`, `DONATION_INS`, `FAMILY_INS` 등)

## 연도 연동 규칙

### {YY} 플레이스홀더 치환

패키지·프로시저 명칭의 `{YY}` 부분은 **귀속 연도의 4자리** 로 치환된다.

예: 2026 귀속 → `PKG_CPN_YEA_2026`, `P_CPN_YEAREND_MONPAY_2026`

### 연도 롤오버 메커니즘

새로운 연도가 도래하면 `PKG_CPN_YEA_{이전연도}_CODE`에서 기준코드·항목을 복사하여 `PKG_CPN_YEA_{신규연도}_CODE`의 입력으로 제공한다. 즉 CODE 패키지가 **연도별 포워드 복사** 역할을 담당한다.

### 2026 귀속 구체 사례

2026 귀속 연말정산 업무는 다음 6개 패키지 + 7개 독립 프로시저로 구성된다:

**패키지:**
- `PKG_CPN_YEA_2026` (본체 세액 계산)
- `PKG_CPN_YEA_2026_CODE` (기준코드 생성 및 연도 전개)
- `PKG_CPN_YEA_2026_DISK` (신고서·디스크 생성)
- `PKG_CPN_YEA_2026_EMP` (대상자 재생성·재계산)
- `PKG_CPN_YEA_2026_ERRCHK` (오류검증)
- `PKG_CPN_YEA_2026_SYNC` (원천자료 동기화)

**독립 프로시저:**
- `P_CPN_YEAREND_EMP` (대상자 초기생성)
- `P_CPN_YEAREND_MONPAY_2026` (월별 급여·기타소득 적재)
- `P_CPN_YEA_CLOSE` (마감 오케스트레이션)
- `P_CPN_YEA_CLOSE_ALL` (일괄 마감)
- `P_CPN_YEA_RESULT_CONFIRM` (본인결과확인)
- `P_CPN_YEA_PDF_ERRCHK_2026` (PDF 검증)
- `P_CPN_YEA_PDF_ERRUPD_2026` (PDF 반영)

이들은 **기준코드 생성 → 대상자·원천 적재 → 원천 동기화 → 세액 계산 → 오류검증 → 마감** 순서로 실행된다.
