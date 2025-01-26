`default_nettype none
`timescale 1ns/1ps

`ifndef SIM_TIME_NS
	`define SIM_TIME_NS 1_000
`endif
`ifndef WAVE_FILE
	`define WAVE_FILE "sim.vcd"
`endif

module test_uart_tx();
	parameter CLK_RATE_HZ 	= 125_000_000;
	parameter CLK_RATE_MHZ 	= CLK_RATE_HZ / 1_000_000;
	parameter CLK_PERIOD_NS = 1_000 / CLK_RATE_MHZ;
	parameter FULL_CLK 	= CLK_PERIOD_NS;
	parameter HALF_CLK	= FULL_CLK / 2;

	reg CLK;
	reg RST;

	initial CLK = 0;
	initial RST = 0;

	//create initial synchronous reset ( must be longer than a clock pulse )
	initial begin
		#(1*FULL_CLK);
		RST = 1;
		#(1*FULL_CLK);
		RST = 0;
	end

	wire uart_tready;

	//generate clock
	always begin
		#(HALF_CLK);
		CLK = ~CLK;
	end

	//generate data valid signal
	wire 		OUT;
	reg [7:0] 	DATA = 8'hc5;
	reg 		DV   = 0;
	initial begin
		#(2*FULL_CLK);
		if( uart_tready )
			DV = 1;
		#(1*FULL_CLK);
		DV = 0;
	end


	axis_uart_tx #(
		.CLK_FREQ_HZ(CLK_RATE_HZ),
		.BAUD_RATE(9_600),
		.DATA_WIDTH(8)
	)axis_uart_tx(
		.clk(CLK),
		.rst_sync(RST),
		.tdata(DATA),
		.tvalid(DV),
		.tready(uart_tready),
		.out(OUT)
	);

	//--------------- RUN SIM  ---------------//
	initial begin
		#(`SIM_TIME_NS);
		$finish;
	end

	//--------------- SIM DUMP ---------------//
	initial begin
		$dumpfile(`WAVE_FILE);
		$dumpvars(0, test_uart_tx);
	end

endmodule
