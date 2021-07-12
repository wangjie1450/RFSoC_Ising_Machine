
import ising_config::*;


module experiment_top_level
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	output wire [15:0] gpio_out_bus,
	
	
	//Outputs to DACs/////////////////
	output wire [255:0] m0_axis_tdata,
	output wire m0_axis_tvalid,
	input wire m0_axis_tready,
	
	output wire [255:0] m1_axis_tdata,
	output wire m1_axis_tvalid,
	input wire m1_axis_tready,
	
	output wire [255:0] m2_axis_tdata,
	output wire m2_axis_tvalid,
	input wire m2_axis_tready,
	//////////////////////////////////
	
	//Inputs from ADCs////////////////
	input wire [127:0] s0_axis_tdata,
	input wire s0_axis_tvalid,
	output wire s0_axis_tready,
	
	input wire [127:0] s1_axis_tdata,
	input wire s1_axis_tvalid,
	output wire s1_axis_tready,
	//////////////////////////////////
	
	//Input from CPU over DMA/////////
	input wire [127:0] s2_axis_tdata,
	input wire s2_axis_tvalid,
	output wire s2_axis_tready,
	//////////////////////////////////
	
);

assign m0_axis_tvalid = 1;
assign m1_axis_tvalid = 1;
assign m2_axis_tvalid = 1;

assign s0_axis_tready = 1;
assign s1_axis_tready = 1

//Experiment FSM instantiation
//Run trigger for starting experiment
wire run_trig;
wire run_done;//Done flag for when we've finished processing instructions

//run trigger gpio register
wire [7:0] run_trig_out;
assign run_trig = run_trig_out[0];
config_reg #(8,1,16,run_trig_reg) run_trig_reg_inst (clk, rst, gpio_in, run_trig_out);

//Instruction bus; upper 16 bits are instruction; lower 16 are data for the 32-bit bus coming from cpu
wire [16:0] instr_axis_tdata;
wire instr_axis_tvalid;
wire instr_axis_tready;

//beta in bus////////////////
wire [num_bits-1:0] b_r_tdata;
wire b_r_tvalid;
wire b_r_tready;



//Needed for CPU readback
wire [num_bits-1:0] a_in_data;
wire a_in_valid;
wire a_in_ready;

wire [num_bits-1:0] c_in_data;
wire c_in_valid;
wire c_in_ready;

//Allows CPU to load A and C fifos over gpio
gpio_axis_writer #(a_write_addr,c_write_addr) gpio_axis_writer_inst
(
	clk, rst,
	
	gpio_in,
	
	a_in_data,
	a_in_valid,
	a_in_ready,
	
	c_in_data,
	c_in_valid,
	c_in_ready
);



wire [num_bits-1:0] a_out_data;
wire a_out_valid;
wire a_out_ready;

wire [num_bits-1:0] c_out_data;
wire c_out_valid;
wire c_out_ready;


//GPIO reader instantiation
wire [15:0] gpio_out;
wire [127:0] mac_adc_data, nl_adc_data;
wire mac_adc_valid, mac_adc_ready, nl_adc_valid, nl_adc_ready;
gpio_reader
(
	clk, rst,
	
	gpio_in,
	
	gpio_out,
	
	valid,//1 if read was successful (if data was available in the a/c fifo)

	//Inputs to be read out over gpio
	del_meas_mac_result, del_meas_nl_result,
	
	a_out_data,
	a_out_valid,
	a_out_ready,
	
	c_out_data,
	c_out_valid,
	c_out_ready,
	
	mac_adc_data,
	mac_adc_valid,
	mac_adc_ready,
	
	nl_adc_data,
	nl_adc_valid,
	nl_adc_ready,
	
	instr_count,
	b_count
);






/////////////////////////////////////

//Outputs to DAC drivers (generated by FSM)
wire [num_bits-1:0] a_out;
wire a_valid;

wire [num_bits-1:0] b_out;
wire b_valid;

wire [num_bits-1:0] c_out;
wire c_valid;


//Inputs from ADC drivers
wire [num_bits-1:0] mac_val_in;
wire mac_val_valid;
wire mac_run;

wire [num_bits-1:0] nl_val_in;
wire nl_val_valid;
wire nl_run;


//Inputs and outputs for delay measurement
wire a_del_meas_trig, bc_del_meas_trig;

//Config reg for delay measurement triggers
wire [7:0] del_trig_out;
assign a_del_meas_trig = del_trig_out[0];
assign bc_del_meas_trig = del_trig_out[1];
config_reg #(8,1,16,del_trig_reg) del_trig_reg_inst (clk, rst, gpio_in, del_trig_out);

wire [num_bits-1:0] del_meas_val;
wire [num_bits-1:0] del_meas_thresh;

//Config reg for delay val and thresh
wire [15:0] del_meas_val_out, del_meas_thresh_out;
assign del_meas_val = del_meas_val_out[num_bits-1:0];
assign del_meas_thresh = del_meas_thresh_out[num_bits-1:0];
config_reg #(8,2,16,del_meas_val_reg) del_meas_val_reg_inst (clk, rst, gpio_in, del_meas_val_out);
config_reg #(8,2,16,del_meas_thresh_reg) del_meas_thresh_reg_inst (clk, rst, gpio_in, del_meas_thresh_out);

wire [15:0] del_meas_mac_result;
wire [15:0] del_meas_nl_result;
wire del_done; //Done flag for when this measurement finishes

wire halt;
//Config register for halt signal
wire [7:0] halt_reg_out;
assign halt = halt_reg_out[0];
config_reg #(8,1,16,halt_reg) halt_reg_inst (clk, rst, gpio_in, halt_reg_out);

wire [2:0] state_out;

wire err_out;

//ADC drivers for MAC and NL
wire [7:0] adc_run;
wire mac_adc_run = adc_run[0];
wire nl_adc_run = adc_run[1];
config_reg #(8,1,16,adc_run_reg) adc_run_reg_inst (clk, rst, gpio_in, adc_run);
//MAC driver
adc_driver
#(
mac_driver_addr_reg,
mac_driver_data_reg,
mac_driver_shift_amt_reg_base_addr
) mac_driver_inst
(
	clk, rst,
	
	gpio_in,
	
	//Input from ADC
	s0_axis_tdata,
	s0_axis_tvalid,
	s0_axis_tready,
	
	//Output to experiment FSM
	mac_val_in,
	mac_val_valid,
	
	mac_run,//From FSM, tells peak detector to start processing data, need to OR this with del trig
	
	//Output to PS over DMA
	mac_adc_data,
	mac_adc_valid,
	mac_adc_ready,
	
	mac_adc_run//From CPU, tells adc driver when to start recording raw data
	
);
//NL Driver
adc_driver
#(
nl_driver_addr_reg,
nl_driver_data_reg,
nl_driver_shift_amt_reg_base_addr
) nl_driver_inst
(
	clk, rst,
	
	gpio_in,
	
	//Input from ADC
	s1_axis_tdata,
	s1_axis_tvalid,
	s1_axis_tready,
	
	//Output to experiment FSM
	nl_val_in,
	nl_val_valid,
	
	nl_run,//From FSM, tells peak detector to start processing data, need to OR this with del trig
	
	//Output to PS over DMA
	nl_adc_data,
	nl_adc_valid,
	nl_adc_ready,
	
	nl_adc_run//From CPU, tells adc driver when to start recording raw data
	
);


//DAC drivers

wire [255:0] m0_axis_tdata;
dac_driver
#(
a_output_scaler_addr_reg,
a_output_scaler_data_reg,
a_static_output_reg_base_addr,//Static dac word to output
a_dac_mux_sel_reg_base_addr,//Selects between input from output scaler, static word, or delay cal
a_shift_amt_reg_base_addr//Selects how much to shift output by
) a_dac_driver_inst
(
	clk, rst,
	
	gpio_in,
	
	a_out,
	a_valid,
	
	1'b0,//Delay trgger
	
	m0_axis_tdata
	
);

wire [255:0] m1_axis_tdata;
dac_driver
#(
b_output_scaler_addr_reg,
b_output_scaler_data_reg,
b_static_output_reg_base_addr,//Static dac word to output
b_dac_mux_sel_reg_base_addr,//Selects between input from output scaler, static word, or delay cal
b_shift_amt_reg_base_addr//Selects how much to shift output by
) b_dac_driver_inst
(
	clk, rst,
	
	gpio_in,
	
	b_out,
	b_valid,
	
	1'b0,//Delay trgger
	
	m1_axis_tdata
	
);

wire [255:0] m2_axis_tdata;
dac_driver
#(
c_output_scaler_addr_reg,
c_output_scaler_data_reg,
c_static_output_reg_base_addr,//Static dac word to output
c_dac_mux_sel_reg_base_addr,//Selects between input from output scaler, static word, or delay cal
c_shift_amt_reg_base_addr//Selects how much to shift output by
) c_dac_driver_inst
(
	clk, rst,
	
	gpio_in,
	
	c_out,
	c_valid,
	
	1'b0,//Delay trgger
	
	m2_axis_tdata
	
);


//Input fifo selector for ps to pl

wire [15:0] sa_axis_tdata, sb_axis_tdata;
wire sa_axis_tvalid, sa_axis_tvalid, sb_axis_tvalid, sb_axis_tready;

 axis_selector #(16) axis_input_selector
(
	s2_axis_tdata,
	s2_axis_tvalid,
	s2_axis_tready,
	
	sa_axis_tdata,
	sa_axis_tvalid,
	sa_axis_tready,
	
	sb_axis_tdata,
	sb_axis_tvalid,
	sb_axis_tready,
	
	instr_b_sel
	
);

//FIFOs for B and instructions
wire [31:0] b_count, instr_count;
counter_fifo
#(16, instr_fifo_depth) instr_fifo_inst
(
	clk, rst,
	
	sa_axis_tdata,
	sa_axis_tvalid,
	sa_axis_tready,
	
	instr_axis_tdata,
	instr_axis_tvalid,
	instr_axis_tready,
	
	instr_count
);

counter_fifo
#(16, instr_fifo_depth) b_fifo_inst
(
	clk, rst,
	
	sb_axis_tdata,
	sb_axis_tvalid,
	sb_axis_tready,
	
	b_r_tdata,
	b_r_tvalid,
	b_r_tready,
	
	b_count
);


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
	
	halt, 
	state_out,
	err_out
);






endmodule