module ALU(
        //input
        input CLOCK,
        input stallE,
        input ALUflush,
        input RegWriteE,
        input MemtoRegE,
        input MemWriteE,
        //input BranchE,
        input [4:0] ALUControlE,
        input ALUSrcE,
        input RegDstE,
        input [31:0] SrcAE,
        input [31:0] SrcBE,
        input [4:0] RtE,
        input [4:0] RdE,
        input [31:0] SignImmE,
        input [31:0] uSignImmE,
        input [4:0] shmntE,
        input [31:0] PCE,
        input [31:0] jumpaddM,
        input [4:0] NextRs,
        input [4:0] NextRt,
        input [5:0] Nextop,
        input forwardArs,              //the flag for ID-EX data forwarding without stalling
        input forwardArt,
        input [31:0] ALUOutEf,            //the ALU output for data forwarding
        input forwardBrs,              //the flag for ID-EX data forwarding with stalling(lw)
        input forwardBrt,
        input [31:0] MemDataEf,            //the ID-EX memory data forwarding for load instruction
        input forwardCrs,                 //the forwarding signal for MEM-ID data forwarding
        input forwardCrt,
        input [31:0] MforwardE,                 //the forwarding data from memory

        //output
        output reg RWE,
        output reg MRE,
        output reg MWE,
        output reg BranchE,
        //output Zero,
        output reg [31:0] ALUOutE,
        output reg [31:0] WriteDataE,
        output reg [4:0] WriteRegE,
        output reg [31:0] targetaddE,
        output reg hazardArs,             //the flags for ID-EX data forwarding without stalling
        output reg hazardArt,
        output reg hazardBrs,             //the flags for ID-EX data forwarding with stalling(lw instruction)
        output reg hazardBrt,
        output reg stallsigE

    );
    wire [31:0] shE;
    wire [31:0] dataA;
    wire [31:0] dataB;
    wire signed [31:0] sdataB;
    wire [4:0] outReg;      //the chosen target register address
    wire [31:0] udataB;
    wire [31:0] rsdata;
    wire [31:0] rtdata;
    assign rsdata = (forwardCrs == 1'b1) ? MforwardE : ((forwardBrs == 1'b1) ? MemDataEf : ((forwardArs == 1'b1) ? ALUOutEf : SrcAE));
    assign rtdata = (forwardCrt == 1'b1) ? MforwardE : ((forwardBrt == 1'b1) ? MemDataEf : ((forwardArt == 1'b1) ? ALUOutEf : SrcBE));
    assign dataA = rsdata;
    assign dataB = ALUSrcE ? SignImmE : rtdata;
    assign sdataB = dataB;
    assign udataB = ALUSrcE ? uSignImmE : rtdata;
    assign outReg = RegDstE ? RdE : RtE;
    assign shE = {27'b0, shmntE};


    always @(posedge CLOCK) begin
        if (stallE == 1'b1) begin
            RWE <= 1'b0;
            MRE <= 1'b0;
            MWE <= 1'b0;
            ALUOutE <= 32'b0;
            WriteDataE <= 32'b0;
            WriteRegE <= 4'b0;
            BranchE <= 1'b0;
            stallsigE <= 1'b0;
        end
        else begin
        if (ALUControlE == 5'b10010 || ALUflush == 1'b1) begin
            RWE <= 1'b0;
            MRE <= 1'b0;
            MWE <= 1'b0;
            ALUOutE <= 32'b0;
            WriteDataE <= 32'b0;
            WriteRegE <= 4'b0;
            BranchE <= 1'b0;
        end
        else begin
        //ID-EX data hazard without stalling detection
        if (RegWriteE && (outReg == NextRs) && (MemtoRegE != 1'b1) && (outReg != 5'b00000)) begin
            hazardArs <= 1'b1;
        end
        else hazardArs <= 1'b0;
        if (RegWriteE && (outReg == NextRt) && (MemtoRegE != 1'b1) && (outReg != 5'b00000) && (Nextop == 6'b000000 || Nextop == 6'b101011)) begin
            hazardArt <= 1'b1;
        end
        else hazardArt <= 1'b0;

        //Id-EX stalling detection
        if (RegWriteE && (outReg == NextRs) && (MemtoRegE == 1'b1) && (outReg != 5'b00000)) begin
            hazardBrs <= 1'b1;
        end
        else hazardBrs <= 1'b0;
        if (RegWriteE && (outReg == NextRt) && (MemtoRegE == 1'b1) && (outReg != 5'b00000)) begin
            hazardBrt <= 1'b1;
        end
        else hazardBrt <= 1'b0;
        if ((RegWriteE && (outReg == NextRt) && (MemtoRegE == 1'b1) && (outReg != 5'b00000)) || (RegWriteE && (outReg == NextRs) && (MemtoRegE == 1'b1) && (outReg != 5'b00000))) begin
            stallsigE <= 1'b1;
        end
        else stallsigE <= 1'b0;

        //ALU execution
        if (ALUControlE == 5'b10001) begin        //jal write back
            WriteRegE <= 5'b11111;
            WriteDataE <= ((PCE + 1) << 2);
        end
        else begin
            WriteRegE <= outReg;
            WriteDataE <= rtdata;
        end 
        RWE <= RegWriteE;
        MRE <= MemtoRegE;
        MWE <= MemWriteE;

        if (ALUControlE == 5'b00000) begin     //add
            ALUOutE <= dataA + dataB;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00001) begin     //sub
            ALUOutE <= dataA - dataB;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00010) begin     //and
            ALUOutE <= dataA & udataB;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00011) begin     //nor
            ALUOutE <= ~(dataA | udataB);
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00100) begin     //or
            ALUOutE <= dataA | udataB;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00101) begin     //xor
            ALUOutE <= dataA ^ udataB;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00110) begin     //sll
            ALUOutE <= dataB << shE;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b00111) begin     //sllv
            ALUOutE <= dataB << dataA;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01000) begin      //srl
            ALUOutE <= dataB >> shE;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01001) begin      //srlv
            ALUOutE <= dataB >> dataA;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01010) begin      //sra
            ALUOutE <= sdataB >>> shE;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01011) begin      //srav
            ALUOutE <= sdataB >>> dataA;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01100) begin      //slt
            if (dataA < dataB) ALUOutE <= 32'b1;
            else ALUOutE <= 32'b0;
            BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01101) begin      //beq
            if (rsdata == rtdata) begin
                BranchE <= 1'b1;
                targetaddE <= SignImmE + PCE + 32'b1; 
            end
            else BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01110) begin      //bne
            if (rsdata != rtdata) begin
                BranchE <= 1'b1;
                targetaddE <= SignImmE + PCE + 32'b1; 
            end
            else BranchE <= 1'b0;
        end
        else if (ALUControlE == 5'b01111) begin           //j
            BranchE <= 1'b1;
            targetaddE <= jumpaddM;
        end
        else if (ALUControlE == 5'b10000) begin           //jr
            BranchE <= 1'b1;
            targetaddE <= (rsdata >> 2);
        end
        else if (ALUControlE == 5'b10001) begin           //jal
            BranchE <= 1'b1;
            targetaddE <= jumpaddM;
            ALUOutE <= ((PCE + 1) << 2);
        end

        end
        end
    end

endmodule