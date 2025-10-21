`timescale 1ns / 1ps

module uart_command (
    input        clk,
    input        rst,
    input  [7:0] rx_data,
    input        rx_done,
    output       uart_enable,
    output       uart_clear,
    output       uart_mode
);

    reg uart_enable_reg;  // r = 0x72
    reg uart_mode_reg;  // m = 0x6D
    reg uart_clear_reg;  // c = 0x63

    assign uart_enable = uart_enable_reg;
    assign uart_clear = uart_clear_reg;
    assign uart_mode = uart_mode_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            uart_enable_reg <= 0;
            uart_mode_reg   <= 0;
            uart_clear_reg  <= 0;
        end else begin
            if (rx_done) begin
                if (rx_data == 8'h72) begin
                    uart_enable_reg <= 1;
                end else begin
                    uart_enable_reg <= 0;
                end
                if (rx_data == 8'h6D) begin
                    uart_mode_reg <= 1;
                end else begin
                    uart_mode_reg <= 0;
                end
                if (rx_data == 8'h63) begin
                    uart_clear_reg <= 1;
                end else begin
                    uart_clear_reg <= 0;
                end
            end else begin
                uart_clear_reg <=0;
                uart_enable_reg <= 0;
                uart_mode_reg <= 0;
            end
        end
    end

endmodule
