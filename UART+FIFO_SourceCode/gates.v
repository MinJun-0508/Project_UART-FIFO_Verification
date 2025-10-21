`timescale 1ns / 1ps

module segment (
    input        clk,
    input        rst,
    input        mode,
    input        enable,
    input        clear,
    input        uart_enable,
    input        uart_mode,
    input        uart_clear,
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire [13:0] w_counter;
    wire        w_tick;
    wire [ 1:0] w_sel;
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire [3:0] w_bcd;
    wire       w_1khz_clk;
    wire w_enable, w_mode, w_clear;
    wire w_bd_enable, w_bd_mode, w_bd_clear;
    wire w_mix_enable, w_mix_mode, w_mix_clear;
    assign w_mix_enable = w_bd_enable | uart_enable;
    assign w_mix_mode   = w_bd_mode | uart_mode;
    assign w_mix_clear  = w_bd_clear | uart_clear;

    button_debounce U_BUTTON_DEBOUNCE_ENABLE (
        .clk  (clk),
        .rst  (rst),
        .i_btn(enable),
        .o_btn(w_bd_enable)
    );

    button_debounce U_BUTTON_DEBOUNCE_MODE (
        .clk  (clk),
        .rst  (rst),
        .i_btn(mode),
        .o_btn(w_bd_mode)
    );

    button_debounce U_BUTTON_DEBOUNCE_CLEAR (
        .clk  (clk),
        .rst  (rst),
        .i_btn(clear),
        .o_btn(w_bd_clear)
    );

    counter_cu U_COUNTER_CU (
        .clk(clk),
        .rst(rst),
        .i_enable(w_mix_enable),
        .i_mode(w_mix_mode),
        .i_clear(w_mix_clear),
        .o_enable(w_enable),
        .o_mode(w_mode),
        .o_clear(w_clear)
    );

    decoder_2x4 U_DECODER_2x4 (
        .sel(w_sel),
        .fnd_com(fnd_com)
    );

    counter U_COUNTER (
        .clk(clk),
        .rst(rst),
        .mode(w_mode),
        .clear(w_clear),
        .i_tick(w_tick),
        .counter(w_counter)
    );

    fnd_controller U_FND_CNTL (
        .bcd(w_bcd),
        .fnd_com(),
        .fnd_data(fnd_data)
    );

    tick_10hz_gen U_TICK_10HZ_GEN (
        .clk(clk),
        .rst(rst),
        .clear(w_clear),
        .enable(w_enable),
        .o_tick_10hz(w_tick)
    );

    clk_divider_10khz U_CLK_DIV (
        .clk(clk),
        .rst(rst),
        .o_clk_1khz(w_1khz_clk)
    );

    digit_splitter U_DIGIT_SPLITTER (
        .i_counter(w_counter),
        .o_digit_1(w_digit_1),
        .o_digit_10(w_digit_10),
        .o_digit_100(w_digit_100),
        .o_digit_1000(w_digit_1000)
    );
    mux_4x1 U_4x1_MUX (
        .i_digit_1(w_digit_1),
        .i_digit_10(w_digit_10),
        .i_digit_100(w_digit_100),
        .i_digit_1000(w_digit_1000),
        .sel(w_sel),
        .o_digit(w_bcd)
    );

    counter_4 U_COUNTER4 (
        .clk(clk),
        .i_tick(w_1khz_clk),
        .rst(rst),
        .sel(w_sel)
    );

endmodule

module counter_cu (
    input  clk,
    input  rst,
    input  i_enable,
    input  i_mode,
    input  i_clear,
    output o_enable,
    output o_mode,
    output o_clear
);
    parameter [1:0] IDLE = 1'b0, CMD = 1'b1;
    reg n_state, c_state;
    reg n_mode, c_mode;
    reg n_clear, c_clear;
    reg n_enable, c_enable;

    assign o_enable = c_enable;
    assign o_clear  = c_clear;
    assign o_mode   = c_mode;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state  <= IDLE;
            c_mode   <= 0;
            c_clear  <= 0;
            c_enable <= 0;
        end else begin
            c_state  <= n_state;
            c_mode   <= n_mode;
            c_clear  <= n_clear;
            c_enable <= n_enable;
        end
    end

    always @(*) begin
        n_state  = c_state;
        n_mode   = c_mode;
        n_clear  = c_clear;
        n_enable = c_enable;
        case (c_state)
            IDLE: begin

                //if (i_enable == 1 | i_clear == 1 | i_mode == 1) begin
                //n_state = CMD;
                //end
                if (i_enable == 1) begin
                    if (c_enable == 1) begin
                        n_enable = 0;
                    end else begin
                        n_enable = 1;
                    end
                end
                if (i_clear == 1) begin
                    n_clear = 1;
                    n_state = CMD;
                end
                if (i_mode == 1) begin
                    if (c_mode == 1) begin
                        n_mode = 0;
                    end else begin
                        n_mode = 1;
                    end
                end
            end
            CMD: begin
                n_state = IDLE;
                n_clear = 0;
            end

        endcase
    end

endmodule

module counter (

    input         clk,
    input         rst,
    input         i_tick,
    input         mode,
    input         clear,
    output [13:0] counter
);

    reg [13:0] r_counter;
    assign counter = r_counter;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
        end else begin
            if (mode == 0) begin
                if (i_tick) begin
                    r_counter <= r_counter + 1;
                    if (r_counter == 9999) begin
                        r_counter <= 0;
                    end
                end
            end else if (mode == 1) begin
                if (i_tick) begin
                    r_counter <= r_counter - 1;
                    if (r_counter == 0) begin
                        r_counter <= 9999;
                    end
                end
            end
            if (clear) begin
                r_counter <= 0;
            end
        end
    end

endmodule

module fnd_controller (
    input      [3:0] bcd,
    output     [3:0] fnd_com,
    output reg [7:0] fnd_data
);


    always @(bcd) begin
        case (bcd)
            4'b0000: fnd_data = 8'hc0;
            4'b0001: fnd_data = 8'hF9;
            4'b0010: fnd_data = 8'hA4;
            4'b0011: fnd_data = 8'hB0;
            4'b0100: fnd_data = 8'h99;
            4'b0101: fnd_data = 8'h92;
            4'b0110: fnd_data = 8'h82;
            4'b0111: fnd_data = 8'hF8;
            4'b1000: fnd_data = 8'h80;
            4'b1001: fnd_data = 8'h90;
            default: fnd_data = 8'hff;
        endcase
    end
endmodule

module tick_10hz_gen (
    input  clk,
    input  rst,
    input  clear,
    input  enable,
    output o_tick_10hz
);
    reg [$clog2(10_000_000) - 1:0] clk_cnt;
    reg tick_10hz;
    assign o_tick_10hz = tick_10hz;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            tick_10hz <= 0;
            clk_cnt   <= 0;
        end else begin
            if (enable == 0) begin

                if (clk_cnt == 10_000_000) begin
                    tick_10hz <= 1;
                    clk_cnt   <= 0;
                end else begin
                    tick_10hz <= 0;
                    clk_cnt   <= clk_cnt + 1;
                end
                if (clear) begin
                    tick_10hz <= 0;
                    clk_cnt   <= 0;
                end
            end else if (enable == 1) begin
                clk_cnt <= clk_cnt;
            end
        end
    end

endmodule

module digit_splitter (
    input  [13:0] i_counter,
    output [ 3:0] o_digit_1,
    output [ 3:0] o_digit_10,
    output [ 3:0] o_digit_100,
    output [ 3:0] o_digit_1000
);
    reg [3:0] digit_1;
    reg [3:0] digit_10;
    reg [3:0] digit_100;
    reg [3:0] digit_1000;

    assign o_digit_1 = digit_1;
    assign o_digit_10 = digit_10;
    assign o_digit_100 = digit_100;
    assign o_digit_1000 = digit_1000;

    always @(*) begin
        digit_1 = i_counter % 10;
        digit_10 = (i_counter % 100) / 10;
        digit_100 = (i_counter % 1000) / 100;
        digit_1000 = i_counter / 1000;
    end

endmodule

module mux_4x1 (
    input  [3:0] i_digit_1,
    input  [3:0] i_digit_10,
    input  [3:0] i_digit_100,
    input  [3:0] i_digit_1000,
    input  [1:0] sel,
    output [3:0] o_digit
);
    reg [3:0] o_digit_reg;
    assign o_digit = o_digit_reg;
    always @(*) begin
        case (sel)
            2'b00: begin
                o_digit_reg = i_digit_1;
            end
            2'b01: begin
                o_digit_reg = i_digit_10;
            end

            2'b10: begin
                o_digit_reg = i_digit_100;
            end

            2'b11: begin
                o_digit_reg = i_digit_1000;
            end
            default: o_digit_reg = i_digit_1;
        endcase
    end

endmodule

module clk_divider_10khz (
    input  clk,
    input  rst,
    output o_clk_1khz
);

    reg [$clog2(100_000) - 1:0] clk_cnt;
    reg clk_1khz;
    assign o_clk_1khz = clk_1khz;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            clk_1khz <= 0;
            clk_cnt  <= 0;
        end else begin
            if (clk_cnt == 99_999) begin
                clk_1khz <= 1;
                clk_cnt  <= 0;
            end else begin
                clk_cnt  <= clk_cnt + 1;
                clk_1khz <= 0;
            end
        end
    end


endmodule

module counter_4 (
    input        clk,
    input        i_tick,
    input        rst,
    output [1:0] sel
);
    reg [1:0] sel_reg;
    assign sel = sel_reg;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            sel_reg <= 0;
        end else begin
            if (i_tick) begin
                sel_reg <= sel_reg + 1;
            end
        end
    end

endmodule

module decoder_2x4 (
    input      [1:0] sel,
    output reg [3:0] fnd_com
);

    always @(*) begin
        case (sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end

endmodule
