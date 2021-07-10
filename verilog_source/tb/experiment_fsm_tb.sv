
import ising_config::*;
module experiment_fsm_tb();

reg clk, rst;
	
//Run trigger for starting experiment
reg run_trig;
wire run_done;//Done flag for when we've finished processing instructions

//Instruction bus; upper 16 bits are instruction; lower 16 are data for the 32-bit bus coming from cpu
reg [16:0] instr_axis_tdata;
reg instr_axis_tvalid;
wire instr_axis_tready;

//beta in bus////////////////
reg [num_bits-1:0] b_r_tdata;
reg b_r_tvalid;
wire b_r_tready;

//Needed for CPU readback
reg [num_bits-1:0] a_in_data;
reg a_in_valid;
wire a_in_ready;

reg [num_bits-1:0] c_in_data;
reg c_in_valid;
wire c_in_ready;

wire [num_bits-1:0] a_out_data;
wire a_out_valid;
reg a_out_ready;

wire [num_bits-1:0] c_out_data;
wire c_out_valid;
reg c_out_ready;

/////////////////////////////////////

//Outputs to DAC drivers (generated by FSM)
wire [num_bits-1:0] a_out;
wire a_valid;

wire [num_bits-1:0] b_out;
wire b_valid;

wire [num_bits-1:0] c_out;
wire c_valid;


//Inputs from ADC drivers
reg [num_bits-1:0] mac_val_in;
reg mac_val_valid;
wire mac_run;

reg [num_bits-1:0] nl_val_in;
reg nl_val_valid;
wire nl_run;


//Inputs and outputs for delay measurement
reg a_del_meas_trig, bc_del_meas_trig;
reg [num_bits-1:0] del_meas_val;
reg [num_bits-1:0] del_meas_thresh;
wire [15:0] del_meas_mac_result;
wire [15:0] del_meas_nl_result;
wire del_done; //Done flag for when this measurement finishes

reg halt_reg;

wire [2:0] state_out;

wire err_out;


experiment_fsm dut(
	clk, rst,
	
	//Run trigger for starting experiment
	run_trig,
	run_done,//Done flag for when we've finished processing instructions
	
	//Instruction bus, upper 16 bits are instruction, lower 16 are data for the 32-bit bus coming from cpu
	instr_axis_tdata,
	instr_axis_tvalid,
	instr_axis_tready,
	
	//beta in bus////////////////
	b_r_tdata,
	b_r_tvalid,
	b_r_tready,
	
	//Needed for CPU readback
	a_in_data,
	a_in_valid,
	a_in_ready,
	
	c_in_data,
	c_in_valid,
	c_in_ready,

	a_out_data,
	a_out_valid,
	a_out_ready,
	
	c_out_data,
	c_out_valid,
	c_out_ready,

	/////////////////////////////////////
	
	//Outputs to DAC drivers
	a_out,
	a_valid,
	
	b_out,
	b_valid,
	
	c_out,
	c_valid,
	
	
	//Inputs from ADC drivers
	mac_val_in,
	mac_val_valid,
	mac_run,
	
	nl_val_in,
	nl_val_valid,
	nl_run,
	
	
	//Inputs and outputs for delay measurement
	a_del_meas_trig, bc_del_meas_trig,
	del_meas_val,//input wire [num_bits-1:0] del_meas_val,
	del_meas_thresh,//If we reach this value the pulse is consildered as recieved and the timer stops
	del_meas_mac_result,
	del_meas_nl_result,
	del_done, //Done flag for when this measurement finishes
	
	halt_reg, 
	state_out,
	err_out
);

integer i, j, k, num_errs;

initial begin

	//Set and reset everything
	clk <= 0;
	rst <= 1;
	run_trig <= 0;
	instr_axis_tdata <= 0;
	instr_axis_tvalid <= 0;
	b_r_tdata <= 0;
	b_r_tvalid <= 0;
	a_in_data <= 0;
	a_in_valid <= 0;
	c_in_data <= 0;
	c_in_valid <= 0;
	a_out_ready <= 0;
	c_out_ready <= 0;
	
	mac_val_in <= 0;
	mac_val_valid <= 0;
	
	nl_val_in <= 0;
	nl_val_valid <= 0;
	
	halt_reg <= 0;
	
	a_del_meas_trig <= 0;
	bc_del_meas_trig <= 0;
	
	del_meas_thresh <= 0;
	del_meas_val <= 0;
	
	
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(10) clk_cycle();
	
	//Load in some stuff to the a and c fifos
	
	a_in_valid <= 1;
	c_in_valid <= 1;
	
	for(i = 0; i < 8; i = i + 1) begin
		a_in_data <= 8'(i);
		c_in_data <= 8'(i);
		clk_cycle();
	end
	
	a_in_valid <= 0;
	c_in_valid <= 0;
	
	//Try reading that data back outputs
	a_out_ready <= 1;
	c_out_ready <= 1;
	num_errs = 0;
	for(i = 0; i < 8; i = i + 1) begin
		if(a_out_data != 8'(i)) begin
			num_errs = num_errs + 1;
		end
		if(c_out_data != 8'(i)) begin
			num_errs = num_errs + 1;
		end
		clk_cycle();
	end
	
	//Reset the ready lines
	a_out_ready <= 0;
	c_out_ready <= 0;
	$display("\nVar readback test complete, num errs: %x\n", num_errs);
	
	//Now we test the delay measurement functionality by setting up the inputs first
	
	del_meas_val <= 8'h7F;
	del_meas_thresh <= 8'h10;
	
	//Try the A delay measurement first
	a_del_meas_trig <= 1;
	
	repeat(10) clk_cycle();
	//assert the triggering value on the MAC input for one cycle
	mac_val_in <= 8'h3F;
	clk_cycle();
	mac_val_in <= 0;
	repeat(10) clk_cycle();
	
	//Make sure the DEL flag was not asserted here
	if(del_done) begin
		$display("Error, del flag was asserted before measurement finished!\n");
	end
	
	nl_val_in <= 8'h3F;//Do the same thing for NL
	clk_cycle();
	nl_val_in <= 0;
	repeat(100) clk_cycle();
	
	//Check to make sure the done flag was asserted
	if(!del_done) begin
		$display("Error, del flag was not asserted after 100 cycles\n");
	end
	
	//Check to make sure the outputs are correct
	if(del_meas_mac_result != 10) begin
		$display("Error, MAC delay measurement result was wrong!\n");
	end
	if(del_meas_nl_result != 21) begin
		$display("Error, NL delay measurement result was wrong!\n");
	end
	
	$display("A delay measurement test complete");
	
	a_del_meas_trig <= 0;//Reset the del meas trigger
	repeat(10) clk_cycle();//Let it go back into the reset state
	
	//Run the same test for bc
	
	bc_del_meas_trig <= 1;
	
	repeat(14) clk_cycle();
	//assert the triggering value on the MAC input for one cycle
	nl_val_in <= 8'h3F;
	clk_cycle();
	nl_val_in <= 0;
	repeat(28) clk_cycle();
	
	//Make sure the DEL flag was not asserted here
	if(del_done) begin
		$display("Error, del flag was asserted before measurement finished!\n");
	end
	
	mac_val_in <= 8'h3F;//Do the same thing for NL
	clk_cycle();
	mac_val_in <= 0;
	repeat(100) clk_cycle();
	
	//Check to make sure the done flag was asserted
	if(!del_done) begin
		$display("Error, del flag was not asserted after 100 cycles\n");
	end
	
	//Check to make sure the outputs are correct
	if(del_meas_nl_result != 10+4) begin
		$display("Error, MAC delay measurement result was wrong!\n");
	end
	if(del_meas_mac_result != 43) begin
		$display("Error, NL delay measurement result was wrong!\n");
	end
	
	
	$display("BC delay measurement test complete");
	
	bc_del_meas_trig <= 0;//Reset the del meas trigger
	repeat(10) clk_cycle();//Let it go back into the reset state
	
	
	//Load more dummy data into the internal A and C fifos
	
	a_in_valid <= 1;
	c_in_valid <= 1;
	
	//Make b valid so the FSM runs
	b_r_tvalid <= 1;
	
	for(i = 0; i < 8; i = i + 1) begin
		a_in_data <= 8'(i);
		c_in_data <= 8'(i);
		clk_cycle();
	end
	
	a_in_valid <= 0;
	c_in_valid <= 0;
	
	//Feed the FSM some instructions and see what happens
	run_trig <= 1;
	//Tell it to remove a for 8 cycles and verify the output
	instr_axis_tdata <= (1 << 0);
	instr_axis_tvalid <= 1;
	
	//Need one cycle to switch into the run state
	clk_cycle();
	clk_cycle();//and one to push to output
	
	//verify the output
	num_errs <= 0;
	for(i = 0; i < 8; i = i + 1) begin
		clk_cycle();//Cycle clock first so we execute the current instruction
		if(a_out != 8'(i)) begin
			num_errs <= num_errs + 1;
		end
	end
	
	$display("\nA buff readout test complete, num errs: %x\n", num_errs);
	
	//Do the same thing for c
	instr_axis_tdata <= (1 << 2);
	clk_cycle();//and one to push to output
	//verify the output
	num_errs <= 0;
	for(i = 0; i < 8; i = i + 1) begin
		clk_cycle();//Cycle clock first so we execute the current instruction
		if(c_out != 8'(i)) begin
			num_errs <= num_errs + 1;
		end
	end
	
	$display("\nC buff readout test complete, num errs: %x\n", num_errs);

	//Do the same thing for B but this time provide the B input
	instr_axis_tdata <= (1 << 1);
	b_r_tdata <= 8'hff;
	//verify the output
	num_errs <= 0;
	for(i = 0; i < 8; i = i + 1) begin
		clk_cycle();//Cycle clock first so we execute the current instruction
		if(b_out != 8'hff) begin
			num_errs <= num_errs + 1;
		end
	end
	
	$display("\nB buff readout test complete, num errs: %x\n", num_errs);
	
	
	//See if we can get it to add stuff into the buffers from the MAC input
	mac_val_in <= 8'haa;
	mac_val_valid <= 1;
	nl_val_in <= 8'hbb;
	nl_val_valid <= 1;
	
	instr_axis_tdata <= (1 << 3);
	
	//Add it to the a buffer 8 times, but on the last time also do a switch
	repeat(7) clk_cycle();
	instr_axis_tdata <= (1 << 3) | (1 << 7);
	clk_cycle();
	
	//Now do the same thing for the c buffer
	instr_axis_tdata <= (1 << 4);
	
	repeat(8) clk_cycle();
	
	//Now add 4 0s to both A and C
	instr_axis_tdata <= (1 << 5) | (1 << 6);
	
	repeat(4) clk_cycle();
	
	instr_axis_tdata <= 0;
	instr_axis_tvalid <= 0;//Halt the FSM here
	run_trig <= 0;
	halt_reg <= 1;
	
	repeat(100) clk_cycle();
	
	//Read out A and see what we get
	a_out_ready <= 1;
	num_errs <= 0;
	for(i = 0; i < 8+4; i = i + 1) begin
		if(i < 8) begin//Should be 0xaa
			if(a_out_data != 8'haa) begin
				num_errs <= num_errs + 1;
			end
		end
		else begin//Should be 0
			if(a_out_data) begin
				num_errs <= num_errs + 1;
			end
		end
		clk_cycle();
	end
	
	a_out_ready <= 0;
	$display("\nA buff write+read test complete, num errs: %x\n", num_errs);
	
	//Read out C and see what we get
	c_out_ready <= 1;
	num_errs <= 0;
	for(i = 0; i < 8+4; i = i + 1) begin
		if(i < 8) begin//Should be 0xbb
			if(c_out_data != 8'hbb) begin
				num_errs <= num_errs + 1;
			end
		end
		else begin//Should be 0
			if(c_out_data) begin
				num_errs <= num_errs + 1;
			end
		end
		clk_cycle();
	end
	
	c_out_ready <= 0;
	$display("\nC buff write+read test complete, num errs: %x\n", num_errs);
	
	
	
	
	
	

end

task clk_cycle();
begin
	#1
	clk <= 1;
	#1
	#1
	clk <= 0;
	#1
	clk <= 0;
end
endtask

endmodule 


