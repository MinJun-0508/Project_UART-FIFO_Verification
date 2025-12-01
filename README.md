# Project_UART-FIFO_Verification

## 📌 프로젝트 목표
본 프로젝트는 Verilog/SystemVerilog를 이용해 UART통신 기반의 스톱워치 모듈을 설계하고,
SystemVerilog 기반의 검증환경을 구축하여 설계한 UART 모듈(DUT)의 기능을 검증하는 것 입니다.

---

## ⚙️ 개발 환경
- 설계 언어 : Verilog, SystemVerilog
- 검증 언어 : SystemVerilog
- 시뮬레이션 툴 : Vivado

---

## 🧩 블록 다이어그램

### 전체 시스템 블록 다이어그램

<img width="1476" height="616" alt="STOPWATCH_DRAWIO" src="https://github.com/user-attachments/assets/46909f56-e4ea-4523-a438-0f499415a002" />

### UART + FIFO 상세 블록 다이어그램

<img width="1412" height="837" alt="UART_DRAWIO" src="https://github.com/user-attachments/assets/0f97dd0e-a64f-45e8-a3e9-fe7350566959" />

---

## 검증 환경

<img width="779" height="828" alt="TESTBENCH_DRAWIO" src="https://github.com/user-attachments/assets/5472c858-93db-4c11-913b-09b16dd5d4c9" />

- Transaction: 데이터 패킷의 기본 단위 클래스. 전송할 데이터, Start/Stop 비트, 예외 상황 플래그 등을 포함합니다.
- Generator: 테스트 시나리오에 맞는 Transaction을 생성합니다. (예: 랜덤 데이터, 예외 상황 데이터)
- Driver: Generator로부터 Transaction을 받아 DUT의 입력 포맷에 맞게 신호를 인가합니다.
- Monitor: DUT의 출력 신호를 감지하여 Transaction 형태로 변환합니다.
- Scoreboard: Driver가 보낸 원본 데이터와 Monitor가 수집한 결과 데이터를 비교하여 Pass/Fail을 판정합니다.
- Mailbox: Generator, Driver, Scoreboard 간의 Transaction 데이터 전달을 위한 통신 채널입니다.
- Interface: DUT와 검증 환경 간의 신호 연결을 간소화합니다.

---

## 검증 시나리오 및 결과

## 📈 프로젝트 고찰
