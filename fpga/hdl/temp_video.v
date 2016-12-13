`default_nettype none

module temp_video(
    input wire clk,
    input wire reset,
    input wire [2:0] ck_an_p,
    input wire [2:0] ck_an_n,
    input wire [9:0] temp,
    input wire trigger,
    output reg [23:0] pixel,
    output wire hsync,
    output wire vsync,
    output wire blank
    );

    // INSTANTIATE XVGA SIGNALS
    wire [10:0] hcount;
    wire [9:0] vcount;
    wire hsync_in, vsync_in, blank_in;
    xvga xvga1(
        .vclock(clk),
        .hcount(hcount),
        .vcount(vcount),
        .vsync(vsync_in),
        .hsync(hsync_in),
        .blank(blank_in));
    wire [9:0] y = 'd767 - vcount;
    wire eof = hcount == 1024 && vcount == 768; // end of frame

    wire [9:0] vptat;
    wire [9:0] integrator_dout, comparator_dout;
    scope sco(
        .clk(clk),
        .reset(reset),
        .ck_an_p(ck_an_p),
        .ck_an_n(ck_an_n),
        .trigger(trigger),
        .can_commit(eof),
        .waveform_addr(hcount[9:0]),
        .integrator_dout(integrator_dout),
        .comparator_dout(comparator_dout),
        .vptat(vptat)
        );

    reg [9:0] temp_waddr = 0;
    reg temp_we;
    wire [9:0] temp_raddr, temp_rdata;
    video_bram temp_ram(
        .clka(clk),
        .addra(temp_waddr),
        .dina(temp),
        .wea(temp_we),
        .clkb(clk),
        .addrb(temp_raddr),
        .doutb(temp_rdata)
        );

    reg [9:0] vptat_waddr = 0;
    reg vptat_we;
    wire [9:0] vptat_raddr, vptat_rdata;
    video_bram vptat_ram(
        .clka(clk),
        .addra(vptat_waddr),
        .dina(vptat),
        .wea(vptat_we),
        .clkb(clk),
        .addrb(vptat_raddr),
        .doutb(vptat_rdata)
        );

    reg [1:0] hsync_reg, vsync_reg, blank_reg;
    assign temp_raddr = temp_waddr + hcount;
    assign vptat_raddr = vptat_waddr + hcount;
    always @(posedge clk) begin
        if (eof) begin
            temp_we <= 1;
            temp_waddr <= temp_waddr + 1;
            vptat_we <= 1;
            vptat_waddr <= vptat_waddr + 1;
        end else temp_we <= 0;

        hsync_reg <= {hsync_reg[0], hsync_in};     
        vsync_reg <= {vsync_reg[0], vsync_in};     
        blank_reg <= {blank_reg[0], blank_in};
        if (y < 512) begin
            if (temp_rdata >> 1 ==  y) pixel <= 24'hFF_44_44;
            else if (vptat_rdata >> 1 == y) pixel <= 24'h00_00_FF;
            else if (temp_rdata >> 1 > y) pixel <= 24'hA3_28_28;
            else pixel <= 24'hFF_BF_BF;
        end else begin
            if (integrator_dout >> 2 == y - 512) pixel <= 24'h00_FF_00;
            else if (comparator_dout >> 2 == y - 512) pixel <= 24'h00_00_FF;
            else pixel <= 24'hFF_FF_FF;
        end
    end
    assign hsync = hsync_reg[1];
    assign vsync = vsync_reg[1];
    assign blank = blank_reg[1];

endmodule