`timescale 1ns / 1ps

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
                    if (b_tick_cnt_reg == 15) begin
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