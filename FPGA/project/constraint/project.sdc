# ##############################################################################

# iCEcube SDC

# Version:            2017.01.27914

# File Generated:     Sep 22 2017 14:09:03

# ##############################################################################

####---- CreateClock list ----4
create_clock  -period 37.00 -name {osc_clk} [get_ports {osc_clk}] 
create_clock  -period 18.50 -name {DCK_N} [get_ports {DCK_N}] 
create_clock  -period 18.50 -name {DCK_P} [get_ports {DCK_P}] 
create_clock  -period 166.67 -name {byte_clk_g} [get_nets {byte_clk_g}] 

