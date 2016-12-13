`default_nettype none

module temp_to_seg(
	input wire clk,
	input wire [9:0] temp,
	input wire oor,
	input wire start,
	output reg seg_ser,
	output reg seg_clk
	);

	parameter IDLE = 2'b00;
	parameter BCD = 2'b01;
	parameter SETUP_SERIALIZE = 2'b11;
	parameter SERIALIZE = 2'b10;

	reg [2:0] state = IDLE;

	reg bcd_start;
	wire [3:0] bcd2;
	wire [3:0] bcd1;
	wire [3:0] bcd0;
	wire bcd_done;

	temp_to_bcd ttb(
		.clk(clk),
		.temp(temp),
		.start(bcd_start),
		.d2(bcd2),
		.d1(bcd1),
		.d0(bcd0),
		.done(bcd_done));

	reg [3:0] d3;
	reg [3:0] d2;
	reg [3:0] d1;
	reg [3:0] d0;
	reg [3:0] dp;

	wire [31:0] ser;
	reg [32:0] ser_reg;
	reg [7:0] ser_counter;
	serialize_digits sd(
		.d3(d3),
		.d2(d2),
		.d1(d1),
		.d0(d0),
		.dp(dp),
		.ser(ser));

	reg [9:0] clk_counter;

	always @(posedge clk) begin
		case (state)
			IDLE: begin
				if (start) begin
					if (oor) begin
						{d3, d2, d1, d0} <= 16'hDEAD;
						dp <= 4'b0000;
						state <= SERIALIZE;
					end else begin
						bcd_start <= 1;
						state <= BCD;
					end
				end
			end
			BCD: begin
				bcd_start <= 0;
				if (bcd_done) begin
					{d3, d2, d1, d0} <= {bcd2, bcd1, bcd0, 4'hC};
					dp <= 4'b0100;
					state <= SETUP_SERIALIZE;
				end
			end
			SETUP_SERIALIZE: begin
				ser_reg <= ser;
				ser_counter <= 33;
				clk_counter <= 0;
				state <= SERIALIZE;
			end
			SERIALIZE: begin
				if (clk_counter == 0) begin
					if (ser_counter == 0) begin
						state <= IDLE;
					end else begin
						seg_ser <= ~ser_reg[0];
						ser_reg <= ser_reg >> 1;
						ser_counter <= ser_counter - 1;
					end
				end
				clk_counter <= clk_counter + 1;
				seg_clk <= clk_counter[9];
			end
		endcase
	end
endmodule

module temp_to_bcd(
	input wire clk,
	input wire [9:0] temp,
	input wire start,
	output reg [3:0] d2,
	output reg [3:0] d1,
	output reg [3:0] d0,
	output reg done
	);

	parameter IDLE = 0;
	parameter CONVERTING = 1;
	reg state = IDLE;
	reg [9:0] temp_reg;

	wire carry_d0 = d0 == 4'd9;
	wire [3:0] next_d0 =  (carry_d0) ? 4'd0 : d0 + 1;
	wire [3:0] next_d1 = (carry_d0) ? ((d1 == 4'd9) ? 4'd0 : d1 + 1) : d1;
	wire carry_d1 = (carry_d0 && d1 == 4'd9);
	wire [3:0] next_d2 = (carry_d1) ? d2 + 1 : d2;

	always @(posedge clk) begin
		case (state)
			IDLE: begin
				d0 <= 0;
				d1 <= 0;
				d2 <= 0;
				done <= 0;
				if (start) begin
					temp_reg <= temp;
					state <= CONVERTING;
				end
			end
			CONVERTING: begin
				d2 <= next_d2;
				d1 <= next_d1;
				d0 <= next_d0;
				if (temp_reg == 0) begin
					done <= 1;
					state <= IDLE;
				end else temp_reg <= temp_reg - 1;
			end
		endcase
	end

endmodule

module serialize_digits(
	input wire [3:0] d3,
	input wire [3:0] d2,
	input wire [3:0] d1,
	input wire [3:0] d0,
	input wire [3:0] dp,
	output wire [31:0] ser
	);

	wire [6:0] s3;
	wire [6:0] s2;
	wire [6:0] s1;
	wire [6:0] s0;
	hex_to_seg h2s_3(.hex(d3), .seg(s3));
	hex_to_seg h2s_2(.hex(d2), .seg(s2));
	hex_to_seg h2s_1(.hex(d1), .seg(s1));
	hex_to_seg h2s_0(.hex(d0), .seg(s0));

	assign ser[31:28] = {s3[6], s3[5], s3[0], s3[1]};
	assign ser[27:24] = {s2[6], s2[5], s2[0], s2[1]};
	assign ser[23:20] = {s1[6], s1[5], s1[0], s1[1]};
	assign ser[19:16] = {s0[6], s0[5], s0[0], s0[1]};
	assign ser[15:12] = {dp[0], s0[2], s0[3], s0[4]};
	assign ser[11:8] = {dp[1], s1[2], s1[3], s1[4]};
	assign ser[7:4] = {dp[2], s2[2], s2[3], s2[4]};
	assign ser[3:0] = {dp[3], s3[2], s3[3], s3[4]};

	// gfab gfab gfab gfab
	// edcp edcp edcp edcp
	//
	// 6501 6501 6501 6501
	// 432p 432p 432p 432p

endmodule

module hex_to_seg(
    input wire [3:0] hex,
    output reg [6:0] seg // ABCDEFG
    );

    always @ * begin
        case (hex)
            4'h0: seg = 7'b0111111;
            4'h1: seg = 7'b0000110;
            4'h2: seg = 7'b1011011;
            4'h3: seg = 7'b1001111;
            4'h4: seg = 7'b1100110;
            4'h5: seg = 7'b1101101;
            4'h6: seg = 7'b1111101;
            4'h7: seg = 7'b0000111;
            4'h8: seg = 7'b1111111;
            4'h9: seg = 7'b1101111;
            4'hA: seg = 7'b1110111;
            4'hB: seg = 7'b1111100;
            4'hC: seg = 7'b0111001;
            4'hD: seg = 7'b1011110;
            4'hE: seg = 7'b1111001;
            4'hF: seg = 7'b1110001;
        endcase
    end

endmodule
