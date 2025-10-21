`timescale 1ns / 1ps


module uart_stopwatch (
    input        clk,
    input        rst,
    input        btn_R,
    input        btn_L,
    input        btn_U,
    input        rx,
    output       tx,
    output [3:0] fnd_com,
    output [7:0] fnd_data

);

    wire w_uart_clear, w_uart_enable, w_uart_mode;

    segment U_SEGMENT (
        .clk(clk),
        .rst(rst),
        .mode(btn_U),
        .enable(btn_R),
        .clear(btn_L),
        .uart_clear(w_uart_clear),
        .uart_enable(w_uart_enable),
        .uart_mode(w_uart_mode),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

    uart_top U_UART_TOP (
        .clk        (clk),
        .rst        (rst),
        .tx         (tx),
        .rx         (rx)
//        .uart_clear (w_uart_clear),
//        .uart_enable(w_uart_enable),
//        .uart_mode  (w_uart_mode)
    );
endmodule
