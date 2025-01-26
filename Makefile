target=sim.vcd

#Run compiled verilog code to produce waveform file
$(target): sim.o
	vvp $<
	@echo "Run gtkwave --dark $(target) to view simulated waveform"
	@echo "gtkwave --dark $(target)"
	@echo "------or------"
	@echo "surfer $(target)"
	@echo "surfer configs are in the .surfer/decoders directory"

#Create compiled iverilog code (runnable by vvp)
sim.o: test_axis_uart_tx.sv axis_uart_tx.sv
	iverilog -g2012 -o $@ -DSIM -DSIM_TIME_NS=1000 -DSIM_DUMP=\"$(target)\" $^

.PHONY:
clean:
	rm -f $(target) sim.o
