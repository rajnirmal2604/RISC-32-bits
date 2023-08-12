module RISC_123(clk1,clk2);
 
 input clk1,clk2;
 
 
   reg [31:0] PC, IF_ID_IR, IF_ID_NPC;		
   reg [31:0] ID_EX_IR,  ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
	reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;
	reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
	reg 	   EX_MEM_cond;
	reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;
	reg [31:0] Reg [0:31];		//Register Bank
	reg [31:0] Mem [0:1023];	//1024 x 32 memory

	reg HALTED; 			//whenever hlt occure halted = 1
	reg TAKEN_BRANCH;		//Required to disable instructions after branch
	
	parameter 	
			ADD		= 6'b000000,
			SUB		= 6'b000001,
			AND		= 6'b000010,
			OR 		= 6'b000011,
			MUL		= 6'b000101,
			SLT		= 6'b000100,
			HTL		= 6'b111111,

			LW 		= 6'b001000,
			SW 		= 6'b001001,
			ADDI	= 6'b001010,
			SUBI	= 6'b001011,
			SLTI	= 6'b001100,
			BNEQZ	= 6'b001101,
			BEQZ	= 6'b001110,

			RR_ALU	= 3'b000,  //REG REG OPERATION
			RM_ALU	= 3'b001,  // REG MEM OPERATION
			LOAD	= 3'b010,
			STORE	= 3'b011,
			BRANCH	= 3'b100,
			HALT	= 3'b101;
			
		

    		
			
		always @(posedge clk1)  //INSTRUCTION FETCH (IF) CYCLE
		if (HALTED==0)
		begin
			if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond==1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond ==0)))	//cond = (A==0)
			begin
				IF_ID_IR	 	<=  Mem[EX_MEM_ALUOut];
				TAKEN_BRANCH  <= 1'b1;
			
				IF_ID_NPC	 	<=  EX_MEM_ALUOut +1;
				PC		 		<=  EX_MEM_ALUOut +1;
			end
			else begin
				IF_ID_IR	 <=  Mem[PC];
				IF_ID_NPC	 <=  PC +1;
				PC		 	 <=  PC +1;
				TAKEN_BRANCH  <= 1'b0;
		       	end	       
		end

		
	always @ (posedge clk2)     //INSTRUCTION DECODE(ID) CYCLE
		if (HALTED==0)
	    begin
			if (IF_ID_IR[25:21] == 5'b00000) 	
					ID_EX_A <= 0;
			else 
					ID_EX_A	<=  Reg[IF_ID_IR[25:21]];	//"rs"

			if (IF_ID_IR[20:16] == 5'b00000)
					ID_EX_B <= 0;
			else 	
					ID_EX_B	<=  Reg[IF_ID_IR[20:16]];	//"rt"

			ID_EX_NPC	<=  IF_ID_NPC;
			ID_EX_IR	<=  IF_ID_IR;
			ID_EX_Imm	<=  {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};	//16 bit Immediate data 


			case (IF_ID_IR[31:26])
					ADD, SUB, AND, OR, SLT, MUL	: ID_EX_type <=  RR_ALU;
					ADDI, SUBI, SLTI	   	   	: ID_EX_type <=  RM_ALU;
					LW			    			: ID_EX_type <=  LOAD;
					SW			   				: ID_EX_type <=  STORE;
					BNEQZ, BEQZ					: ID_EX_type <=  BRANCH;
					HTL			    			: ID_EX_type <=  HALT;
					default						: ID_EX_type <=  HALT;
			endcase
		end


		

	always @ (posedge clk1)     //EXECUTION (EX) CYCLE
		if (HALTED==0)
		begin
			EX_MEM_type		<=  ID_EX_type;
			EX_MEM_IR		<=  ID_EX_IR;
		
			case (ID_EX_type)
				RR_ALU:	begin
					case (ID_EX_IR[31:26])	//opcode
							ADD: EX_MEM_ALUOut 		<=  ID_EX_A + ID_EX_B;
							SUB: EX_MEM_ALUOut 		<=  ID_EX_A - ID_EX_B;
							AND: EX_MEM_ALUOut 		<=  ID_EX_A & ID_EX_B;
							OR:  EX_MEM_ALUOut 		<=  ID_EX_A | ID_EX_B;
							SLT: EX_MEM_ALUOut 		<=  ID_EX_A < ID_EX_B;
							MUL: EX_MEM_ALUOut 		<=  ID_EX_A * ID_EX_B;
							default: EX_MEM_ALUOut 	<=  32'hxxxxxxxx;
					endcase
					end

				RM_ALU: begin
					case (ID_EX_IR[31:26])	//opcode
							ADDI: EX_MEM_ALUOut 	<=  ID_EX_A + ID_EX_Imm;
							SUBI: EX_MEM_ALUOut 	<=  ID_EX_A - ID_EX_Imm;
							SLTI: EX_MEM_ALUOut 	<=  ID_EX_A < ID_EX_Imm;
					        default: EX_MEM_ALUOut 	<=  32'hxxxxxxxx;
				    endcase
			       	end 


				LOAD, STORE: begin
						EX_MEM_ALUOut	<=  ID_EX_A + ID_EX_Imm;
						EX_MEM_B		<=  ID_EX_B;
					end

				BRANCH:	begin
					EX_MEM_ALUOut	<=  ID_EX_NPC + ID_EX_Imm;
					EX_MEM_cond		<=  (ID_EX_A == 0);
				end
			endcase
		end


	
	always @ (posedge clk2)   //MEMORY (MEM) CYCLE
		if (HALTED==0)
		begin
			MEM_WB_type	<=  EX_MEM_type;
			MEM_WB_IR	<=  EX_MEM_IR;
			
			case (EX_MEM_type)

				RR_ALU, RM_ALU:	MEM_WB_ALUOut	<=  EX_MEM_ALUOut;

				LOAD:			MEM_WB_LMD		<=  Mem[EX_MEM_ALUOut];

				STORE:	if (TAKEN_BRANCH==0)	//disable write
							Mem[EX_MEM_ALUOut]	<=  EX_MEM_B;
			endcase
		end


		

	always @ (posedge clk1)  //WRITE BACK (WB) CYCLE 
	begin
		if (TAKEN_BRANCH==0)
		begin
			case(MEM_WB_type)
				RR_ALU: Reg[MEM_WB_IR[15:11]]	<=  MEM_WB_ALUOut;	// "rd"
				RM_ALU: Reg[MEM_WB_IR[20:16]]   <=  MEM_WB_ALUOut;    // "rt"                             
				LOAD:	Reg[MEM_WB_IR[20:16]]   <=  MEM_WB_LMD;    // "rd"
				HALT:	HALTED					<=  1'b1;
			endcase
		end
	end

endmodule


module testbench;

    reg clk1, clk2;
    integer k;
    RISC_123 mips(clk1,clk2);
    
    initial begin
        clk1=0; clk2=0;
        repeat (50)
            begin
                #5 clk1=1; #5 clk1=0;
                #5 clk2=1; #5 clk2=0;
            end
    end
  
  
task task1(); 
    begin
     for (k=0; k<31; k=k+1)
	  begin
            mips.Reg[k]=k;          //initializing Regesters
      end
        
        
        mips.Mem[0]  = 32'h2801000A;     //  ADDI    R1, R0, 10   32'h2801000A
        mips.Mem[1]  = 32'h28020014;     //  ADDI    R2, R0, 20 
        mips.Mem[2]  = 32'h2803001E;     //  ADDI    R3, R0, 30 
        mips.Mem[3]  = 32'h0CE77800;     //  OR      R7, R7, R7 --- Dummy 
        mips.Mem[4]  = 32'h0CE77800;     //  OR      R7, R7, R7 --- Dummy 
        mips.Mem[5]  = 32'h00222000;     //  ADD     R4, R1, R2 
        mips.Mem[6]  = 32'h0CE77800;     //  OR      R7, R7, R7 --- Dummy 
        mips.Mem[7]  = 32'h0832800;    //  ADD     R5, R4, R3
        mips.Mem[8]  = 32'hFC000000;     //  HLT

        mips.PC      = 0;
        mips.HALTED  = 0;
        mips.TAKEN_BRANCH = 0;

      
     
    end
  endtask
  
  
  task task2();
    begin
      for (k=0; k<31; k=k+1) begin
            mips.Reg[k]=k;          //initializing Regesters  
       end
       
        mips.Mem[0]  = 32'h28010078;     //  ADDI    R1, R0, 120
        mips.Mem[1]  = 32'h0c631800;     //  OR      R3, R3, R3 --- Dummy 00001100011000110001100000000000
        mips.Mem[2]  = 32'h20220000;     //  LW      R2, 0(R1)        
        mips.Mem[3]  = 32'h0c631800;     //  OR      R3, R3, R3 --- Dummy 
        mips.Mem[4]  = 32'h2842002d;     //  ADDI    R2, R2, 45
        mips.Mem[5]  = 32'h0c631800;     //  OR      R3, R3, R3 --- Dummy 
        mips.Mem[6]  = 32'h24220001;     //  SW      R2, 1(R1)  
        mips.Mem[7]  = 32'hfc000000;     //  HLT

        mips.Mem[120]= 85;
        mips.PC      = 0;
        mips.HALTED  = 0;
        mips.TAKEN_BRANCH = 0;

       
      
      
    end
  endtask
  
  
  task task3();
    begin
      
     for (k=0; k<31; k=k+1) begin
            mips.Reg[k]=k;          //initializing Regesters
        end
       
      mips.Mem[0]  = 32'h280A00C8;     //  ADDI    R10, R0, 200
      mips.Mem[1]  = 32'h28020001;     //  ADDI    R2, R0, 1 0010 1000 0000 0010 0000 0000 0000 0001
      mips.Mem[2]  = 32'h0E94A000;     //  OR      R20, R20, R20 --- Dummy
      mips.Mem[3]  = 32'h21430000;     //  LW      R3, 0(R10)
      mips.Mem[4]  = 32'h0E94A000;     //  OR      R20, R20, R20 --- Dummy
      mips.Mem[5]  = 32'h14431000;     //  LOOP : MUL    R2, R2, R3 
      mips.Mem[6]  = 32'h2C630001;     //  SUBI    R3, R3, 1  
      mips.Mem[7]  = 32'h0E94A000;     //  OR      R20, R20, R20 --- Dummy
      mips.Mem[8]  = 32'h3460FFFC;     //  BNEQZ   R3,LOOP
      mips.Mem[9]  = 32'h2542FFFE;     //  SW      R2,-2(R10)  
      mips.Mem[10] = 32'hFC000000;    //  HLT

      mips.Mem[200]= 7;
        mips.PC      = 0;
        mips.HALTED  = 0;
        mips.TAKEN_BRANCH = 0;
      
     
      
    end
  endtask
initial 
      begin
        task1;
       
       //task2;
        
        //task3;
      end  
  endmodule
