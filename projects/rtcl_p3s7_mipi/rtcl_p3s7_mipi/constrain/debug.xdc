create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk72]]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
set_property port_width 8 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {u_pmod_control/sync_pmod[0]} {u_pmod_control/sync_pmod[1]} {u_pmod_control/sync_pmod[2]} {u_pmod_control/sync_pmod[3]} {u_pmod_control/sync_pmod[4]} {u_pmod_control/sync_pmod[5]} {u_pmod_control/sync_pmod[6]} {u_pmod_control/sync_pmod[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {u_pmod_control/sync_monitor[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {u_pmod_control/pmod_t[0]} {u_pmod_control/pmod_t[1]} {u_pmod_control/pmod_t[2]} {u_pmod_control/pmod_t[3]} {u_pmod_control/pmod_t[4]} {u_pmod_control/pmod_t[5]} {u_pmod_control/pmod_t[6]} {u_pmod_control/pmod_t[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {u_pmod_control/ff_trigger[0]} {u_pmod_control/ff_trigger[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {u_pmod_control/pmod_o[0]} {u_pmod_control/pmod_o[1]} {u_pmod_control/pmod_o[2]} {u_pmod_control/pmod_o[3]} {u_pmod_control/pmod_o[4]} {u_pmod_control/pmod_o[5]} {u_pmod_control/pmod_o[6]} {u_pmod_control/pmod_o[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe5]
set_property port_width 8 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {u_pmod_control/pmod_i[0]} {u_pmod_control/pmod_i[1]} {u_pmod_control/pmod_i[2]} {u_pmod_control/pmod_i[3]} {u_pmod_control/pmod_i[4]} {u_pmod_control/pmod_i[5]} {u_pmod_control/pmod_i[6]} {u_pmod_control/pmod_i[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe6]
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {u_pmod_control/light_pattern[0]} {u_pmod_control/light_pattern[1]} {u_pmod_control/light_pattern[2]} {u_pmod_control/light_pattern[3]} {u_pmod_control/light_pattern[4]} {u_pmod_control/light_pattern[5]} {u_pmod_control/light_pattern[6]} {u_pmod_control/light_pattern[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe7]
set_property port_width 8 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {u_pmod_control/hdr_pmod[0]} {u_pmod_control/hdr_pmod[1]} {u_pmod_control/hdr_pmod[2]} {u_pmod_control/hdr_pmod[3]} {u_pmod_control/hdr_pmod[4]} {u_pmod_control/hdr_pmod[5]} {u_pmod_control/hdr_pmod[6]} {u_pmod_control/hdr_pmod[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe8]
set_property port_width 4 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {u_pmod_control/pattern_idx[0]} {u_pmod_control/pattern_idx[1]} {u_pmod_control/pattern_idx[2]} {u_pmod_control/pattern_idx[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list u_pmod_control/sync_trigger]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk72]
