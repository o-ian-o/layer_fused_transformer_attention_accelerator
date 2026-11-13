# 1. Clock Constraint (100 MHz)
# Pin E3 is the standard clock pin for the xc7a100tcsg324-1 (e.g., Nexys A7 / Arty A7)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

# 2. Reset Constraint
# Maps the reset to a physical button (Replace 'C12' with your board's actual reset button pin)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { reset }];
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { start }];