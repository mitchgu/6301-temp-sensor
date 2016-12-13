`default_nettype none

module scope(
	input wire clk,
	input wire reset,
	input wire [2:0] ck_an_p,
	input wire [2:0] ck_an_n,
	input wire trigger,
	input wire can_commit,
	input wire [9:0] waveform_addr,
	output wire [9:0] integrator_dout,
	output wire [9:0] comparator_dout,
	output reg [9:0] vptat
	);

	parameter INTEGRATOR_DADDR = 7'h11;
	parameter COMPARATOR_DADDR = 7'h19;
	parameter VPTAT_DADDR = 7'h16;

	wire eoc, eos;
	reg [6:0] daddr_in;
	wire [15:0] do_out;
	xadc_wiz_0 xadc (
	  .dclk_in(clk),          // input wire dclk_in
	  .di_in(0),              // input wire [15 : 0] di_in
	  .daddr_in(daddr_in),        // input wire [6 : 0] daddr_in
	  .den_in(1),            // input wire den_in
	  .dwe_in(0),            // input wire dwe_in
	  .drdy_out(),        // output wire drdy_out
	  .do_out(do_out),            // output wire [15 : 0] do_out
	  .reset_in(reset),        // input wire reset_in
	  .vp_in(0),              // input wire vp_in
	  .vn_in(0),              // input wire vn_in
	  .vauxp1(ck_an_p[0]),            // input wire vauxp1
	  .vauxn1(ck_an_n[0]),            // input wire vauxn1
	  .vauxp6(ck_an_p[2]),            // input wire vauxp6
	  .vauxn6(ck_an_n[2]),            // input wire vauxn6
	  .vauxp9(ck_an_p[1]),            // input wire vauxp9
	  .vauxn9(ck_an_n[1]),            // input wire vauxn9
	  .channel_out(),  // output wire [4 : 0] channel_out
	  .eoc_out(eoc),          // output wire eoc_out
	  .alarm_out(),      // output wire alarm_out
	  .eos_out(eos),          // output wire eos_out
	  .busy_out()        // output wire busy_out
	);

	parameter WAIT_FOR_TRIGGER = 2'b00;
	parameter WAIT_FOR_EOS = 2'b01;
	parameter WRITE = 2'b11;
	parameter WAIT_FOR_COMMIT = 2'b10;

	reg [2:0] state = WAIT_FOR_TRIGGER;
	reg committed_ram = 0;

	reg integrator_we;
	reg [9:0] waddr = 0;
	wire [9:0] integrator_dout_a;
	wire integrator_we_a;
    video_bram integrator_ram_a(
        .clka(clk),
        .addra(waddr),
        .dina(do_out[11:2]),
        .wea(integrator_we),
        .clkb(clk),
        .addrb(waveform_addr),
        .doutb(integrator_dout_a)
        );

	wire [9:0] integrator_dout_b;
	wire integrator_we_b;
    video_bram integrator_ram_b(
        .clka(clk),
        .addra(waddr),
        .dina(do_out[11:2]),
        .wea(integrator_we),
        .clkb(clk),
        .addrb(waveform_addr),
        .doutb(integrator_dout_b)
        );

    assign integrator_we_a = integrator_we && committed_ram;
    assign integrator_we_b = integrator_we && ~committed_ram;
    assign integrator_dout = committed_ram ? integrator_dout_b : integrator_dout_a;

	reg comparator_we;
	wire [9:0] comparator_dout_a;
	wire comparator_we_a;
    video_bram comparator_ram_a(
        .clka(clk),
        .addra(waddr),
        .dina(do_out[11:2]),
        .wea(comparator_we),
        .clkb(clk),
        .addrb(waveform_addr),
        .doutb(comparator_dout_a)
        );

	wire [9:0] comparator_dout_b;
	wire comparator_we_b;
    video_bram coparator_ram_b(
        .clka(clk),
        .addra(waddr),
        .dina(do_out[11:2]),
        .wea(comparator_we),
        .clkb(clk),
        .addrb(waveform_addr),
        .doutb(comparator_dout_b)
        );

    assign comparator_we_a = comparator_we && ~committed_ram;
    assign comparator_we_b = comparator_we && committed_ram;
    assign comparator_dout = committed_ram ? comparator_dout_b : comparator_dout_a;

	reg [9:0] sample_counter;
	reg [1:0] write_counter;
	always @(posedge clk) begin
		integrator_we <= 0; comparator_we <= 0;
		case (state)
			WAIT_FOR_TRIGGER: begin
				if (trigger) begin
					state <= WAIT_FOR_EOS;
					sample_counter <= 0;
				end
			end
			WAIT_FOR_EOS: begin
				if (eos) begin
					state <= WRITE;
					write_counter <= 0;
					daddr_in <= INTEGRATOR_DADDR;
				end
			end
			WRITE: begin
				if (write_counter == 0) begin
					integrator_we <= 1;
					daddr_in <= COMPARATOR_DADDR;
				end
				else if (write_counter == 1) begin
					comparator_we <= 1;
					daddr_in <= VPTAT_DADDR;
				end
				else if (write_counter == 2) begin
					vptat <= do_out[9:0];
					if (&sample_counter)
						state <= WAIT_FOR_COMMIT;
					else begin
						state <= WAIT_FOR_EOS;
						sample_counter <= sample_counter + 1;
					end
				end
				write_counter <= write_counter + 1;
			end
			WAIT_FOR_COMMIT: begin
				if (can_commit) begin
					state <= WAIT_FOR_TRIGGER;
					committed_ram <= ~committed_ram;
				end
			end
		endcase
	end

endmodule
