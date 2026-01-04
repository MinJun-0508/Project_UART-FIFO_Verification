# Project_UART-FIFO_Verification

## 프로젝트 목표
본 프로젝트는 Verilog/SystemVerilog를 이용해 UART통신 기반의 스톱워치 모듈을 설계하고,
SystemVerilog 기반의 검증환경을 구축하여 설계한 UART 모듈(DUT)의 기능을 검증하는 것 입니다.

---

## 개발 환경
- 설계 언어 : Verilog, SystemVerilog
- 검증 언어 : SystemVerilog
- 시뮬레이션 툴 : Vivado

---

## 블록 다이어그램

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

### 시나리오1 : 정상적인 동작 검증

 - 목표 : 256개의 데이터를 랜덤 순서로 전송하고, DUT가 정상적으로 값을 반환하는지 확인합니다.
 - 결과 :
<img width="524" height="292" alt="image" src="https://github.com/user-attachments/assets/f14e1a7f-4297-41bf-9f43-4c43cfea08da" />
 - 분석 : 256개의 모든 데이터가 오류없이 수신, 송신되었으며, 정상적으로 데이터 전송이 작동하는것을 확인했습니다.

### 시나리오2 : 예외 상황 검증

 - 목표 : 비정상적인 데이터 (Start/Stop비트, 'x', 'z' 등)48개와 정상 데이터 256개를 함께 입력 했을때의 DUT의 동작을 확인하여 시스템의 강건성을 검증합니다.
 - 결과 :
<img width="841" height="798" alt="image" src="https://github.com/user-attachments/assets/ed2e0105-a94e-454f-b718-bd6699dd5ff3" />
<img width="737" height="542" alt="image" src="https://github.com/user-attachments/assets/d0212de5-51c2-4122-a9ad-672fc9103e98" />
 - 분석 : 의도적으로 입력한 3가지의 비정상 케이스에서 Fail이 발생한 것을 Scoreboard가 감지해냈습니다. 이는 검증환경이 예상치 못한 오류를 잡아내고 있음을 의미하여, 동시에 설계된 DUT가 프로토콜 위반 상황에는 대응하지 못함을 알았습니다.


## 트러블슈팅 및 고찰

 - 시뮬레이션 시간 단축: 초기 fork-join_any 기반의 이벤트 제어 방식에서 fork-join_none을 사용한 병렬 프로세스 실행 방식으로 변경하여, 전체 시뮬레이션 시간을 약 46% 단축했습니다. 이를 통해 검증 사이클의 효율성을 크게 향상시킬 수 있었습니다.

- 예외상황 검증의 중요성 : 처음 DUT를 설계 할 때에는 문제없이 모듈을 만들었다고 생각했으나, 이러한 예외상황을 적용함으로써 부족한 점이 설계에 미숙함이 있다는 것을 깨달았습니다. 또한 이런 검증을 통해 설계의 허점을 찾아내는 작업이 중요하다는 것을 느끼게 되었습니다.

