# yjungsan 도메인 동의어 사전 (glossary)

연말정산 도메인에서 **표면 표현(자연어)과 코드 식별자가 다르게 쓰이는 경우** 를 정리한 사전.
사용자가 자연어로 던진 키워드를 코드/DB 검색 시 *반드시 모든 코드 식별자로 확장* 해서 검색하기 위함이다.

> 본 사전은 yearend-plan-first / yearend-investigator 의 **Step 0-B (도메인 동의어 확장)** 단계에서 사용된다.
> 누락된 매핑이 발견되면 점진적으로 추가한다 (PR 환영).

---

## 사용 방법

1. 사용자 요청에서 핵심 키워드 추출
2. 본 사전에서 그 키워드의 모든 코드 식별자를 찾음
3. 식별자 *전부* 로 `Grep` / `Glob` / `git log --grep` 시도

예: "사업장코드 추가해줘" → `BUSINESS_PLACE_CD`, `BP_CD`, `ENTER_CD`, `사업장`, `사업장코드` 모두로 검색.

---

## 표면 표현 → 코드 식별자

### 식별·키 (Identifier / Key)

| 표면 표현 | 코드 식별자 / 컬럼 / 함수 |
|----------|--------------------------|
| 사업장코드 | `BUSINESS_PLACE_CD`, `BP_CD`, `ENTER_CD`, `F_COM_GET_BP_CD` |
| 사업자등록번호 | `REGINO`, `ENTER_NO`, `BIZ_NO`, `BIZ_REG_NO` |
| 사원번호 | `SABUN`, `EMP_NO`, `EMP_ID`, `ssnSabun` |
| 귀속연도 | `WORK_YY`, `work_yy`, 정산연도, 귀속년도 |
| 정산구분 | `ADJUST_TYPE`, `adjust_type` |
| 정산구분=연말 | `ADJUST_TYPE='11'` |
| 정산구분=중도 | `ADJUST_TYPE='12'` |
| 정산구분=재계산 | `ADJUST_TYPE='88'` |

### 근무지 / 회사

| 표면 표현 | 코드 식별자 |
|----------|------------|
| 종전근무지 | `TCPN817`, `TCPN818`, `BEFORE_COM`, `BefComMgr`, 종전회사 |
| 주현근무지, 현근무지 | `CURR_COM`, 현재근무지, 주된근무지 |
| 외국인 | `FOREIGNER_YN`, `FOREIGN`, `F_YN` |

### 항목·테이블 (Items / Tables)

| 표면 표현 | 코드 식별자 |
|----------|------------|
| 임원등할인금액 | `EMP_DC`, `NOTAX_EMP_DC`, `TYEA851`, `yearEndnoTaxEmpDcMgr`, `EMP_DC_NOTAX_INS` |
| 출산지원금 | `BIRTH_SUPPORT`, `TCPN887`, `birthSupportMonMgr`, `SP_CHILD_BIRTH_CD` |
| 자녀세액공제 | `CHILD_DEDUCT`, 자녀공제 |
| 비과세 | `NOTAX`, `NOTAX_MON` |
| 과세 | `TAX`, `TAX_MON` |
| 공제 | `DED`, `DED_MON`, `DEDUCT` |
| 한도 | `LIMIT`, `MAX_AMT`, `Z17` (TCPN501 한도코드) |
| 항목별 합계 | `TCPN843`, `ITEM_TOTAL`, `TCPN843_INS` |
| 기타소득내역 | `TCPN815`, 기타소득 |
| 원천자료 | `TCPN813` ~ `TCPN839`, `TCPN887` |
| 계산결과 | `TYEA850`, `TCPN841`, `TCPN843` |
| 오류검증 | `TCPN849`, `ERROR_CHECK`, `ERRCHK` |
| 원천징수영수증 / PDF | `TCPN851`, `TCPN855`, `WITHHOLDING`, `P_CPN_YEA_PDF` |
| 간소화자료 | `SIMPLE_DATA`, 간이자료, 간소화 |

### 세액 계산 · 사업소세(종업원분)

| 표면 표현 | 코드 식별자 / 의미 |
|----------|-------------------|
| 급여총액, 총지급액 | 비과세 포함 전체 급여. 과세급여 + 과세제외급여 |
| 과세급여 | `TAX_MON`, 이미 비과세를 제외한 과세 대상 급여. **산출과표와 동일** |
| 과세제외급여, 비과세급여 | `NOTAX_MON`, 지방세법 시행령 §78조의2 에 따른 비과세 급여 |
| 산출과표 | = 과세급여 (추가 차감 없음). ⚠️ 과세급여에서 과세제외급여를 다시 빼지 않는다 |
| 산출세액 | 산출과표 × 세율 (종업원분: 0.5%) |
| 무신고가산세 | 산출세액 × 20% × (100% − 감면비율) |
| 과소신고가산세 | 산출세액 × 10% × (100% − 감면비율) |
| 납부지연가산세 | 산출세액 × 가산율 × 납부지연일수 |
| 사업소세, 종업원분 | `SMPPYM`, `smppym`, 지방세 (위택스 신고 대상) |

> 상세 계산 규칙 → `references/yjungsan-tax-calc-rules.md` 참조

### 마감 체인

| 표면 표현 | 코드 식별자 |
|----------|------------|
| 마감 | `CLOSE`, `INPUT_CLOSE_YN`, `P_CPN_YEA_CLOSE` |
| 재계산 | `RECAL`, `RECALCULATE`, `ADJUST_TYPE='88'` |
| 분납 처리 | `INSTALLMENT`, `DIVIDE_PAY` |

### 패키지 / 프로시저

| 표면 표현 | 코드 식별자 |
|----------|------------|
| SYNC 패키지 | `PKG_CPN_YEA_{YY}_SYNC` |
| 계산 패키지 | `PKG_CPN_YEA_{YY}_CALC` |
| 사원 패키지 | `PKG_CPN_YEA_{YY}_EMP`, `P_MAIN` |
| 총급여 생성 | `P_YEA_EMPDC_INS` |
| 마감 프로시저 | `P_CPN_YEA_CLOSE` |
| PDF 반영 | `P_CPN_YEA_PDF_ERRCHK_{YY}`, `P_CPN_YEA_PDF_ERRUPD_{YY}` |

> 패키지/프로시저는 **연도 의존**(`{YY}` = 25, 26 등). 검색 시 `2025` / `2026` 양쪽을 모두 시도.

---

## 변경 흔적 패턴 (코드 정독 시 grep 대상)

Step 0-C 에서 변경 흔적을 찾을 때 사용하는 패턴.

| 패턴 | 의미 |
|------|------|
| `(YYYY.MM.DD)` | 일자 표기 주석 (예: `(2026.03.16)`) |
| `// YYYY-MM-DD`, `<!-- YYYY/MM/DD` | JSP/Java/XML 의 변경 일자 주석 |
| `// 추가`, `// 변경`, `// 수정`, `--- 변경` | 변경 주석 |
| `// FIXME`, `// TODO` | 작업 진행 중 표기 |
| `(이수파이브)`, `(MK)`, 작성자 약자 + 날짜 | 사내 변경 표기 관습 |

---

## 트리거 단어 (사용자 메시지 → 부분 반영 가설 의심)

Step 0-D 에서 사용자 메시지를 검사할 때 *부분 반영* 가능성을 높이는 단어.

| 단어 | 의미 |
|------|------|
| "추가" | 기존 위에 더하는 것 → 기존 일부가 이미 있을 가능성 |
| "개선", "보강" | 기존 동작에 변형을 가하는 것 |
| "이미", "이미 ~ 했는데" | 본인이 직접 일부 작업한 후의 추가 요청 |
| "수정한 후에", "이어서", "다음 단계로" | 작업의 후속 단계 |
| "다시", "한 번 더" | 재작업·재확인 요청 — 이전 결과의 존재 시사 |

이 단어들이 메시지에 있으면 Step 0 의 검사를 더 깊게 한다.
