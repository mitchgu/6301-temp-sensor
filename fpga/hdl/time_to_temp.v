`default_nettype none

module time_to_temp(
    input wire clk,
    input wire [19:0] down_ramp_time,
    input wire start,
    output reg [9:0] temp,
    output reg oor, // out of range
    output reg eoc // end of conversion
    );

    parameter IDLE = 0;
    parameter DIVIDING = 1;
    reg state = IDLE;

    // reg [19:0] cycles_0C = 20'd331_564;
    // reg [19:0] cycles_100C = 20'd452_833;
    //reg [19:0] cycles_0C = 20'd537_195;
    //reg [19:0] cycles_100C = 20'd733_862;
    // reg [19:0] cycles_0C = 20'd530_671;
    // reg [19:0] cycles_100C = 20'd694_167;
    // reg [19:0] cycles_0C = 20'd511964;
    // reg [19:0] cycles_100C = 20'd729379;

    reg [19:0] cycles_0C = 20'd508066;
    reg [19:0] cycles_100C = 20'd762679;
    // reg [19:0] cycles_0C = 20'd519_449;
    // reg [19:0] cycles_100C = 20'd720430;

    wire in_range = down_ramp_time > cycles_0C && down_ramp_time < cycles_100C;

    // Declarations for divider module
    reg [19:0] divisor; 
    reg [29:0] dividend;
    reg start_division;
    wire [55:0] dout;
    wire [29:0] quotient = dout[53:24];
    wire [19:0] remainder = dout[19:0];
    wire division_done;
    time_to_temp_divider tttd(
        .aclk(clk),
        .s_axis_divisor_tdata({4'b0, divisor}),
        .s_axis_divisor_tvalid(start_division),
        .s_axis_dividend_tdata({2'b0, dividend}),
        .s_axis_dividend_tvalid(start_division),
        .m_axis_dout_tdata(dout),
        .m_axis_dout_tvalid(division_done)
        );

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (in_range) begin
                        start_division <= 1;
                        dividend <= (down_ramp_time - cycles_0C) * 1000;
                        divisor <= cycles_100C - cycles_0C;
                        state <= DIVIDING;
                    end
                    else begin
                        oor <= 1;
                        eoc <= 1;
                    end
                end
                else eoc <= 0;
            end
            DIVIDING: begin
                start_division <= 0;
                if (division_done) begin
                    temp <= quotient[9:0];
                    oor <= 0;
                    eoc <= 1;
                    state <= IDLE;
                end
            end
        endcase
    end

    // lifesaver ls(
    //     .clk(clk),
    //     .probe0(start),
    //     .probe1(down_ramp_time),
    //     .probe2(dividend),
    //     .probe3(divisor),
    //     .probe4(quotient),
    //     .probe5(oor),
    //     .probe6(eoc));

endmodule