tb: InstructionRAM.v ReF.v CALU.v MainMemory.v tb.v
	iverilog -o wave InstructionRAM.v ReF.v CALU.v MainMemory.v tb.v
	vvp -n wave -lxt2
.PHONY : clean

clean:
	rm *.o tb