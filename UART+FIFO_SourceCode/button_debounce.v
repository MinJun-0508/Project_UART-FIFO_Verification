`timescale 1ns / 1ps

module button_debounce (
    input  clk,
    input  rst,
    input  i_btn,
    output o_btn
);

    parameter [2:0] IDLE = 3'b000, detect_1 = 3'b001, detect_2 = 3'b010, detect_3 = 3'b011, WAIT = 3'b100;
    reg [2:0] c_state, n_state;
    reg o_btn_reg, o_btn_next;

    assign o_btn = o_btn_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            o_btn_reg <= 0;
            c_state   <= IDLE;
        end else begin
            o_btn_reg <= o_btn_next;
            c_state   <= n_state;
        end
    end

    always @(*) begin
        o_btn_next = o_btn_reg;
        n_state = c_state;
        case (c_state)
            IDLE: begin
                if (i_btn == 1) begin
                    n_state = detect_1;
                end
            end

            detect_1: begin
                if (i_btn == 1) begin
                    n_state = detect_2;
                end else begin
                    n_state = IDLE;
                end
            end

            detect_2: begin
                if (i_btn == 1) begin
                    n_state = detect_3;
                end else begin
                    n_state = IDLE;
                end
            end

            detect_3: begin
                if (i_btn == 1) begin
                    n_state = WAIT;
                    o_btn_next = 1;
                end else begin
                    n_state = IDLE;
                end
            end

            WAIT: begin
                o_btn_next = 0;
                if (i_btn == 1) begin
                    n_state = WAIT;
                end else begin
                    n_state = IDLE;
                end
            end
        endcase
    end

endmodule
