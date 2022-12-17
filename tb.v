`timescale 1ns/1ns

module MIPS_CPU();
    reg clock;
    reg[31:0] PCC = 32'b0;
    wire[31:0] PC;
    wire[31:0] instruction;
    wire[31:0] PCI;

    //Input of Register File
    reg WBenable = 1'b0;
    reg [4:0] WBaddress = 4'b0;
    reg [31:0] WBdata = 32'b0;
    //Output of Register File, Input of ALU operation
    wire [31:0] RsDm;  //the data of Rs  low case "m" means Main part
    wire [31:0] RtDm; 
    wire [4:0] Rsaddm;
    wire [4:0] Rtaddm;  //the address of Rt
    wire [4:0] Rdaddm;
    wire [31:0] SignImmem;
    wire [31:0] uSignImmem;
    wire [4:0] shmntm;
    wire RegDstm;
    wire ALUSrcm;
    wire [4:0] ALUControlm;
    wire RegWritem;
    wire MemtoRegm;
    wire MemWritem;
    wire terminatorm;
    wire [31:0] PCRFm;
    wire [31:0] jumpaddEm;

    //the output of ALU part, the input of Memory part
    wire RegWriteEm;
    wire MemtoRegEm;
    wire MemWriteEm;
    wire BranchEm;
    //output Zero,
    wire [31:0] ALUOutEm;
    wire [31:0] WriteDataEm;
    wire [4:0] WriteRegEm;
    wire [31:0] targetaddEm;

    //the output of Memory part, the input of write back stage
    wire RegWriteWm;
    wire MemtoRegWm;
    wire [31:0] ALUOutWm;
    wire [31:0] ReadDataWm;
    wire [4:0] WriteRegWm;

    //the input and output for data hazard handling
    wire hazardArsm;         //the signals for EX-ID data forwarding(without stalling)
    wire hazardArtm;
    wire hazardBrsm;         //the signals for EX-ID data forwarding(with stalling)
    wire hazardBrtm;
    wire stallsigm;
    wire hazardCrsm;         //the signals for MEM-ID data forwarding
    wire hazardCrtm;
    wire [31:0] Mforwardm;

    InstructionRAM ins(
        .CLOCK (clock), 
        .IRstall (stallsigm), 
        .ENABLE (1'b1), 
        .FETCH_ADDRESS (PC), 
        .IFflush (BranchEm), 
        
        .DATA (instruction), 
        .PCIR (PCI)
    );

    Regs RF( //Input
        .CLOCK (clock),
        .stall (stallsigm),                                  // flush
        .WriteEnbale (RegWriteWm),
        .it (instruction),  //input instruction
        .WB (WriteRegWm),         //the write back address
        .WriteData (MemtoRegWm ? ReadDataWm : ALUOutWm),  //the write back data
        .counter (PCI),
        .RFflush (BranchEm),

        // Outputs
        .RsD (RsDm),  //the data of Rs
        .RtD (RtDm),
        .Rsadd (Rsaddm),
        .Rtadd (Rtaddm),         //the address of Rt
        .Rdadd (Rdaddm),         //the address of Rd, will be choose as the write back address
        .SignImme (SignImmem),
        .uSignImme (uSignImmem),
        .sh (shmntm),           //shift amount
        .RegDstD (RegDstm),            //Destination register choice 0:rt, 1:rd 
        .ALUSrcD (ALUSrcm),            //the second source of ALU, 0:rt, 1:immediate number
        .ALUControlD (ALUControlm),
        //.BranchD (Branchm),            //1:jump or branch occurs, 0: not jump or branch
        .MemWriteD (MemWritem),
        .MemtoRegD (MemtoRegm),
        .RegWriteD (RegWritem),
        .terminator (terminatorm),
        .PCRF (PCRFm),
        .jumpaddE (jumpaddEm)
    );

    ALU ALUm(
        //input
        .CLOCK (clock),
        .stallE (stallsigm),
        .ALUflush (BranchEm),
        .RegWriteE (RegWritem),
        .MemtoRegE (MemtoRegm),
        .MemWriteE (MemWritem),
        //input BranchE,
        .ALUControlE (ALUControlm),
        .ALUSrcE (ALUSrcm),
        .RegDstE (RegDstm),
        .SrcAE (RsDm),
        .SrcBE (RtDm),
        .RtE (Rtaddm),
        .RdE (Rdaddm),
        .SignImmE (SignImmem),
        .uSignImmE (uSignImmem),
        .shmntE (shmntm),
        .PCE (PCRFm),
        .jumpaddM (jumpaddEm),
        .NextRs (instruction[25:21]),
        .NextRt (instruction[20:16]),
        .Nextop (instruction[31:26]),
        .forwardArs (hazardArsm),
        .forwardArt (hazardArtm),
        .ALUOutEf (ALUOutEm),
        .forwardBrs (hazardBrsm),
        .forwardBrt (hazardBrtm),
        .MemDataEf (ReadDataWm),
        .forwardCrs (hazardCrsm),
        .forwardCrt (hazardCrtm),
        .MforwardE (Mforwardm),

        //output
        .RWE (RegWriteEm),
        .MRE (MemtoRegEm),
        .MWE (MemWriteEm),
        .BranchE (BranchEm),
        //output Zero,
        .ALUOutE (ALUOutEm),
        .WriteDataE (WriteDataEm),
        .WriteRegE (WriteRegEm),
        .targetaddE (targetaddEm),
        .hazardArs (hazardArsm),
        .hazardArt (hazardArtm),
        .hazardBrs (hazardBrsm),
        .hazardBrt (hazardBrtm),
        .stallsigE (stallsigm)
    );

    MainMemory MM(
        //input
        .CLOCK (clock),
        //.MMstall
        .FETCH_ADDRESS (ALUOutEm),
        .EDIT_SERIAL ({MemWriteEm, ALUOutEm, WriteDataEm}),
        .RegWriteM (RegWriteEm),
        .MemtoRegM (MemtoRegEm),
        .MemWriteM (MemWriteEm),
        .WriteRegM (WriteRegEm),
        //.stallM (stallsigm),
        .thirdrs (instruction[25:21]),
        .thirdrt (instruction[20:16]),
        .EXrs (Rsaddm),
        .EXrt (Rtaddm),

        //output
        .DATA (ReadDataWm),
        .RWM (RegWriteWm),
        .MRM (MemtoRegWm),
        .ALUOutM (ALUOutWm),
        .WRM (WriteRegWm),
        //.stalloutM (stallsigm),
        .hazardCrs (hazardCrsm),
        .hazardCrt (hazardCrtm),
        .Mforward (Mforwardm)
    );

    initial begin
        clock = 0;
        forever begin
            #1 clock = ~clock;
        end
    end
    
    always @(posedge clock) begin
        if (stallsigm == 1'b1) begin
            PCC <= PC;
        end
        else begin
            if (BranchEm == 1'b1) PCC <= (targetaddEm);
            else PCC <= (PC + 1);
        end
    end

    assign PC = PCC;

    integer i;
    always @(posedge clock) begin
        if (terminatorm == 1'b1) begin
            #7 for (i=0; i < 510; i = i + 10) begin
                $display("%h %h %h %h %h %h %h %h %h %h", MM.DATA_RAM[i], MM.DATA_RAM[i+1], MM.DATA_RAM[i+2], MM.DATA_RAM[i+3], MM.DATA_RAM[i+4], MM.DATA_RAM[i+5], MM.DATA_RAM[i+6], MM.DATA_RAM[i+7], MM.DATA_RAM[i+8], MM.DATA_RAM[i+9]);
            end
            $display("%h %h", MM.DATA_RAM[510], MM.DATA_RAM[511]);
            $finish;
        end
    end

    initial begin            
        $dumpfile("CPU.vcd");        
        $dumpvars(0, MIPS_CPU);    
    end


endmodule