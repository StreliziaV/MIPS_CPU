echo "start compiling"
iverilog -o wave InstructionRAM.v ReF.v CALU.v MainMemory.v tb.v
echo "compile complete"
vvp -n wave -lxt2