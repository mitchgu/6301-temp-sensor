`timescale 1ns / 1ps
`default_nettype none

module main (
    input wire sysclk,
    input wire [2:0] ck_an_p,
    input wire [2:0] ck_an_n,
    input wire [1:0] sw, 
    input wire [3:0] btn,
    output wire [3:0] led, // LEDs above switches
    output wire [2:0] led_l,
    output wire [2:0] led_r,
    inout wire [7:0] ja,
    output wire hdmi_tx_clk_p,
    output wire hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_d_p,
    output wire [2:0] hdmi_tx_d_n,
    input wire hdmi_tx_hpdn,
    output wire hdmi_tx_cec,
    output wire hdmi_tx_scl,
    output wire hdmi_tx_sda
    );

    ///////////////////////////////////////////////////////////////
    // SETUP

    // Clock generation
    wire clk_65mhz;
    wire clk_325mhz;
    clk_wiz_0 clkgen(
        .clk_in1(sysclk),
        .clk_out1(clk_65mhz),
        .clk_out2(clk_325mhz));

    // Debouncing
    wire [3:0] btn_clean;
    wire [1:0] sw_clean;
    debounce #(.COUNT(6)) debouncer(
        .clk(clk_65mhz),
        .reset(1'b0),
        .noisy({btn, sw}),
        .clean({btn_clean, sw_clean}));

    ///////////////////////////////////////////////////////////////
    
    wire comparator;
    wire startup = 0;
    wire ramp_up_sw, ramp_down_sw, reset_cap_sw;
    wire seg_ser, seg_clk;

    // Pmod port A
    assign ja[0] = 1'b0;
    assign comparator = ja[1];
    assign ja[2] = reset_cap_sw;
    assign ja[3] = startup;
    assign ja[4] = ramp_up_sw;
    assign ja[5] = ramp_down_sw;
    assign ja[6] = seg_ser;
    assign ja[7] = seg_clk;

    // assign led_ser = btn_clean[2];
    // assign led_clk = btn_clean[1];

    wire [19:0] down_ramp_time;
    wire eoac; // End of ADC conversion
    adc_controller adcc(
    	.clk(clk_65mhz),
    	.comparator(comparator),
    	.ramp_up_sw(ramp_up_sw),
    	.ramp_down_sw(ramp_down_sw),
        .reset_cap_sw(reset_cap_sw),
        .down_ramp_time(down_ramp_time),
        .eoc(eoac)
    	);

    wire [9:0] temp;    // Ten bit temperature: temp in celsius times 10 (0 - 1000)
    wire oor;           // Out of range
    wire eotc;          // End of temp conversion
    time_to_temp ttt(
        .clk(clk_65mhz),
        .down_ramp_time(down_ramp_time >> sw_clean),
        .start(eoac),
        .temp(temp),
        .oor(oor),
        .eoc(eotc)
        );

    wire eofc;
    wire [9:0] filtered_temp;
    median_filter dmf(
        .clk(clk_65mhz),
        .x(temp),
        .start(eotc),
        .y(filtered_temp),
        .eoc(eofc)
        );

    temp_to_seg tts(
        .clk(clk_65mhz),
        .temp(filtered_temp),
        .oor(oor),
        .start(eofc),
        .seg_ser(seg_ser),
        .seg_clk(seg_clk)
        );

    wire [23:0] pixel;
    wire hsync, vsync, blank;
    temp_video tv(
        .clk(clk_65mhz),
        .reset(btn_clean[0]),
        .ck_an_p(ck_an_p),
        .ck_an_n(ck_an_n),
        .temp(filtered_temp),
        .trigger(comparator),
        .pixel(pixel),
        .hsync(hsync),
        .vsync(vsync),
        .blank(blank)
        );

    // HDMI OUTPUT
    hdmi_source hdmi_out(
        .clk(clk_65mhz),
        .clk_5x(clk_325mhz),
        .reset(btn_clean[0]),
        .red(pixel[23:16]),
        .green(pixel[15:8]),
        .blue(pixel[7:0]),
        .hsync(hsync),
        .vsync(vsync),
        .de(~blank),
        .hdmi_tx_clk_p(hdmi_tx_clk_p),
        .hdmi_tx_clk_n(hdmi_tx_clk_n),
        .hdmi_tx_d_p(hdmi_tx_d_p),
        .hdmi_tx_d_n(hdmi_tx_d_n));
    assign hdmi_tx_cec = 1'bZ;
    assign hdmi_tx_scl = 1'bZ;
    assign hdmi_tx_sda = 1'bZ;

    // LED Outputs
    assign led_l = {3{ramp_up_sw}};
    assign led_r = {3{ramp_down_sw}};
    assign led[3] = comparator;
    assign led[2] = oor;
    assign led[1] = eotc;
    assign led[0] = 0;

endmodule