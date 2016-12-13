`default_nettype none

module median_filter(
	input wire clk,
	input wire [9:0] x,
	input wire start,
	output reg [9:0] y,
	output reg eoc
	);

	reg [9:0] a;
	reg [9:0] b;
	wire [9:0] c = x;

	always @(posedge clk) begin
		if (start) begin
			a <= b;
			b <= c;
			eoc <= 1;

			if ((a >= b && b >= c) || (a <= b && b <= c)) y <= b;
			else if ((b >= a && a >= c) || (b <= a && a <= c)) y <= a;
			else y <= c;
		end
		else eoc <= 0;
	end

endmodule