# Claude AutoFlow Template — 작업 계획서

> **목표**: `ontology-platform`의 Claude Code 운영 방법론(Auto-Flow)을 다른 프로젝트에 쉽게 이식할 수 있는 공개 템플릿 레포로 일반화한다.

---

## 배경 및 범위

### 이식 대상
`Munsik-Park/ontology-platform`의 CLAUDE.md, Hook, docs에 녹아 있는 Claude Code 운영 노하우:
- Auto-Flow (PREFLIGHT~LAND) 개발 생명주기
- 3-Phase 독립 구조 분석 (편향 방지)
- Multi-agent 역할 분리 (오케스트레이터 / 개발 AI / 테스트 AI / 평가 AI)
- Hook 기반 평가 게이트 (`check-autoflow-gate.sh`)
- Discussion Protocol
- 평가 시스템 (10점 척도, PASS 기준)

### 전제 구조
- **탑 오케스트레이션 레포** (이 템플릿이 타겟) + **기능별 서브 레포** 구조
- 서브 레포 예시: `frontend`, `backend`, `infra`, `docs` 등 일반적 형태
- 레포 간 경계 규칙 (서비스 간 직접 수정 금지)

---

## 산출물 목록 (레포 구조)

```
claude-autoflow-template/
│
├── README.md                          # 개요 + 이식 가이드
├── CLAUDE.md.template                 # 핵심 템플릿 (placeholder 포함)
├── CLAUDE.local.md.example            # 로컬 오버라이드 예시
│
├── .claude/
│   └── hooks/
│       └── check-autoflow-gate.sh     # 범용 Hook (수정 불필요)
│
├── docs/
│   ├── autoflow-guide.md              # Auto-Flow 단계별 상세 설명
│   ├── git-workflow.md                # Git 절차 (범용)
│   ├── repo-boundary-rules.md         # 레포 간 경계 규칙 (일반화)
│   ├── submodule-common-rules.md      # 서브 레포 공통 규칙 (일반화)
│   ├── security-checklist.md.template # 보안 체크리스트 (일반화 + 교체 가이드)
│   ├── maintained-docs.md.template    # 유지 문서 목록 템플릿
│   └── evaluation-system.md           # 평가 시스템 설명
│
├── subrepo-templates/
│   ├── frontend/
│   │   └── CLAUDE.md.template         # 프론트엔드 서브 레포용 CLAUDE.md
│   ├── backend/
│   │   └── CLAUDE.md.template         # 백엔드 서브 레포용 CLAUDE.md
│   └── _common/
│       └── CLAUDE.md.template         # 공통 서브 레포 규칙
│
└── setup/
    ├── init.sh                        # 대화형 초기화 스크립트
    └── SETUP-GUIDE.md                 # 수동 이식 가이드
```

---

## Phase별 작업 계획

### Phase 1: 분리 및 분석 (준비)
**목표**: 현재 `ontology-platform`의 내용을 "범용 레이어"와 "프로젝트 특화 레이어"로 명확히 분리한다.

| 작업 | 내용 | 산출물 |
|------|------|--------|
| 1-1 | CLAUDE.md 전체를 줄별로 읽으며 일반화 가능 여부 태깅 | 분석 메모 |
| 1-2 | 프로젝트 특화 요소 목록 추출 | placeholder 목록 |
| 1-3 | docs/ 각 파일의 일반화 가능 범위 확인 | 파일별 처리 방침 |

**프로젝트 특화 → 일반화 매핑 (확정된 것)**

| 현재 (특화) | 템플릿 (일반화) |
|-------------|-----------------|
| `ontology-api`, `saiso` 등 서비스명 | `{{REPO_BACKEND}}`, `{{REPO_FRONTEND}}` 등 |
| `connev-ontology` org명 | `{{GITHUB_ORG}}` |
| OAuth 2.1, Keycloak, SPARQL 보안 항목 | 일반 웹서비스 보안 5항목 + 교체 가이드 |
| 서비스 간 경계 규칙 | 레포 간 경계 규칙 |
| Agent Teams (`SendMessage`) | 동일 유지 (Claude Code 범용 기능) |
| fork/upstream 구조 | 선택적 (단일 레포 / 멀티 레포 옵션) |

---

### Phase 2: 핵심 파일 작성

#### 2-1. `CLAUDE.md.template` 작성
**가장 중요한 파일.** 아래 원칙으로 작성:

- **고정 섹션** (수정 불필요): Auto-Flow 단계 정의, 평가 시스템, Hook 게이트, Discussion Protocol
- **교체 섹션** (placeholder): 서브 레포명, org명, 보안 스택, 커밋 소유권 테이블의 역할명
- **선택 섹션** (주석 처리): 서브모듈 구조를 쓰지 않는 경우 제거할 블록

Placeholder 형식: `{{UPPER_SNAKE_CASE}}`

주요 placeholder 목록:
```
{{PROJECT_NAME}}          - 프로젝트 이름
{{GITHUB_ORG}}            - GitHub 조직명
{{REPO_ORCHESTRATOR}}     - 오케스트레이션 레포명
{{REPO_BACKEND}}          - 백엔드 레포명 (복수 가능)
{{REPO_FRONTEND}}         - 프론트엔드 레포명
{{REPO_INFRA}}            - 인프라 레포명 (선택)
{{TECH_STACK_SUMMARY}}    - 기술 스택 한줄 요약 (보안 체크리스트용)
{{CI_SYSTEM}}             - CI 도구 (Jenkins / GitHub Actions / CircleCI 등)
{{DEFAULT_BRANCH}}        - 기본 브랜치명 (main / master)
```

#### 2-2. `check-autoflow-gate.sh` 범용화 확인
현재 Hook은 이미 범용적으로 작성되어 있음. 확인 사항:
- `CLAUDE_PROJECT_DIR` 환경변수 의존 → 유지 (Claude Code 표준)
- 하드코딩된 경로 없음 → 수정 불필요
- 이슈 번호 기반 상태 파일 패턴 → 유지

#### 2-3. `docs/repo-boundary-rules.md` 작성
`ontology-platform`의 "Cross-Project Boundary Rules"를 레포 간 규칙으로 일반화:
- 각 레포 AI의 읽기/쓰기 범위
- 레포 간 변경 조율 절차 (Agent Teams 활용)
- 오케스트레이터가 직접 커밋하는 예외 케이스

#### 2-4. `docs/security-checklist.md.template` 작성
현재 플랫폼 특화(OAuth 2.1, Keycloak, SPARQL, RabbitMQ, C2C)를 일반화:

**일반화 5항목 (범용 웹서비스 기준)**:
1. 인증/인가 — 엔드포인트 접근 제어
2. 입력값 검증 — SQL/NoSQL/외부 입력 이스케이프
3. 데이터 노출 — 민감정보 로그/응답 노출 방지
4. 인프라 격리 — 내부 서비스 포트 노출 방지
5. 의존성 취약점 — 외부 라이브러리 CVE 확인

각 항목 뒤에 "프로젝트 특화 예시" 블록을 주석으로 첨부하여 교체 방법 안내.

#### 2-5. `subrepo-templates/` 작성
각 서브 레포용 최소 CLAUDE.md 템플릿:
- 자기 레포 범위 정의
- 상위 오케스트레이터와의 소통 방식
- 테스트 AI / 개발 AI 역할 수행 방법
- 공통 규칙 참조 링크

#### 2-6. `setup/init.sh` 작성
```bash
# 대화형 초기화 흐름
1. 프로젝트명 입력
2. GitHub org/user명 입력
3. 서브 레포 목록 입력 (frontend, backend, infra, ...)
4. CI 시스템 선택 (GitHub Actions / Jenkins / 기타)
5. 기술 스택 요약 입력
6. CLAUDE.md.template → CLAUDE.md 치환
7. security-checklist.md.template → security-checklist.md 치환
8. 완료 안내 출력
```

---

### Phase 3: README 및 문서화

#### 3-1. `README.md` 작성
- 이 템플릿이 무엇인지 (Auto-Flow 방법론 소개)
- 빠른 시작 (Quick Start): `init.sh` 실행 또는 수동 이식
- 레포 구조 설명
- 이식 후 체크리스트
- 기여 방법 (CONTRIBUTING.md)

#### 3-2. `docs/autoflow-guide.md` 작성
현재 CLAUDE.md에 내장된 Auto-Flow 설명을 독립 문서로 분리:
- 각 phase의 목적과 완료 조건
- Flow Control 표
- 회귀 규칙
- 실행 원칙

#### 3-3. `docs/evaluation-system.md` 작성
평가 시스템 독립 문서화:
- 10점 척도 의미
- PASS 기준
- 평가 유형별 항목
- 출력 포맷 (JSON)
- Hook과의 연동 방식

---

### Phase 4: 검증

| 작업 | 방법 |
|------|------|
| 4-1 placeholder 완전성 검증 | `grep -r '{{' .` 로 누락 없는지 확인 |
| 4-2 init.sh 동작 검증 | 실제 실행하여 치환 결과 확인 |
| 4-3 Hook 동작 검증 | 테스트 상태 파일로 게이트 차단 시나리오 확인 |
| 4-4 다른 프로젝트에 이식 시뮬레이션 | 가상 프로젝트(예: `todo-app`)에 이식 테스트 |

---

## 작업 환경 및 권장 순서

### 어디서 작업할 것인가

| 단계 | 환경 | 이유 |
|------|------|------|
| 설계 논의 / 방향 결정 | Claude.ai 채팅 (여기) | 대화형 의사결정 |
| 파일 생성 / git 조작 | **Claude Code** | 파일 직접 생성, bash 실행, 반복 수정 |
| 최종 리뷰 / 피드백 | Claude.ai 채팅 또는 Claude Code | 취향에 따라 |

### 시작 전 준비 사항
1. GitHub에 새 public 레포 생성 (예: `claude-autoflow-template`)
   - "Template repository" 체크박스 활성화 권장
2. `README.md`만 있는 초기 상태로 생성
3. Claude Code에서 `git clone` 후 작업 시작

### Claude Code에서 첫 명령
```
이 레포를 claude-autoflow-template으로 만들려고 합니다.
작업 계획서(claude-autoflow-template-workplan.md)를 읽고
Phase 1부터 시작해주세요.
```

---

## 핵심 설계 원칙 (작업 중 유지)

1. **Auto-Flow 로직은 건드리지 않는다** — phase 정의, 평가 기준, Hook 로직은 범용 그대로 유지
2. **placeholder는 최소화한다** — 필수적인 것만. 너무 많으면 이식 비용이 높아짐
3. **선택적 섹션은 주석으로** — 서브모듈 불필요한 경우를 위한 "여기서 여기까지 제거" 가이드
4. **서브 레포 CLAUDE.md는 얇게** — 오케스트레이터 CLAUDE.md를 복사하지 않고 참조하도록
5. **init.sh 없이도 이식 가능하게** — `SETUP-GUIDE.md`로 수동 이식도 지원

---

## 미결 결정 사항 (작업 전 확인 필요)

| 항목 | 옵션 A | 옵션 B | 현재 판단 |
|------|--------|--------|-----------|
| 레포명 | `claude-autoflow-template` | `auto-flow-template` | 미결 |
| 서브모듈 구조 기본값 | git submodule 방식 | 독립 레포 방식 | 미결 |
| 언어 | 한국어 README | 영어 README | 공개용이므로 영어 권장 |
| 라이선스 | MIT | Apache 2.0 | 미결 |
