create_clock -period 3.350 -name clk -waveform {0.000 1.675} [get_ports -filter { NAME =~  "*clk*" && DIRECTION == "IN" }]











