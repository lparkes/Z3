package require ::quartus::project

set_location_assignment PIN_AA3 -to address[0]
set_location_assignment PIN_AB3 -to address[1]
set_location_assignment PIN_AA4 -to address[2]
set_location_assignment PIN_AB4 -to address[3]
set_location_assignment PIN_AA5 -to address[4]
set_location_assignment PIN_AB10 -to address[5]
set_location_assignment PIN_AA11 -to address[6]
set_location_assignment PIN_AB11 -to address[7]
set_location_assignment PIN_V11 -to address[8]
set_location_assignment PIN_W11 -to address[9]
set_location_assignment PIN_R11 -to address[10]
set_location_assignment PIN_T11 -to address[11]
set_location_assignment PIN_Y10 -to address[12]
set_location_assignment PIN_U10 -to address[13]
set_location_assignment PIN_R10 -to address[14]
set_location_assignment PIN_T7 -to address[15]
set_location_assignment PIN_Y6 -to address[16]
set_location_assignment PIN_Y5 -to address[17]

set_location_assignment PIN_AB5 -to SRAM_CE_N
set_location_assignment PIN_AA6 -to data[0]
set_location_assignment PIN_AB6 -to data[1]
set_location_assignment PIN_AA7 -to data[2]
set_location_assignment PIN_AB7 -to data[3]
set_location_assignment PIN_AA8 -to data[4]
set_location_assignment PIN_AB8 -to data[5]
set_location_assignment PIN_AA9 -to data[6]
set_location_assignment PIN_AB9 -to data[7]

set_location_assignment PIN_Y7 -to SRAM_LB_N
set_location_assignment PIN_T8 -to SRAM_OE_N
set_location_assignment PIN_W7 -to SRAM_UB_N
set_location_assignment PIN_AA10 -to SRAM_WE_N

set_instance_assignment -name OUTPUT_PIN_LOAD 15 -to led0
set_instance_assignment -name OUTPUT_PIN_LOAD 15 -to led1
set_instance_assignment -name OUTPUT_PIN_LOAD 15 -to led2
set_location_assignment PIN_R20 -to led0
set_location_assignment PIN_R19 -to led1
set_location_assignment PIN_U19 -to led2
