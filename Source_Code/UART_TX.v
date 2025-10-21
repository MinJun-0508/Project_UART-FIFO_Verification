`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    //input        tx_start,
    //input  [7:0] tx_data,
    input        rx,
    //output [7:0] rx_data,
    //output       rx_done,
    //output       tx_busy,
    output       tx
    //output uart_clear,
    //output uart_enable,
    //output uart_mode
);


    wire w_baud_tick;
    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire w_rx_full;
    wire w_rx_empty;
    wire [7:0] w_rx_rdata,w_tx_rdata;
    wire w_tx_full;
    wire w_tx_empty;
    wire w_tx_busy;

    //assign rx_data = w_rx_data;
    

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .o_baud_tick(w_baud_tick)
    );

    UART_TX U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_empty),
        .tx_data(w_tx_rdata),
        .b_tick(w_baud_tick),
        .tx_busy(w_tx_busy),
        .tx(tx)
    );

    UART_RX U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_baud_tick),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    fifo U_RX_FIFO (
    .clk(clk),
    .rst(rst),
    .wr(w_rx_done),
    .rd(~w_tx_full),
    .wdata(w_rx_data),
    .rdata(w_rx_rdata),
    .full(w_rx_full),
    .empty(w_rx_empty)
);

fifo U_TX_FIFO (
    .clk(clk),
    .rst(rst),
    .wr(~w_rx_empty),
    .rd(~w_tx_busy),
    .wdata(w_rx_rdata),
    .rdata(w_tx_rdata),
    .full(w_tx_full),
    .empty(w_tx_empty)
);

    uart_command U_COMMAND_CU(
    .clk(clk),
    .rst(rst),
    .rx_data(w_rx_data),
    .rx_done(~w_rx_empty),
    .uart_enable(uart_enable),
    .uart_clear(uart_clear),
    .uart_mode(uart_mode)
);


endmodule


module UART_TX (
    input clk,
    input rst,
    input tx_start,
    input [7:0] tx_data,
    input b_tick,
    output tx_busy,
    output tx
);

    parameter [1:0] IDLE = 2'b0, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] state_reg, state_next;
    reg tx_busy_reg, tx_busy_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg tx_reg, tx_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg <= IDLE;
            tx_busy_reg <= 1'b0;
            data_buf_reg <= 8'h00;
            tx_reg <= 1'b1;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg <= 3'b000;

        end else begin
            state_reg <= state_next;
            tx_busy_reg <= tx_busy_next;
            data_buf_reg <= data_buf_next;
            tx_reg <= tx_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
        end
    end

    always @(*) begin
        state_next = state_reg;
        tx_busy_next = tx_busy_reg;
        tx_next = tx_reg;
        data_buf_next = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        case (state_reg)
            IDLE: begin
                tx_next = 1;
                tx_busy_next = 0;
                if (tx_start == 1) begin
                    data_buf_next = tx_data;
                    state_next = START;
                end
            end

            START: begin
                tx_next = 0;
                tx_busy_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        state_next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_next == 15) begin
                        if (bit_cnt_reg == 7) begin
                            state_next = STOP;
                            b_tick_cnt_next = 0;
                            bit_cnt_next = 0;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        state_next = IDLE;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end


endmodule

module baud_tick_gen (
    input  clk,
    input  rst,
    output o_baud_tick
);

    parameter baud = 100_000_000 / 9600 / 16;
    reg [$clog2(baud) -1 : 0] clk_cnt;
    reg baud_tick;

    assign o_baud_tick = baud_tick;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            clk_cnt   <= 0;
            baud_tick <= 0;
        end else begin
            if (clk_cnt == baud - 1) begin
                baud_tick <= 1;
                clk_cnt   <= 0;
            end else begin
                baud_tick <= 0;
                clk_cnt   <= clk_cnt + 1;
            end
        end
    end

endmodule

module UART_RX (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output       rx_done,
    output [7:0] rx_data
);
    parameter [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] state_reg, state_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [3:0] bit_cnt_reg, bit_cnt_next;
    reg rx_done_reg, rx_done_next;
    reg [7:0] rx_data_reg, rx_data_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_done_reg    <= 0;
            rx_data_reg    <= 0;
        end else begin
            state_reg      <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_done_reg    <= rx_done_next;
            rx_data_reg    <= rx_data_next;
        end
    end

    always @(*) begin
        state_next      = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_done_next    = rx_done_reg;
        rx_data_next    = rx_data_reg;
        case (state_reg)
            IDLE: begin
                rx_done_next = 0;
                if (!rx) begin
                    b_tick_cnt_next = 0;
                    bit_cnt_next = 0;
                    state_next = START;
                    rx_data_next = 0;
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        state_next = DATA;
                        rx_data_next[7] = rx;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (b_tick) begin
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        state_next   = STOP;
                    end else begin
                        if (b_tick_cnt_reg == 15) begin
                            b_tick_cnt_next = 0;
                            rx_data_next = rx_data_reg >> 1;
                            rx_data_next[7] = rx;
                            bit_cnt_next = bit_cnt_reg + 1;
                        end else begin
                            b_tick_cnt_next = b_tick_cnt_reg + 1;
                        end
                    end
                end
            end

            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        state_next = IDLE;
                        b_tick_cnt_next = 0;

                        rx_done_next = 1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule


