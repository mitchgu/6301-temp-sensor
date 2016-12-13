`default_nettype none

module adc_controller(
  input wire clk,
  input wire comparator,
  output wire ramp_up_sw,
  output wire ramp_down_sw,
  output wire reset_cap_sw,
  output reg [19:0] down_ramp_time,
  output reg eoc // end of conversion
	);
	
  parameter RESET = 2'b00;
  parameter WAIT = 2'b01;
	parameter RAMP_UP = 2'b11; // gray code
	parameter RAMP_DOWN = 2'b10;

  parameter RESET_CYCLES = 6500; // 100us;
	parameter RAMP_UP_CYCLES = 20'd325_000; // 5ms

	reg [1:0] state = RESET;
	reg [19:0] ramp_counter = RESET_CYCLES;

  wire comparator_pulse;
  level_to_pulse comparator_ltp(
    .clk(clk),
    .level(comparator),
    .pulse(comparator_pulse)
    );

  always @(posedge clk) begin
    eoc <= 0;
		case (state)
      RESET: begin
        if (ramp_counter == 0)
          state <= WAIT;
        else ramp_counter = ramp_counter - 1;
      end
      WAIT: begin
        if (~comparator) begin
          ramp_counter <= RAMP_UP_CYCLES;
          state <= RAMP_UP;
        end
      end
			RAMP_UP: begin
				if (ramp_counter == 0) state <= RAMP_DOWN;
				else ramp_counter <= ramp_counter - 1;
			end
			RAMP_DOWN: begin
				if (comparator) begin
          down_ramp_time <= ramp_counter;
          eoc <= 1;
          ramp_counter <= RESET_CYCLES;
          state <= RESET;
				end
				else ramp_counter <= (&ramp_counter) ? ramp_counter : ramp_counter + 1; // prevent overflow
			end
		endcase
  end

  assign ramp_up_sw = (state == RAMP_UP || state == WAIT);
  assign ramp_down_sw = (state == RAMP_DOWN);
  assign reset_cap_sw = (state == RESET);

endmodule