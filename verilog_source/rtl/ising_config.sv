


package rfsoc_config;

parameter gpio_w_clk_bit = 24;
parameter gpio_addr_start = 015
parameter gpio_addr_end = 0;
parameter gpio_data_start = 23;
parameter gpio_data_end = 16;

parameter adc_buffer_len = 256;

parameter num_bits = 8; //Bit precision to use for internal logic


//Address table for configuration registers (0 to 65535)
parameter mac_input_scaler_addr_reg = 0;
parameter mac_input_scaler_data_reg = 0;
parameter nl_input_scaler_addr_reg = 256;
parameter nl_input_scaler_data_reg = 256;


endpackage