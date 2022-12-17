module Regs  //including the Control Unit
    ( // Inputs
      input  CLOCK // clock
    , input  stall // stalling operation
    , input  WriteEnbale
    , input [31:0] it  //input instruction
    , input [4:0] WB         //the write back address
    , input [31:0] WriteData  //the write back data
    , input [31:0] counter
    , input RFflush

      // Outputs
    , output reg [31:0] RsD  //the data of Rs
    , output reg [31:0] RtD
    , output reg [4:0] Rsadd
    , output reg [4:0] Rtadd  //the address of Rt
    , output reg [4:0] Rdadd
    , output reg [31:0] SignImme       //signed immediate
    , output reg [31:0] uSignImme       //unsigned immedite number
    , output reg [4:0] sh           //shift amount
    , output reg RegDstD            //Destination register choice 0:rt, 1:rd 
    , output reg ALUSrcD            //the second source of ALU, 0:rt, 1:immediate number
    , output reg [4:0] ALUControlD //output the ALU control signal
    //, output reg BranchD            //1:jump or branch occurs, 0: not jump or branch
    , output reg MemWriteD
    , output reg MemtoRegD
    , output reg RegWriteD
    , output reg terminator
    , output reg [31:0] PCRF
    , output reg [31:0] jumpaddE
    );

    reg[31:0] RegFile[0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            RegFile[i] = 32'b0;
        end
    end
    wire[31:0] instruct;
    wire[5:0] opcode;
    wire[4:0] Rs;
    wire[4:0] Rt;
    wire[4:0] Rd;
    wire[4:0] shmnt;
    wire[5:0] funcode;
    wire[15:0] imme;
    wire[4:0] WriteAdd;
    wire[25:0] address;

    assign instruct = it;
    assign opcode = instruct[31:26];
    assign Rs = instruct[25:21];
    assign Rt = instruct[20:16];
    assign Rd = instruct[15:11];
    assign shmnt = instruct[10:6];
    assign funcode = instruct[5:0];
    assign imme = instruct[15:0];
    assign WriteAdd = WB[4:0];
    assign address = instruct[25:0];

    always @(posedge CLOCK) begin
        if (stall == 1'b1) begin
        //register file write
            if ((WriteEnbale == 1'b1) && (WriteAdd != 5'b00000)) begin
                RegFile[WriteAdd] <= WriteData;
            end
        end
        else begin
        //register file write
        if ((WriteEnbale == 1'b1) && (WriteAdd != 5'b00000)) begin
            RegFile[WriteAdd] <= WriteData;
        end
        //instruction decoding
        if (RFflush == 1'b1) begin
            ALUControlD <= 5'b10010;
        end
        else if (instruct == 32'hffffffff) begin 
            terminator <= 1'b1;
            MemWriteD <= 1'b0;
            RegWriteD <= 1'b0;
        end
        else begin
        SignImme <= instruct[15] ? {{(16) {1'b1}}, imme} : {{(16) {1'b0}}, imme};
        uSignImme <= {{(16) {1'b0}}, imme};
        PCRF <= counter;
        jumpaddE <= {{(6) {1'b0}}, address};

        //WB-ID data hazard detection
        if (WriteEnbale && (WB == Rs) && (WriteAdd != 5'b00000)) begin
            RsD <= WriteData;
        end
        else RsD <= RegFile[Rs];
        if (WriteEnbale && (WB == Rt) && (WriteAdd != 5'b00000)) begin
            RtD <= WriteData;
        end
        else RtD <= RegFile[Rt];
        Rsadd <= Rs;
        Rtadd <= Rt;
        Rdadd <= Rd;
        sh <= shmnt;

        if (opcode == 6'b000000) begin     //R type: choose rd as the destination: the write back address
            RegDstD <= 1'b1;
            ALUSrcD <= 1'b0;
            if (funcode == 6'b100000 || funcode == 6'b100001) begin     //add addu
                ALUControlD <= 5'b00000;
            end
            else if (funcode == 6'b100010 || funcode == 6'b100011) begin    //sub subu
                ALUControlD <= 5'b00001;
            end
            else if (funcode == 6'b100100) begin            //and
                ALUControlD <= 5'b00010;
            end
            else if (funcode == 6'b100111) begin            //nor
                ALUControlD <= 5'b00011;
            end
            else if (funcode == 6'b100101) begin            //or
                ALUControlD <= 5'b00100;
            end
            else if (funcode == 6'b100110) begin            //xor
                ALUControlD <= 5'b00101;
            end
            else if (funcode == 6'b000000) begin            //sll
                ALUControlD <= 5'b00110;
            end
            else if (funcode == 6'b000100) begin            //sllv
                ALUControlD <= 5'b00111;
            end
            else if (funcode == 6'b000010) begin            //srl
                ALUControlD <= 5'b01000;
            end
            else if (funcode == 6'b000110) begin            //srlv
                ALUControlD <= 5'b01001;
            end
            else if (funcode == 6'b000011) begin            //sra
                ALUControlD <= 5'b01010;
            end
            else if (funcode == 6'b000111) begin            //srav
                ALUControlD <= 5'b01011;
            end
            else if (funcode == 6'b101010) begin            //slt
                ALUControlD <= 5'b01100;
            end
            else if (funcode == 6'b001000) begin            //jr
                ALUControlD <= 5'b10000;
            end
            else ALUControlD <= 5'b10010;
        end
        else if (opcode != 6'b000000) begin                        //other type choose rt
            RegDstD <= 1'b0;
            ALUSrcD <= 1'b1;              //ALU choose immediate number
            if ((opcode == 6'b100011) || (opcode == 6'b101011) || (opcode == 6'b001000) || (opcode == 6'b001001)) begin        //lw sw addi addiu
                ALUControlD <= 5'b00000;
            end
            else if (opcode == 6'b001100) begin      //andi
                ALUControlD <= 5'b00010;
            end
            else if (opcode == 6'b001101) begin      //ori
                ALUControlD <= 5'b00100;
            end
            else if (opcode == 6'b001110) begin      //xori
                ALUControlD <= 5'b00101;
            end
            else if (opcode == 6'b000100) begin      //beq
                ALUControlD <= 5'b01101;
            end
            else if (opcode == 6'b000101) begin      //bne
                ALUControlD <= 5'b01110; 
            end
            else if (opcode == 6'b000010) begin      //j
                ALUControlD <= 5'b01111;
            end
            else if (opcode == 6'b000011) begin      //jal
                ALUControlD <= 5'b10001;
            end
            else ALUControlD <= 5'b10010;
        end

        if (opcode == 6'b101011) MemWriteD <= 1'b1;  //sw
        else MemWriteD <= 1'b0;

        if (opcode == 6'b100011 || opcode == 6'b101011) MemtoRegD <= 1'b1;
        else MemtoRegD <= 1'b0;
        //sw or jr or j or beq or bne or flush: opcode = 111111 means flush happens
        if ((opcode == 6'b101011) || (opcode == 6'b000000 && funcode == 6'b001000) || (opcode == 6'b000010) || (opcode == 6'b000101) || (opcode == 6'b000100) || (opcode == 6'b111111)) RegWriteD <= 1'b0; 
        else RegWriteD <= 1'b1;

        end
        end
    end

endmodule