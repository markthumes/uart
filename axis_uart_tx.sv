`timescale 1ns/1ps
`default_nettype none

module axis_uart_tx #(
	parameter CLK_FREQ_HZ  = 10_000_000,
	parameter BAUD_RATE    =      9_600,
	parameter DATA_WIDTH   =          8
)(
	//FPGA Clock and Reset
	input wire 			clk,		//fpga main clock domain clock
	input wire 			rst_sync,	//synchronous reset positive edge

	//AXI4-Stream Interface
	input wire [DATA_WIDTH-1:0] 	tdata,		//data to send
	input wire                 	tvalid,		//data capture/valid signal
	output wire			tready,		//UART inactive
	
	//UART Output
	output reg			out		//data output
);
	/*  X CLK   9600 BITS   1 SECOND
	 *  ----- = --------- * --------
	 *   BITS     SECOND    10M CLK
	 */

`ifdef SIM
	parameter BIT_RATE = 10;
`else
	parameter BIT_RATE = BAUD_RATE / CLK_FREQ_HZ;
`endif

	typedef enum {
		IDLE,	//Wait for data valid signal
		START,	//Register data and start UART
		DATA,	//Shift data out
		STOP	//Stop UART
	} state_t;

	state_t current_state;
	state_t next_state;

	assign tready = ( current_state == IDLE );

	reg [DATA_WIDTH-1:0] shift_register; //capture data here

	//always@(*) begin //Fix [Ref 1]
	always_comb begin
		case( current_state )
			IDLE: begin
				out = 1;
			end
			START: begin
				out = 0;
			end
			DATA: begin
				//[Ref 1]: iverilog Make warning:
				//sorry: constant selects in always_* processes are not 
				//currently supported (all bits will be included).
				out = shift_register[DATA_WIDTH-1];
			end
			STOP: begin
				out = 1;
			end
		endcase
	end

	//create bit counter for current state transfer speed
	reg [$clog2(BIT_RATE)-1:0] bit_ctr = 0;
	wire xfer_rate;
	assign xfer_rate = (bit_ctr == BIT_RATE-1);
	always_ff @(posedge clk) begin
		if( bit_ctr == BIT_RATE-1 || current_state != next_state ) begin
			bit_ctr  <= 0;
		end 
		else begin
			bit_ctr <= bit_ctr + 1;
		end
	end

	reg [$clog2(DATA_WIDTH)-1:0] data_ctr = DATA_WIDTH-1;
	always_ff @(posedge clk) begin
		case( current_state )
			START: begin
				shift_register <= tdata;
				data_ctr <= DATA_WIDTH-1;
			end
			DATA: begin
				//update shift register at the specified rate
				if( xfer_rate ) begin
					data_ctr <= data_ctr - 1;
					// [7][6][5][4][3][2][1][0]
					//  s  x  x  x  x  x  x  x
                                        //  x  x  x  x  x  x  x  0
					shift_register <= 
						{shift_register[DATA_WIDTH-2:0], 1'b0};
				end 
			end
		endcase
		if( rst_sync ) begin
			shift_register <= 0;
			data_ctr <= DATA_WIDTH-1;
		end
	end

	//evaluate conditions for next state
	//Do not transition out of START, DATA, or STOP until at least
	//one UART transmission has occured at the UART rate (xfer_rate)
	always_comb begin
		case( current_state )
			IDLE: begin
				if( tvalid & tready ) begin
					next_state = START;
				end
			end
			START: begin
				if( xfer_rate ) next_state = DATA;
			end
			DATA: begin
				if( xfer_rate && data_ctr == 0 ) next_state = STOP;
			end
			STOP: begin
				if( xfer_rate ) next_state = IDLE;
			end
		endcase
	end

	//create behaviour for next state
	//register next into current
	always_ff @(posedge clk) begin
		current_state <= next_state;
		if( rst_sync ) begin
			current_state <= IDLE;
		end
	end

	
endmodule
