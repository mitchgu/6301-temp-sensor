`timescale 1ns / 1ps
`default_nettype none

// Switch Debounce Module
// use your system clock for the clock input
// to produce a synchronous, debounced output

module debounce #(parameter DELAY=1000000, parameter COUNT=1) (
    input wire clk,
    input wire reset,
    input wire [COUNT-1:0] noisy,
    output reg [COUNT-1:0] clean);

    genvar i;
    generate
        for (i = 0; i < COUNT; i = i + 1) begin
            reg [19:0] count;
            reg new;

            always @(posedge clk) begin
                if (reset) begin
                    count <= 0;
                    new <= noisy[i];
                    clean[i] <= noisy[i];
                end
                else if (noisy[i] != new) begin
                    new <= noisy[i];
                    count <= 0;
                end
                else if (count == DELAY)
                    clean[i] <= new;
                else
                    count <= count+1;
            end
        end
    endgenerate
      
endmodule

module level_to_pulse (
    input wire clk,
    input wire level,
    output wire pulse);

    reg last_level;
    always @(posedge clk) begin
        last_level <= level;
    end
    assign pulse = level & ~last_level;

endmodule

// pulse synchronizer
module synchronize #(parameter NSYNC = 2) ( // number of sync flops.  must be >= 2
    input wire clk,in,
    output reg out);

  reg [NSYNC-2:0] sync;

  always @ (posedge clk)
  begin
    {out,sync} <= {sync[NSYNC-2:0],in};
  end
endmodule

////////////////////////////////////////////////////////////////////////////////
//
// xvga: Generate XVGA display signals (1024 x 768 @ 60Hz)
//
////////////////////////////////////////////////////////////////////////////////

module xvga(
    input wire vclock,
    output reg [10:0] hcount,    // pixel number on current line
    output reg [9:0] vcount,     // line number
    output reg vsync, hsync, blank);

    // horizontal: 1344 pixels total
    // display 1024 pixels per line
    reg hblank,vblank;
    wire hsyncon,hsyncoff,hreset,hblankon;
    assign hblankon = (hcount == 1023);
    assign hsyncon = (hcount == 1047);
    assign hsyncoff = (hcount == 1183);
    assign hreset = (hcount == 1343);

    // vertical: 806 lines total
    // display 768 lines
    wire vsyncon,vsyncoff,vreset,vblankon;
    assign vblankon = hreset & (vcount == 767);
    assign vsyncon = hreset & (vcount == 776);
    assign vsyncoff = hreset & (vcount == 782);
    assign vreset = hreset & (vcount == 805);

    // sync and blanking
    wire next_hblank,next_vblank;
    assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
    assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
    always @(posedge vclock) begin
        hcount <= hreset ? 0 : hcount + 1;
        hblank <= next_hblank;
        hsync <= hsyncon ? 0 : hsyncoff ? 1 : hsync;  // active low

        vcount <= hreset ? (vreset ? 0 : vcount + 1) : vcount;
        vblank <= next_vblank;
        vsync <= vsyncon ? 0 : vsyncoff ? 1 : vsync;  // active low

        blank <= next_vblank | (next_hblank & ~hreset);
    end
endmodule
