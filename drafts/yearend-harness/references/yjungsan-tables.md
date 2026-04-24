# yjungsan 테이블 사전

연말정산(`yjungsan`) 도메인에서 운용되는 Oracle 테이블을 레이어별로 정리한다.
**테이블명은 연도 불변**이다 (예: `TCPN811`은 2024·2025·2026 귀속 모두 동일 테이블).
연도별 차이는 `WORK_YY` 컬럼 값으로 구분한다.

출처: 분석 문서 `EHR_HR50/docs/records/연말정산_yjungsan_소스_DB_상세분석_20260423.md` §5.

---

## 기준/정의 테이블

### TCPN801 — 연말정산프로세스코드

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJ_PROCESS_CD`
- **용도**: 귀속연도별 연말정산 프로세스(단계) 정의. `YearEndItemMgr` 화면의 상단 목록 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_CODE.P_CPN_CODE_APPLY` (프로세스 정의 INSERT), `YearEndItemMgrController` (운영 화면 수정)

### TCPN803 — 연말정산항목코드

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJ_ELEMENT_CD`
- **용도**: 프로세스 내부 항목 정의. 과세/비과세 판정(`F_CPN_YEA_TAX_YN`) 기준 데이터.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_CODE.P_CPN_CODE_APPLY`

---

## 대상자/상태 테이블

### TCPN811 — 연말정산대상자관리

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`
- **용도**: 연말정산 대상자의 진행상태(입력마감, 확인, 최종마감), 주택소유/외국인/분납 등 계산 조건을 모두 보유. 가장 중심이 되는 마스터 테이블.
- **업데이트 주체**: `P_CPN_YEAREND_EMP`, `P_CPN_YEA_CLOSE`, `P_CPN_YEA_RESULT_CONFIRM`, `BefComMgrController` (화면 수정)

### TCPN884 — 연말정산재계산대상자관리

- **PK**: `ENTER_CD`, `WORK_YY`, `SABUN`, `ADJUST_TYPE`
- **용도**: 2024 귀속 이후 추가된 재계산 대상자 관리 테이블.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_EMP` (재계산 대상자 관리)

---

## 원천/입력 테이블

### TCPN813 — 연간급여지급내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `YM`
- **용도**: 월별 급여/상여/세금/보험 원천 자료. 연말정산 계산의 기초가 되는 월별 급여 집계.
- **업데이트 주체**: `P_CPN_YEAREND_MONPAY_{YY}`, `YearIncomeMgrController`

### TCPN815 — 기타소득관리

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `YM`, `ADJ_ELEMENT_CD`
- **용도**: 월별 기타소득/비과세 항목 상세. 과세/비과세 구분과 적용 메모 포함.
- **업데이트 주체**: `P_CPN_YEAREND_MONPAY_{YY}`, `YearIncomeMgrController`

### TCPN817 — 종전근무소득관리

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 연도 내 전직한 경우 종전 직장의 급여 소득 기록. 주현급여와 합산하여 연간소득 계산.
- **업데이트 주체**: `BefComMgrController` (화면), `BefComUpldController` (업로드)

### TCPN818 — 종전근무지비과세관리

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`, `ADJ_ELEMENT_CD`
- **용도**: 종전 직장의 비과세/기타소득 상세. `TCPN817`의 하위 항목 관리.
- **업데이트 주체**: `BefComMgrController` (화면), 레거시 `befYearEtcMgrRst.jsp`

### TCPN821 — 연간카드사용내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 신용카드/직불카드 사용 기록. 신용카드 소득공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC` (PDF 반영), `P_CPN_YEA_PDF_ERRUPD_{YY}` (PDF 검증 후 적용)

### TCPN823 — 정산가족사항

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `FAMRES`
- **용도**: 연말정산 대상 가족(배우자/자녀/부양가족) 기본 정보.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.FAMILY_INS`, PDF 반영 프로세스

### TCPN825 — 정산가족의료비내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 가족 의료비 지출 내역. 의료비 공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.MEDICAL_INS`, PDF 반영

### TCPN827 — 기부금내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 법정기부금/지정기부금/종교기부금 기록. 기부금 공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.DONATION_INS`, PDF 반영

### TCPN828 — 보험금내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 보험료(건강보험/장기요양/고용보험) 납입 기록.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.INSURANCE_INS`, PDF 반영

### TCPN829 — 교육비내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 본인/배우자/자녀 교육비 지출 기록. 교육비 공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.EDUCATION_INS`, PDF 반영

### TCPN830 — 연금저축등소득공제내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 개인연금저축/DC/IRP 납입액 기록. 연금저축 소득공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.PENSION_INS`, PDF 반영

### TCPN839 — 주택자금소득공제내역

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `HOUSE_DEC_CD`, `SEQ`
- **용도**: 주택자금(주택담보대출이자/전세대출이자/월세) 내역. 주택자금 소득공제 계산 원천.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.HOUSE_SAVING_INS`, `PKG_CPN_YEA_{YY}_SYNC.MTH_RENT_INS`, PDF 반영

### TCPN887 — 출산지원금내역관리

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `FAMRES`, `SUP_CNT`
- **용도**: 출산지원금/아동수당 등 정부 지원 기록. 2024 귀속 이후 추가 항목.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC.CHILD_BIRTH_INS`, PDF 반영

---

## 계산결과/검증/PDF 테이블

### TCPN841 — 연말정산계산결과

- **PK**: `ADJUST_TYPE`, `WORK_YY`, `ENTER_CD`, `SABUN`
- **용도**: 최종 세액 계산 결과. 소득/공제/세액/환급액의 종합 결과 레코드.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_TAX` (계산 최종 결과 기록)

### TCPN843 — 연말정산계산결과상세

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `ADJ_ELEMENT_CD`
- **용도**: 항목별 계산 결과 상세. 입력값/기준값/계산값/임시값을 모두 보존하여 계산 추적 가능.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_SYNC` (원천자료 동기화), `PKG_CPN_YEA_{YY}.P_CPN_YEAREND_PAYTOT` (집계 및 기초값 정비), `P_CPN_YEAREND_EMP` (초기 항목행 생성)

### TCPN849 — 정산대상자별오류검증결과

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `CHK_GUBUN`, `SEQ`
- **용도**: 연말정산 마감 전 오류검증 결과. 입력마감 불가능 사유를 기록.
- **업데이트 주체**: `PKG_CPN_YEA_{YY}_ERRCHK.ERROR_CHK` (검증 수행 후 오류 INSERT)

### TCPN851 — PDF기초자료

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `SEQ`
- **용도**: 업로드된 PDF 자료(교육비/의료비/기부금/카드 등)의 기초 데이터. 유효성 검증 후 원천자료로 반영.
- **업데이트 주체**: `P_CPN_YEA_PDF_ERRCHK_{YY}` (PDF 검증), `P_CPN_YEA_PDF_ERRUPD_{YY}` (검증 후 원천자료 반영)

### TCPN855 — PDF파일정보

- **PK**: `ENTER_CD`, `WORK_YY`, `ADJUST_TYPE`, `SABUN`, `DOC_TYPE`, `DOC_SEQ`
- **용도**: 업로드된 PDF 파일의 메타데이터(파일명/저장경로/업로드일시/양식코드). `TCPN851`의 상위 파일 레코드.
- **업데이트 주체**: 파일 업로드 프로세스, `P_CPN_YEA_PDF_ERRCHK_{YY}`, `P_CPN_YEA_PDF_ERRUPD_{YY}`

---

## 연도 불변 원칙

### 테이블명의 연도 독립성

`TCPN801`, `TCPN803`, `TCPN811`, `TCPN813` 등 모든 연말정산 테이블은 **테이블 이름 자체는 연도와 무관**하다.
즉, 2024 귀속과 2025 귀속, 2026 귀속이 **동일한 물리 테이블**을 공유한다.

연도별 데이터는 `WORK_YY` 컬럼으로 구분한다.

```sql
-- 2024 귀속 대상자
SELECT * FROM TCPN811 WHERE WORK_YY = '2024';

-- 2025 귀속 대상자
SELECT * FROM TCPN811 WHERE WORK_YY = '2025';

-- 2026 귀속 대상자
SELECT * FROM TCPN811 WHERE WORK_YY = '2026';
```

### 패키지명의 연도 종속성

이와 대조적으로, **DB 패키지/프로시저는 연도별로 별도 생성**된다.

| 2024 귀속 | 2025 귀속 | 2026 귀속 |
|---|---|---|
| `PKG_CPN_YEA_2024` | `PKG_CPN_YEA_2025` | `PKG_CPN_YEA_2026` |
| `PKG_CPN_YEA_2024_CODE` | `PKG_CPN_YEA_2025_CODE` | `PKG_CPN_YEA_2026_CODE` |
| `PKG_CPN_YEA_2024_SYNC` | `PKG_CPN_YEA_2025_SYNC` | `PKG_CPN_YEA_2026_SYNC` |
| `PKG_CPN_YEA_2024_EMP` | `PKG_CPN_YEA_2025_EMP` | `PKG_CPN_YEA_2026_EMP` |
| `PKG_CPN_YEA_2024_ERRCHK` | `PKG_CPN_YEA_2025_ERRCHK` | `PKG_CPN_YEA_2026_ERRCHK` |

따라서 새 귀속년도가 추가되면:

1. 테이블은 기존 테이블에 `WORK_YY` 값만 추가되고,
2. 패키지는 당해연도별 신규 패키지 세트를 생성해야 한다.

이 구조 덕분에 **하나의 물리 테이블이 여러 연도를 효율적으로 관리**할 수 있다.
