/*`timescale 1ns / 1ps
interface uart_interface;
    logic clk;
    logic rst;
    logic rx;
    logic tx;
    logic uart_clear;
    logic uart_enable;
    logic uart_mode;
endinterface  //uart_interface

class transaction;

    rand bit [7:0] rx_data;
    bit tx;
    bit rx;
    bit [7:0] tx_data;
    //logic uart_clear;
    //logic uart_enable;
    //logic uart_mode;

    task display(string name_s);
       // $display("%t, [%s] rx_data = %h, tx_data = %h", $stime, name_s,
                 //rx_data, tx_data);
        $display("[%12d ns] : [%s] rand_wdata = 0x%02h, rdata = 0x%02h", $time,
                 name_s, rx_data, tx_data);
    endtask

endclass  //transaction

class generator;

    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;
    int total_count;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            total_count++;
            trans = new();
            assert (trans.randomize())
            else $error("[GEN] randomize() error");

            gen2drv_mbox.put(trans);
            trans.display("GEN");
            @(gen_next_event);
        end
    endtask  // run
endclass  // generator

class driver;

    transaction trans;
    transaction trans_scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) drv2scb_mbox;
    virtual uart_interface uart_if;
    event mon_next_event;
    parameter BIT_PERIOD = 10 * (100_000_000 / 9600);
    integer i;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_if, event mon_next_event,
                 mailbox#(transaction) drv2scb_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if = uart_if;
        this.mon_next_event = mon_next_event;
        this.drv2scb_mbox = drv2scb_mbox;
    endfunction  //new()

    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;
        repeat (2) @(posedge uart_if.clk);
        uart_if.rst = 0;
        uart_if.rx  = 1;
        repeat (2) @(posedge uart_if.clk);
        $display("[DRV] reset done");
    endtask  //reset

    task run();
        forever begin
            //#1;
            gen2drv_mbox.get(trans);
            uart_if.rx = 1'b0;
            #(BIT_PERIOD);
            for (i = 0; i < 8; i++) begin
                uart_if.rx = trans.rx_data[i];
                #(BIT_PERIOD);
            end
            uart_if.rx = 1'b1;
            #(BIT_PERIOD / 2);
            trans.display("DRV");
            #(BIT_PERIOD / 2);

            //#2;
            trans_scb = new();
            trans_scb.tx_data = trans.rx_data;
            drv2scb_mbox.put(trans_scb);
            //->mon_next_event;
            //@(posedge uart_if.clk);
        end
    endtask  //run
endclass  //driver

class monitor;

    transaction trans;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_interface uart_if;
    event mon_next_event;
    integer i = 0;
    parameter BIT_PERIOD = 10 * (100_000_000 / 9600);

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_interface uart_if, event mon_next_event);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;
        this.mon_next_event = mon_next_event;
    endfunction  //new()

    task run();
        forever begin
            //@mon_next_event;
            @(negedge uart_if.tx);
            trans = new();
            //if (uart_if.tx == 0) begin
                #(BIT_PERIOD);
                //#(BIT_PERIOD / 2);
                for (i = 0; i < 8; i++) begin
                    trans.tx_data[i] = uart_if.tx;
                    #(BIT_PERIOD);
                end
                #(BIT_PERIOD/2);
                if (uart_if.tx == 0) begin
                    $display("STOP BIT ERROR");
                end
            //end
            trans.display("MON");
            mon2scb_mbox.put(trans);
            // @(posedge uart_if.clk);
        end
    endtask  //run

endclass  //monitor

class scoreboard;

    transaction trans;
    transaction trans_scb;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;
    event gen_next_event;
    int pass_count, fail_count;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event,
                 mailbox#(transaction) drv2scb_mbox);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        this.drv2scb_mbox   = drv2scb_mbox;
    endfunction  //new()

    task run();
        forever begin
            drv2scb_mbox.get(trans_scb);
            mon2scb_mbox.get(trans);
            trans.display("SCB");

            if (trans_scb.tx_data == trans.tx_data) begin
                $display(
                    "[%12d ns] : [SCB] PASS: Sent 0x%02h, Received 0x%02h\n",
                    $stime, trans_scb.tx_data, trans.tx_data);
                pass_count++;
            end else begin
                $error(
                    "[%12d ns] : [SCB] FAIL: Expected 0x%02h, But got 0x%02h\n",
                    $stime, trans_scb.tx_data, trans.tx_data);
                fail_count++;
            end
            ->gen_next_event;
        end
    endtask

endclass  //scoreboard

class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    event gen_next_event;
    event mon_next_event;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;


    function new(virtual uart_interface uart_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        drv2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, uart_if, mon_next_event, drv2scb_mbox);
        mon = new(mon2scb_mbox, uart_if, mon_next_event);
        scb = new(mon2scb_mbox, gen_next_event, drv2scb_mbox);
    endfunction  //new()

    task reset();
        drv.reset();
    endtask  //reset

    task report();
        $display("===================================");
        $display("============test report============");
        $display("===================================");
        $display("==     Total Count : %d ==", gen.total_count);
        $display("==     Pass  Test  : %d ==", scb.pass_count);
        $display("==     Fail  Test  : %d ==", scb.fail_count);
        $display("===================================");
        $display("==     Test bench is finish      ==");
        $display("===================================");
    endtask  //report

    task run();
        fork
            gen.run(256);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $display("finished");
        $stop;
    endtask  //run

endclass  //environment



module tb_uart_fifo_tb ();
    environment env;
    uart_interface uart_if_tb ();

    uart_top dut (
        .clk(uart_if_tb.clk),
        .rst(uart_if_tb.rst),
        .rx(uart_if_tb.rx),
        .tx(uart_if_tb.tx)
 //       .uart_clear(uart_if_tb.uart_clear),
//        .uart_enable(uart_if_tb.uart_enable),
//        .uart_mode(uart_if_tb.uart_mode)
    );

    always #5 uart_if_tb.clk = ~uart_if_tb.clk;
    initial begin
        env = new(uart_if_tb);
        env.reset();
        env.run();
        env.report();
        $stop;
    end

endmodule*/
`timescale 1ns / 1ps

parameter BIT_PERIOD = (100_000_000 / 9600) * 10;


interface uart_fifo_interface;
    logic clk;
    logic rst;
    logic rx;
    logic tx;
endinterface  //reg_interface

class transaction;
    rand logic [7:0] rand_wdata;
    logic      [7:0] rdata;

    task display(string name_s);
        $display("[%12d ns] : [%s] rand_wdata = 0x%02h, rdata = 0x%02h", $time,
                 name_s, rand_wdata, rdata);
    endtask

endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;

    int total_cnt = 0;

    function new(mailbox#(transaction) gen2drv_mbox);
        this.gen2drv_mbox   = gen2drv_mbox;
    endfunction  //new()

    task run();
        // 1. 0~255까지의 숫자를 담을 큐(queue) 생성
        int data_q[$];

        // 2. 큐에 0부터 255까지의 모든 값을 순서대로 채우기
        for (int i = 0; i < 256; i++) begin
            data_q.push_back(i);
        end

        // 3. 큐의 순서를 무작위로 섞기 (Fisher-Yates Shuffle 알고리즘 직접 구현)
        // XSIM이 data_q.shuffle()을 지원하지 않으므로 수동으로 구현합니다.
        for (int i = data_q.size() - 1; i > 0; i--) begin
            int j = $urandom_range(i, 0); // 0부터 현재 인덱스(i)까지의 무작위 인덱스 선택
            // i번째 요소와 j번째 요소를 교환(swap)
            int temp = data_q[i];
            data_q[i] = data_q[j];
            data_q[j] = temp;
        end

        total_cnt = data_q.size();
        $display("[%12d ns] : [%-5s] : Generating %0d shuffled transactions (0x00 to 0xFF)...", 
                 $time, "GEN", total_cnt);
        
        // 4. 무작위로 섞인 큐의 순서대로 트랜잭션 생성 및 전송
        foreach (data_q[i]) begin
            tr = new();
            // randomize() 대신 큐에서 값을 직접 할당
            tr.rand_wdata = data_q[i];
            gen2drv_mbox.put(tr);
            tr.display("GEN");
        end
    endtask
endclass  //generator

class driver;

    transaction                 tr;
    mailbox #(transaction)      gen2drv_mbox;
    mailbox #(transaction)      drv2scb_mbox;
    virtual uart_fifo_interface uart_if;
    event                       gen_next_event;
    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) drv2scb_mbox,
                 virtual uart_fifo_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        this.uart_if      = uart_if;
    endfunction

    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;
        #10;
        uart_if.rst = 0;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            drv2scb_mbox.put(tr);
            uart_if.rx = 1'b0;
            #(BIT_PERIOD); // 104166ns

            for (int i = 0; i < 8; i++) begin
                uart_if.rx = tr.rand_wdata[i];
                #(BIT_PERIOD);
            end
            uart_if.rx = 1'b1;
            #(BIT_PERIOD);
            tr.display("DRV");
        end
    endtask  //
endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_fifo_interface uart_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_fifo_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;
    endfunction  //new()

    task run();
        forever begin
            tr = new();
            @(negedge uart_if.tx);
            #(BIT_PERIOD / 2);
            #(BIT_PERIOD);
            for (int i = 0; i < 8; i++) begin
                tr.rdata[i] = uart_if.tx;
                #(BIT_PERIOD);
            end
            tr.display("MON");
            #(BIT_PERIOD / 2);
            mon2scb_mbox.put(tr);
        end
    endtask
endclass  //monitor

class scoreboard;

    transaction tr;
    transaction send_data;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;

    int pass_cnt = 0;
    int fail_cnt = 0;

    // 0~255까지의 값이 커버되었는지 체크하기 위한 256비트 배열
    bit [255:0] covered_bins;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) drv2scb_mbox);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.drv2scb_mbox   = drv2scb_mbox;
        // 체크리스트를 모두 0으로 초기화
        this.covered_bins = '0; 
    endfunction  //new()

    task run();
        forever begin

            drv2scb_mbox.get(send_data);
            mon2scb_mbox.get(tr);

            // 수신된 데이터에 해당하는 체크리스트 칸을 1로 마킹
            covered_bins[send_data.rand_wdata] = 1'b1;

            //tr.display("SCB");
            if (send_data.rand_wdata == tr.rdata) begin
                $display("[%12d ns] : ==============  SCORE BOARD  ===========",$stime);
                $display(
                    "[%12d ns] : [SCB] PASS: Sent 0x%02h, Received 0x%02h",
                    $stime, send_data.rand_wdata, tr.rdata);
                $display("[%12d ns] : ========================================\n",$stime);
                pass_cnt++;
            end else begin
                $display("[%12d ns] : ==============  SCORE BOARD  ===========",$stime);
                $error(
                    "[%12d ns] : [SCB] FAIL: Expected 0x%02h, But got 0x%02h",
                    $stime, send_data.rand_wdata, tr.rdata);
                $display("[%12d ns] : ========================================\n",$stime);
                fail_cnt++;
            end
        end
    endtask

endclass  //scoreboard

class environment;

    generator                   gen;
    driver                      drv;
    transaction                 tr;
    mailbox #(transaction)      gen2drv_mbox;
    mailbox #(transaction)      drv2scb_mbox;
    mailbox #(transaction)      mon2scb_mbox;
    virtual uart_fifo_interface uart_if;
    event                       gen_next_event;
    monitor                     mon;
    scoreboard                  scb;

    function new(virtual uart_fifo_interface uart_if);
        gen2drv_mbox = new();
        drv2scb_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, drv2scb_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, drv2scb_mbox);
        this.uart_if = uart_if;
    endfunction  //new()

    task report();
        int covered_count = 0;
        int uncovered_q[$]; // 테스트되지 않은 값들을 저장할 큐

        // 1. scoreboard의 체크리스트(covered_bins)를 검사
        for (int i = 0; i < 256; i++) begin
            if (scb.covered_bins[i] == 1'b1) begin
                covered_count++;
            end else begin
                uncovered_q.push_back(i); // 테스트 안된 값 저장
            end
        end

        // 2. 기본 테스트 결과 출력
        $display("========================================");
        $display("============= TEST SUMMARY =============");
        $display("========================================");
        $display("  Total Transactions : %0d", gen.total_cnt);
        $display("  Passed             : %0d", scb.pass_cnt);
        $display("  Failed             : %0d", scb.fail_cnt);
        $display("----------------------------------------");
        if (scb.fail_cnt == 0 && gen.total_cnt == scb.pass_cnt) begin
            $display("  TEST RESULT: ** PASSED **");
        end else begin
            $display("  TEST RESULT: ** FAILED **");
        end
        $display("========================================");
        
        // 3. 커버리지 결과 출력
        $display("========== COVERAGE REPORT ===========");
        $display("========================================");
        $display("  Data Value Coverage: %0.2f %% (%0d / 256)", 
                 (real'(covered_count) / 256.0) * 100.0, covered_count);
        
        // 4. 테스트되지 않은 항목이 있다면 출력
        if (uncovered_q.size() > 0) begin
            $write("  Uncovered values : ");
            foreach(uncovered_q[i]) begin
                $write("0x%02h, ", uncovered_q[i]);
            end
            $display(""); // new line
        end
        $display("========================================");
    endtask

    task run();
        drv.reset();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none

        // 모든 생성된 트랜잭션이 scoreboard에서 처리될 때까지 대기
        wait(scb.pass_cnt + scb.fail_cnt >= 256);
        report();
        $stop;
    endtask
endclass  //environment

module tb_v2 ();

    uart_fifo_interface uart_if_tb ();
    environment env;

    uart_top dut (
        .clk(uart_if_tb.clk),
        .rst(uart_if_tb.rst),
        .rx (uart_if_tb.rx),
        .tx (uart_if_tb.tx)
    );

    always #5 uart_if_tb.clk = ~uart_if_tb.clk;

    initial begin
        uart_if_tb.clk = 0;
        env = new(uart_if_tb);
        env.run();
    end

endmodule
