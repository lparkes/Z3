module boss(clk, reset, data, waddress, we, led0, led1, led2, txd, romData, romHighAddr, romEnable);

input clk;
input reset;

inout [7:0] data;

output [16:0] waddress;
output we;
output led0;
output led1;
output led2;
output txd;

input [7:0] romData;
output [21:17] romHighAddr;
output romEnable;

reg [16:0] address;
reg [7:0] dataOut;
reg writeEnable;
reg [21:17] romHighAddr;
reg romEnable;

wire [16:0] waddress;
wire we;
wire led0;
wire led1;
wire led2;
wire txd;


//`define HARDWARE_PRINT
//`define REAL_HARDWARE

`define CALLBACK_BASE		'h1E58B
`define INIT_CALLBACK		'h0
`define PRINT_CALLBACK		'h1
//`define PRINTCHAR_CALLBACK	'h2
`define PRINTNUM_CALLBACK	'h3
`define READ_CALLBACK		'h4
`define STATUS_CALLBACK		'h5
`define QUIT_CALLBACK		'h6
`define EXCEPTION_CALLBACK	'h7

`define OPER_LARGE 2'b00
`define OPER_SMALL 2'b01
`define OPER_VARI  2'b10
`define OPER_OMIT  2'b11

`define STATE_RESET 		0
`define STATE_FETCH_OP		1
`define STATE_READ_TYPES	2
`define STATE_READ_OPERS	3
`define STATE_READ_INDIRECT	4
`define STATE_READ_STORE	5
`define STATE_READ_BRANCH	6
`define STATE_DO_OP			7
`define STATE_READ_FUNCTION	8
`define STATE_CALL_FUNCTION	9
`define STATE_RET_FUNCTION	10
`define STATE_STORE_REGISTER 11
`define STATE_PRINT			12
`define STATE_DIVIDE		13
`define STATE_HALT			14
`define STATE_PRINT_CHAR	15

`define OP_0	2'b00
`define OP_1	2'b01
`define OP_2	2'b10
`define OP_VAR	2'b11

`define OP0_RTRUE	'h0
`define OP0_RFALSE	'h1
`define OP0_PRINT	'h2
`define OP0_PRINTRET 'h3
`define OP0_NOP		'h4
`define OP0_SAVE	'h5
`define OP0_RESTORE	'h6
`define OP0_RESTART	'h7
`define OP0_RETPOP	'h8
`define OP0_POP		'h9
`define OP0_QUIT	'hA
`define OP0_NEWLINE	'hB
`define OP0_SHOWSTATUS	'hC
`define OP0_VERIFY	'hD

`define OP1_JZ		'h0
`define OP1_GETSIBLING 'h1
`define OP1_GETCHILD 'h2
`define OP1_GETPARENT 'h3
`define OP1_GETPROPLEN 'h4
`define OP1_INC		'h5
`define OP1_DEC		'h6
`define OP1_PRINTADDR 'h7
`define OP1_REMOVEOBJ 'h9
`define OP1_PRINTOBJ 'hA
`define OP1_RET		'hB
`define OP1_JUMP	'hC
`define OP1_PRINTPADDR 'hD
`define OP1_LOAD 'hE
`define OP1_NOT 'hF

`define OP2_JE		'h1
`define OP2_JL		'h2
`define OP2_JG		'h3
`define OP2_DEC_CHK	'h4
`define OP2_INC_CHK	'h5
`define OP2_JIN		'h6
`define OP2_TEST	'h7
`define OP2_OR		'h8
`define OP2_AND		'h9
`define OP2_TESTATTR 'hA
`define OP2_SETATTR 'hB
`define OP2_CLEARATTR 'hC
`define OP2_STORE	'hD
`define OP2_INSERTOBJ 'hE
`define OP2_LOADW	'hF
`define OP2_LOADB	'h10
`define OP2_GETPROP	'h11
`define OP2_GETPROPADDR	'h12
`define OP2_GETNEXTPROP	'h13
`define OP2_ADD		'h14
`define OP2_SUB		'h15
`define OP2_MUL		'h16
`define OP2_DIV		'h17
`define OP2_MOD		'h18

`define OPVAR_CALL   'h0
`define OPVAR_STOREW 'h1
`define OPVAR_STOREB 'h2
`define OPVAR_PUTPROP 'h3
`define OPVAR_SREAD  'h4
`define OPVAR_PRINTCHAR 'h5
`define OPVAR_PRINTNUM 'h6
`define OPVAR_RANDOM 'h7
`define OPVAR_PUSH 'h8
`define OPVAR_PULL 'h9

`define PRINTEFFECT_FETCH		0
`define PRINTEFFECT_FETCHAFTER	1
`define PRINTEFFECT_RET1		2
`define PRINTEFFECT_ABBREVRET	3

`define PROG0_HIGH_ADDR 	21'h8_0000 >> 17

`define ZHEAD_FILE_LEN_MSB	17'h001a
`define ZHEAD_FILE_LEN_LSB	17'h001b

reg [3:0] state;
reg [3:0] phase;

reg [16:0] pc;
reg [16:0] curPC;
reg [15:0] globalsAddress;
reg [15:0] objectTable;

reg readHigh;

reg [4:0] op;
reg [1:0] operNum;
reg [1:0] operTypes [4:0];
reg [15:0] operand [3:0];
reg [2:0] operandIdx;
reg [13:0] branch;
reg [7:0] store;
reg negate;

reg delayedBranch;
reg divideAddOne;

reg [15:0] returnValue;

reg [6:0] opsToRead;
reg [6:0] currentLocal; 
reg [16:0] csStack;
reg [15:0] stackAddress;

reg [16:0] temp;
reg [15:0] random;

reg [1:0] alphabet;
reg [1:0] long;

reg [7:0] cachedReg;
reg [15:0] cachedValue;

// xp<=adcConfig[0]?0:'bZ;
// yp<=adcConfig[1]?1:'bZ;
// xm<=adcConfig[2]?1:'bZ;
// ym<=adcConfig[3]?0:'bZ;
// XP dataOut[6]
// XM lcsRS
// YP dataOut[7]
// YM lcdWR



txuartlite #(.CLOCKS_PER_BAUD(24'd10000000/19200)) uart
  (
   .i_clk(clk),
   .i_wr(uart_stb),
   .i_data(uart_out),
   .o_uart_tx(txd),
   .o_busy(uart_busy)
   );

reg [7:0]  uart_out;
reg 	   uart_stb;
wire 	   uart_busy;


initial
begin
	state=`STATE_RESET;
	writeEnable=0;
	phase=0;
	readHigh=0;
	cachedReg=0;
	cachedValue=0;
end

assign waddress[16:2] = address[16:2];
assign waddress[0] = address[0];
assign waddress[1] = address[1];
assign data[5:0] = writeEnable?dataOut[5:0]:6'bZ;
assign data[6] = writeEnable?dataOut[6]:'bZ;
assign data[7] = writeEnable?dataOut[7]:'bZ;
assign we = !writeEnable;
assign led0 = reset;
assign led1 = reset;
assign led2 = !address[14];

task StoreB;
	begin
		if (phase==0) begin
			cachedReg<=15; address<=operand[0]+operand[1]; writeEnable<=1; dataOut<=operand[2][7:0]; phase<=phase+1;
		end else begin
			address<=pc; writeEnable<=0; state<=`STATE_FETCH_OP;
		end
	end
endtask

task StoreW;
	begin
		case (phase)
			0: begin cachedReg<=15; address<=operand[0]+operand[1]*2; writeEnable<=1; dataOut<=operand[2][15:8]; phase<=phase+1; end
			1: begin address<=address+1; dataOut<=operand[2][7:0]; phase<=phase+1; end
			default: begin address<=pc; writeEnable<=0; state<=`STATE_FETCH_OP; end
		endcase
	end
endtask

task StoreRegisterAndBranch;
	input [7:0] regNum;
	input [15:0] value;
	input doBranch;
	begin
		state<=`STATE_STORE_REGISTER;
		store<=regNum;
		returnValue<=value;
		delayedBranch<=doBranch;
		phase<=0;
	end
endtask

task StoreResultAndBranch;
	input [15:0] result;
	input doBranch;
	begin
		if (store>=16) begin
			address<=globalsAddress+2*(store-16);
		end else if (store==0) begin
			address<=2*stackAddress;
			stackAddress<=stackAddress+1;
		end else begin
			address<=csStack+8+2*(store-1);
		end
		dataOut<=result[15:8];
		writeEnable<=1;
		state<=`STATE_STORE_REGISTER;
		returnValue[7:0]<=result[7:0];
		delayedBranch<=doBranch;
		phase<=1;
	end
endtask

task StoreResult;
	input [15:0] result;
	begin
		StoreResultAndBranch(result, negate); // negate means won't branch
	end
endtask

task StoreResultSlow;
	input [15:0] result;
	begin
		StoreRegisterAndBranch(store, result, negate); // negate means won't branch
	end
endtask

task ReturnFunction;
	input [15:0] value;
	begin
		returnValue<=value;
		phase<=0;
		state<=`STATE_RET_FUNCTION;
	end
endtask

task CallFunction;
	input doubleReturn;
	input noStoreOnReturn;
	begin
		negate<=doubleReturn;
		delayedBranch<=noStoreOnReturn;
		phase<=0;
		state<=`STATE_CALL_FUNCTION;
	end
endtask

task DoBranch;
	input result;
	begin
		if ((!result)==negate) begin
			if (branch==0) begin
				ReturnFunction(0);
			end else if (branch==1) begin
				ReturnFunction(1);
			end else begin
				pc<=$signed(pc)+$signed(branch)-2;
				address<=$signed(pc)+$signed(branch)-2;
				state<=`STATE_FETCH_OP;
			end
		end else begin
			address<=pc;
			state<=`STATE_FETCH_OP;
		end
	end
endtask

task LoadAndStore;
	input [16:0] loadAddress;
	input		 word;
	begin
		if (phase==0) begin
			store<=data;
			address<=loadAddress;
			temp[7:0]<=0;
			phase<=word?phase+1:2;
		end else if (phase==1) begin
			temp[7:0]<=data;
			address<=address+1;
			phase<=phase+1;
		end else begin
			StoreResultSlow((temp[7:0]<<8)|data);
		end
	end
endtask

function [16:0] GetObjectAddr;
	input [7:0] object;
	begin
		GetObjectAddr=objectTable+2*31+9*(object-1);
	end
endfunction

task TestAttr;
	begin
		if (phase==0) begin
			address<=GetObjectAddr(operand[0])+(operand[1]/8); phase<=phase+1;
		end else begin
			DoBranch(data[7-(operand[1]&7)]);
		end
	end
endtask

task SetAttr;
	begin
		case (phase)
			0: begin address<=GetObjectAddr(operand[0])+(operand[1]/8); phase<=phase+1; end
			1: begin dataOut<=data|(1<<(7-(operand[1]&7))); writeEnable<=1; phase<=phase+1; end
			default: begin writeEnable<=0; address<=pc; state<=`STATE_FETCH_OP; end
		endcase
	end
endtask

task ClearAttr;
	begin
		case (phase)
			0: begin address<=GetObjectAddr(operand[0])+(operand[1]/8); phase<=phase+1; end
			1: begin dataOut<=data&(~(1<<(7-(operand[1]&7)))); writeEnable<=1; phase<=phase+1; end
			default: begin writeEnable<=0; address<=pc; state<=`STATE_FETCH_OP; end
		endcase
	end
endtask

task JumpIfParent;
	begin
		if (phase==0) begin
			address<=GetObjectAddr(operand[0])+4; phase<=phase+1;
		end else begin
			DoBranch(operand[1]==data);
		end
	end
endtask

task GetRelative;
	input [1:0] offset;
	input branch;
	begin
		if (phase==0) begin
			address<=GetObjectAddr(operand[0])+4+offset; phase<=phase+1;
		end else begin
			StoreResultAndBranch(data, branch?data!=0:negate);
		end
	end
endtask

task FindProp;
	begin
		case (phase[2:0])
			0: begin store<=data; address<=GetObjectAddr(operand[0])+7; phase<=phase+1; end
			1: begin temp[16]<=0; temp[15:8]<=data; temp[7:0]<=0; address<=address+1; phase<=phase+1; end
			2: begin address<=temp|data; phase<=phase+1; end
			3: begin address<=address+2*data+1; phase<=phase+1; end
			4: begin
				if (data==0) begin	// end of search (get default)
					address<=objectTable+2*(operand[1]-1);
					phase<=phase+1;
				end else if (data[4:0]==operand[1]) begin // found property
					address<=address+1;
					if (data[7:5]==0) // only 1 byte
						phase<=6;
					else
						phase<=5;
				end else begin // skip over data
					address<=address+data[7:5]+2;
				end
		   	end
			5: begin temp[7:0]<=data; address<=address+1; phase<=phase+1; end
			default: begin StoreResultSlow((temp[7:0]<<8)|data); end
		endcase
	end
endtask

task SetProp;
	begin
		case (phase[2:0])
			0: begin address<=GetObjectAddr(operand[0])+7; phase<=phase+1; end
			1: begin temp[16]<=0; temp[15:8]<=data; temp[7:0]<=0; address<=address+1; phase<=phase+1; end
			2: begin address<=temp|data; phase<=phase+1; end
			3: begin address<=address+2*data+1; phase<=phase+1; end
			4: begin
`ifndef REAL_HARDWARE
				if (data==0) begin // end of search
					state<=`STATE_HALT;
				end else
`endif
				if (data[4:0]==operand[1]) begin // found property
					if (data[7:5]==0) begin // only 1 byte
						dataOut<=operand[2][7:0];
						phase<=6;
						address<=address+1;
						writeEnable<=1;
					end else begin
						dataOut<=operand[2][15:8];
						phase<=5;
						address<=address+1;
						writeEnable<=1;
					end
				end else begin // skip over data
					address<=address+data[7:5]+2;
				end
			end
			5: begin dataOut<=operand[2][7:0]; address<=address+1; phase<=phase+1; end
			default: begin state<=`STATE_FETCH_OP; address<=pc; writeEnable<=0; end
		endcase
	end
endtask

task FindPropAddrLen;
	begin
		case (phase[2:0])
			0: begin store<=data; address<=GetObjectAddr(operand[0])+7; phase<=phase+1; end
			1: begin temp[16]<=0; temp[15:8]<=data; temp[7:0]<=0; address<=address+1; phase<=phase+1; end
			2: begin address<=temp|data; phase<=phase+1; end
			3: begin address<=address+2*data+1; phase<=phase+1; end
			default: begin
				if (data==0) begin	// end of search
					StoreResultSlow(0);
				end else if (data[4:0]==operand[1]) begin // found property
					StoreResultSlow(address+1);
				end else begin // skip over data
					address<=address+data[7:5]+2;
				end
		   end
		endcase
	end
endtask

task FindNextProp;
	begin
		case (phase[2:0])
			0: begin store<=data; address<=GetObjectAddr(operand[0])+7; phase<=phase+1; end
			1: begin temp[16]<=0; temp[15:8]<=data; temp[7:0]<=0; address<=address+1; phase<=phase+1; end
			2: begin address<=temp|data; phase<=phase+1; end
			3: begin address<=address+2*data+1; phase<=phase+1; end
			default: begin
				if (operand[1]==0)
					StoreResultSlow(data[4:0]);
`ifndef REAL_HARDWARE
				else if (data==0)	// end of search
					state<=`STATE_HALT;
`endif
				else begin // skip over data
					if (data[4:0]==operand[1])
						operand[1]<=0;
					address<=address+data[7:5]+2;
				end
		   end
		endcase
	end
endtask

task GetPropLen;
	begin
		if (phase==0) begin
			address<=operand[0]-1; phase<=phase+1;
		end else begin
			StoreResultSlow((operand[0]==0)?0:(data[7:5]+1));
		end
	end
endtask

task Pull;
	input return;
	begin
		case (phase)
			0: begin
				address<=2*(stackAddress-1);
				phase<=phase+1;
			end
			1: begin
				temp[7:0]<=data;
				stackAddress<=address>>1;
				address<=address+1;
				phase<=phase+1;
			end
			default: begin
				if (return) begin
					ReturnFunction((temp[7:0]<<8)|data);
				end else begin
					if (operand[0]==0)
						stackAddress<=stackAddress-1;
					StoreRegisterAndBranch(operand[0], (temp[7:0]<<8)|data, negate);
				end
			end
		endcase

	end
endtask

task Print;
	input [16:0] addr;
	input [1:0] effect;
	begin
		temp<=addr;
		state<=`STATE_PRINT;
		returnValue[1:0]<=effect;
		delayedBranch<=0;
		phase<=0;
	end
endtask

task PrintObj;
	begin
		case (phase[1:0])
			0: begin address<=GetObjectAddr(operand[0])+7; phase<=phase+1; end
			1: begin store<=data; address<=address+1; phase<=phase+1; end
			default: Print((store<<8)+data+1, `PRINTEFFECT_FETCH);
		endcase
	end
endtask

task RemoveObject;
	begin
		case (phase[3:0])
			0: begin address<=GetObjectAddr(operand[0])+4; /*obj.parent*/ phase<=phase+1; end
			1: begin
				if (data==0) begin
					phase<=(operand[1]!=0)?6:9;
				end else begin
					phase<=phase+1;
				end
				temp[15:8]<=data;
				writeEnable<=1;
				dataOut<=operand[1];
			end
			2: begin writeEnable<=0; address<=address+1; /*obj.sibling*/ phase<=phase+1; end
			3: begin temp[7:0]<=data; writeEnable<=1; dataOut<=0; phase<=phase+1; end
			4: begin writeEnable<=0; address<=GetObjectAddr(temp[15:8])+6; /*parent.child*/ phase<=phase+1; end
			5: begin
				if (data==operand[0]) begin // found object
					dataOut<=temp[7:0];
					writeEnable<=1;
					phase<=(operand[1]!=0)?phase+1:9;
				end else begin
					address<=GetObjectAddr(data)+5; /*follow sibling*/
				end
			end

			6: begin address<=GetObjectAddr(operand[1])+6; writeEnable<=0; phase<=phase+1; end
			7: begin temp[7:0]<=data; writeEnable<=1; dataOut<=operand[0]; phase<=phase+1; end
			8: begin address<=GetObjectAddr(operand[0])+5; dataOut<=temp[7:0]; phase<=phase+1; end
			default: begin
				writeEnable<=0;
				state<=`STATE_FETCH_OP;
				address<=pc;
			end
		endcase
	end
endtask

task Random;
	begin
		case (phase)
			0: begin if ($signed(operand[0])<0) begin random<=operand[0]; state<=`STATE_FETCH_OP; end else begin random<=random^(random<<13); end phase<=phase+1; end
			1: begin random<=random^(random>>9); phase<=phase+1; end
			2: begin random<=random^(random<<7); phase<=phase+1; end
			default: begin state<=`STATE_DIVIDE; delayedBranch<=1; divideAddOne<=1; operand[1]<=operand[0]; operand[0]<=random&'h7FFF; phase<=0; end
		endcase
	end
endtask

task PrintNum;
	begin
`ifdef HARDWARE_PRINT
		case (phase)
			0: begin negate<=0; operand[1]<=1; operand[2][2:0]<=2; operand[3][3:0]<=0; phase<=phase+1; end
			1,2,3,4: begin operand[1]<=(operand[1]<<3)+(operand[1]<<1); printEnable<=0; phase<=phase+1; end
			5: begin
				if (operand[0]>=operand[1]) begin
					operand[0]<=operand[0]-operand[1];
					operand[3][3:0]<=operand[3][3:0]+1;
					negate<=1;
					printEnable<=0;
				end else begin
					printEnable<=negate;
					dataOut<=operand[3][3:0]+48;
					operand[3][3:0]<=0;
					operand[1]<=1;
					operand[2][2:0]<=operand[2][2:0]+1;
					phase<=operand[2][2:0];
				end
			end
			default: begin printEnable<=0; state<=`STATE_FETCH_OP; end
		endcase
`else
		operand[0]<=`PRINTNUM_CALLBACK;
		operand[1]<=operand[0];
		operTypes[1]<=`OPER_LARGE;
		CallFunction(0, 1);
`endif
	end
endtask

task PrintChar;
	input [7:0] char;
	begin
	   $display("Print char: %d\n", char);
	   uart_out <= char;
           uart_stb <= 1'b1;
	   state<=`STATE_PRINT_CHAR;
	end
endtask

task SRead;
	begin
		operand[0]<=`READ_CALLBACK;
		operand[2]<=operand[0]; // Am swapping arguments just to save space on FPGA
		operTypes[2]<=`OPER_LARGE;
		CallFunction(0, 1);
	end
endtask

task DoOp;
	begin
		case (operNum)
			`OP_0: begin
				if (phase==0)
					$display("PC:%h Doing op0:%d Store:%h Branch:%h/%d", curPC, op, operand[0], store, branch, negate);
				case (op[3:0])
					`OP0_RTRUE: ReturnFunction(1);
					`OP0_RFALSE: ReturnFunction(0);
					`OP0_PRINT: Print(pc, `PRINTEFFECT_FETCHAFTER);
					`OP0_PRINTRET: Print(pc, `PRINTEFFECT_RET1);
					`OP0_SAVE,`OP0_RESTORE: DoBranch(0);
					`OP0_RESTART: state<=`STATE_RESET;
					`OP0_RETPOP: Pull(1);
					`OP0_QUIT: begin operand[0]<=`QUIT_CALLBACK; CallFunction(0,1); end
					`OP0_NEWLINE: PrintChar(10);
					`OP0_SHOWSTATUS: begin operand[0]<=`STATUS_CALLBACK; CallFunction(0,1); end
					`OP0_VERIFY: DoBranch(1);
					default: state<=`STATE_HALT;
				endcase
			end
			`OP_1: begin
				if (phase==0)
					$display("PC:%h Doing op1:%d Operands:%h Store:%h Branch:%h/%d", curPC, op, operand[0], store, branch, negate);
				case (op[3:0])
					`OP1_JZ: DoBranch(operand[0]==0);
					`OP1_GETSIBLING: GetRelative(1,1);
					`OP1_GETCHILD: GetRelative(2,1);
					`OP1_GETPARENT: GetRelative(0,0);
					`OP1_GETPROPLEN: GetPropLen();
					`OP1_INC: StoreResult(operand[0]+1);
					`OP1_DEC: StoreResult(operand[0]-1);
					`OP1_PRINTADDR: Print(operand[0], `PRINTEFFECT_FETCH);
					`OP1_REMOVEOBJ: begin operNum<=`OP_2; op<=`OP2_INSERTOBJ; operand[1]<=0; end
					`OP1_PRINTOBJ: PrintObj();
					`OP1_RET: ReturnFunction(operand[0]);
					`OP1_JUMP: begin pc<=$signed(pc)+$signed(operand[0])-2; address<=$signed(pc)+$signed(operand[0])-2; state<=`STATE_FETCH_OP; end
					`OP1_PRINTPADDR: Print(2*operand[0], `PRINTEFFECT_FETCH); 
					`OP1_LOAD: StoreResult(operand[0]);
					`OP1_NOT: StoreResult(~operand[0]);
					default: state<=`STATE_HALT;
				endcase
			end
			`OP_2: begin
				if (phase==0)
					$display("PC:%h Doing op2:%d Operands:%h %h Store:%h Branch:%h/%d/%h", curPC, op, operand[0], operand[1], store, branch, negate, $signed(pc)+$signed(branch-2));
				case (op)
					`OP2_JE: DoBranch(operand[0]==operand[1] || (operTypes[2]!=`OPER_OMIT && operand[0]==operand[2]) || (operTypes[3]!=`OPER_OMIT && operand[0]==operand[3]));
					`OP2_JL: DoBranch($signed(operand[0])<$signed(operand[1]));
					`OP2_JG: DoBranch($signed(operand[0])>$signed(operand[1]));
					`OP2_INC_CHK: StoreResultAndBranch(operand[0]+1, $signed(operand[0])+1>$signed(operand[1]));
					`OP2_DEC_CHK: StoreResultAndBranch(operand[0]-1, $signed(operand[0])-1<$signed(operand[1]));
					`OP2_JIN: JumpIfParent();
					`OP2_TEST: DoBranch((operand[0]&operand[1])==operand[1]);
					`OP2_OR: StoreResult(operand[0]|operand[1]);
					`OP2_AND: StoreResult(operand[0]&operand[1]);
					`OP2_TESTATTR: TestAttr();
					`OP2_SETATTR: SetAttr();
					`OP2_CLEARATTR: ClearAttr();
					`OP2_STORE: begin if (operand[0]==0) stackAddress<=stackAddress-1; StoreRegisterAndBranch(operand[0], operand[1], negate); end
					`OP2_INSERTOBJ: RemoveObject();
					`OP2_LOADW: LoadAndStore(operand[0]+2*operand[1], 1);
					`OP2_LOADB: LoadAndStore(operand[0]+operand[1], 0);
					`OP2_GETPROP: FindProp();
					`OP2_GETPROPADDR: FindPropAddrLen();
					`OP2_GETNEXTPROP: FindNextProp();
					`OP2_ADD: StoreResult($signed(operand[0])+$signed(operand[1]));
					`OP2_SUB: StoreResult($signed(operand[0])-$signed(operand[1]));
					`OP2_MUL: StoreResult($signed(operand[0])*$signed(operand[1]));
					`OP2_DIV: begin store<=data; state<=`STATE_DIVIDE; delayedBranch<=0; divideAddOne<=0; end
					`OP2_MOD: begin store<=data; state<=`STATE_DIVIDE; delayedBranch<=1; divideAddOne<=0; end
					default: state<=`STATE_HALT;
				endcase
			end
			default: begin // 'OP_VAR
				if (phase==0) begin
					if (operTypes[0]==`OPER_OMIT)
						$display("PC:%h Doing opvar:%d Operands: Store:%h Branch:%h/%d/%h", curPC, op, store, branch, negate, $signed(pc)+$signed(branch-2));
					else if (operTypes[1]==`OPER_OMIT)
						$display("PC:%h Doing opvar:%d Operands:%h Store:%h Branch:%h/%d/%h", curPC, op, operand[0], store, branch, negate, $signed(pc)+$signed(branch-2));
					else if (operTypes[2]==`OPER_OMIT)
						$display("PC:%h Doing opvar:%d Operands:%h %h Store:%h Branch:%h/%d/%h", curPC, op, operand[0], operand[1], store, branch, negate, $signed(pc)+$signed(branch-2));
					else if (operTypes[3]==`OPER_OMIT)
						$display("PC:%h Doing opvar:%d Operands:%h %h %h Store:%h Branch:%h/%d/%h", curPC, op, operand[0], operand[1], operand[2], store, branch, negate, $signed(pc)+$signed(branch-2));
					else
						$display("PC:%h Doing opvar:%d Operands:%h %h %h %h Store:%h Branch:%h/%d/%h", curPC, op, operand[0], operand[1], operand[2], operand[3], store, branch, negate, $signed(pc)+$signed(branch-2));
				end
				case (op)
					`OPVAR_CALL: if (operand[0]==0) StoreResultSlow(0); else CallFunction(0, 0);
					`OPVAR_STOREW: StoreW();
					`OPVAR_STOREB: StoreB();
					`OPVAR_PUTPROP: SetProp();
					`OPVAR_SREAD: SRead();
					`OPVAR_PRINTCHAR: PrintChar(operand[0]);
					`OPVAR_PRINTNUM: PrintNum();
					`OPVAR_RANDOM: Random();
					`OPVAR_PUSH: StoreRegisterAndBranch(0, operand[0], negate);
					`OPVAR_PULL: Pull(0);
					default: state<=`STATE_HALT;
				endcase
			end
		endcase
	end
endtask
			
`ifdef HARDWARE_PRINT
task DoPrint;
	input [4:0] char;
	begin
		if (delayedBranch) begin
			store[4:0]<=char;
			operand[1]<=phase+1;
			delayedBranch<=0;
			phase<=6;
		end else if (long==1) begin
			operand[3][4:0]=char;
			long<=long+1;
		end else if (long==2) begin
			printEnable<=1;
			dataOut<=(operand[3][4:0]<<5)|char;
			long<=0;
		end else begin
			phase<=phase+1;
			if (char==0) begin
				printEnable<=1;
				dataOut<=32;
			end else if (char==4 || char==5) begin
				printEnable<=0;
				alphabet=char-3;
			end else if (char>=6) begin
				printEnable<=!(alphabet==2 && char==6);
				if (alphabet==2) begin
					case (char)
						6: long<=1;
						7: dataOut<=10;
						8,9,10,11,12,13,14,15,16,17: dataOut<=char-8+48;
						18: dataOut<=46;
						19: dataOut<=44;
						20: dataOut<=33;
						21: dataOut<=63;
						22: dataOut<=95;
						23: dataOut<=35;
						24: dataOut<=39;
						25: dataOut<=34;
						26: dataOut<=47;
						27: dataOut<=92;
						28: dataOut<=45;
						29: dataOut<=58;
						30: dataOut<=40;
						31: dataOut<=41;
					endcase
				end else begin
					dataOut<=char-6+((alphabet==0)?97:65);
				end
				alphabet<=0;
			end else begin
				printEnable<=0;
				store[7:5]<=(char-1);
				delayedBranch<=1;
			end
		end
	end
endtask
`endif

task FinishReadingOps;
begin
	case (operNum)
		`OP_1: begin
			case (op[3:0])
				`OP1_INC, `OP1_DEC, `OP1_LOAD: state<=`STATE_READ_INDIRECT;
				`OP1_GETSIBLING,`OP1_GETCHILD,`OP1_GETPARENT,`OP1_GETPROPLEN,`OP1_NOT: state<=`STATE_READ_STORE;
				`OP1_JZ: state<=`STATE_READ_BRANCH;
				default: state<=`STATE_DO_OP;
			endcase
			pc<=pc+1;
		end
		`OP_2: begin
			case (op[4:0])
				`OP2_INC_CHK,`OP2_DEC_CHK: begin pc<=pc+1; state<=`STATE_READ_INDIRECT; end
				`OP2_OR,`OP2_AND,`OP2_ADD,`OP2_SUB,`OP2_MUL: begin pc<=pc+1; state<=`STATE_READ_STORE; end
				`OP2_LOADW,`OP2_LOADB,`OP2_GETPROP ,`OP2_GETPROPADDR,`OP2_GETNEXTPROP,`OP2_DIV,`OP2_MOD: begin pc<=pc+2; state<=`STATE_DO_OP; end
				`OP2_JE,`OP2_JL,`OP2_JG,`OP2_JIN,`OP2_TEST,`OP2_TESTATTR: begin pc<=pc+1; state<=`STATE_READ_BRANCH; end
				default: begin pc<=pc+1; state<=`STATE_DO_OP; end
			endcase
		end
		default: begin // `OP_VAR
			pc<=pc+1;
			case (op[4:0])
				`OPVAR_CALL,`OPVAR_RANDOM: state<=`STATE_READ_STORE;
				default: state<=`STATE_DO_OP;
			endcase
		end
	endcase
end
endtask

always @ (posedge clk)
begin
   if (!reset)
   begin
      phase <= 0;
      state <= `STATE_RESET;
   end
   else
	case(state)
		`STATE_RESET: begin
			case (phase)
			  0:
			    begin
			       address <= 0;
			       pc <= 19'h0_0040;
			       romHighAddr <= `PROG0_HIGH_ADDR;
			       romEnable <= 1;
			       
			       phase <= phase + 1;
			    end
			  1:
			    begin
			       dataOut <= romData;
			       writeEnable <= 1;

			       // We can update prog_size byte by byte because
			       // it is stored big-endian in the file.
			       if (address == `ZHEAD_FILE_LEN_MSB)
				 pc[16:9] = romData;
			       if (address == `ZHEAD_FILE_LEN_LSB)
				 pc[8:1] = romData;

			       phase <= 2;
			    end
			  2:
			    begin
			       address <= address + 1'b1;
			       if (address < pc)
				 phase <= 1;
			       else
				 begin
				    writeEnable <= 0;
				    phase <= 3;
				 end
			    end
			  
			  3: begin romEnable <=0; random<=1; address<='h6; phase<=phase+1; end
				4: begin address<='h7; phase<=phase+1; pc[15:8]<=data; pc[16]<=0; end
				5: begin address<='hA; phase<=phase+1; pc[7:0]<=data; end
				6: begin address<='hB; phase<=phase+1; objectTable[15:8]<=data; end
				7: begin address<='hC; phase<=phase+1; objectTable[7:0]<=data; end
				8: begin address<='hD; phase<=phase+1; globalsAddress[15:8]<=data; end
				9: begin address<=0; phase<=phase+1; globalsAddress[7:0]<=data; end
			  
				// 9: begin dataOut<=data; writeEnable<=1; phase<=10; end
				// 10: begin writeEnable<=0; address<=address+1; if (address[15:0]=='hffff) phase<=11; else phase<=9; end
				// 11: begin
				//    writeEnable<=1;
				//    dataOut<=0;
				//    address<=address+1;
				//    if (address[15:0]=='hffff)
				//    begin
				//       writeEnable<=0;
				//       phase<=12;
				//    end
				// end
				// 12: begin address<=address+1; if (address[10:0]=='h7ff) phase<=13; end
				default: begin
					cachedReg<=15;
					address<=pc;
					stackAddress<=64*1024/2;
					csStack<=65*1024;
					// operand[0]<=`INIT_CALLBACK;
					// operTypes[1]<=`OPER_OMIT;
					// CallFunction(0, 1);
				   state <= `STATE_FETCH_OP;
				end
			endcase
		end
		`STATE_CALL_FUNCTION: begin
			case (phase)
				0: begin $display("Call function %h", operand[0]*2); address<=csStack; writeEnable<=1; dataOut<=(delayedBranch<<2)|(negate<<1)|pc[16]; phase<=phase+1; end
				1: begin address<=address+1; dataOut<=pc[15:8]; phase<=phase+1; end
				2: begin address<=address+1; dataOut<=pc[7:0]; phase<=4; end
				3: begin end // pointless phase but for some reason saves gates
				4: begin address<=address+1; dataOut<=stackAddress[15:8]; phase<=phase+1; end
				5: begin address<=address+1; dataOut<=stackAddress[7:0]; phase<=phase+1; end
				6: begin address<=address+1; dataOut<=store; phase<=phase+1; end
				default: begin
					cachedReg<=15;
					csStack<=csStack+38;
					address<=2*operand[0];
					state<=`STATE_READ_FUNCTION;
					writeEnable<=0;
					phase<=0;
				end
				// 0: begin $display("Call function %h", operand[0]*2); address<=csStack; writeEnable<=1; dataOut<=(delayedBranch<<2)|(negate<<1)|pc[16]; phase<=phase+1; end
				// 1: begin address<=address+1; dataOut<=pc[15:8]; phase<=phase+1; end
				// 2: begin address<=address+1; dataOut<=pc[7:0]; phase<=4; end
				// 3: begin end // pointless phase but for some reason saves gates
				// 4: begin address<=address+1; dataOut<=stackAddress[15:8]; phase<=phase+1; end
				// 5: begin address<=address+1; dataOut<=stackAddress[7:0]; phase<=phase+1; end
				// 6: begin address<=address+1; dataOut<=store; phase<=(operand[0][15:3]==0)?phase+1:10; end
				// 7: begin address<=`CALLBACK_BASE+5*(operand[0]&7); writeEnable<=0; phase<=phase+1; end
				// 8: begin address<=address+1; operand[0][15:8]<=data; phase<=phase+1; end
				// 9: begin operand[0][7:0]<=data; phase<=phase+1; end
				// default: begin
				// 	cachedReg<=15;
				// 	csStack<=csStack+38;
				// 	address<=2*operand[0];
				// 	state<=`STATE_READ_FUNCTION;
				// 	writeEnable<=0;
				// 	phase<=0;
				// end
			endcase
		end
		`STATE_RET_FUNCTION: begin
			case (phase)
				0: begin csStack<=csStack-38; address<=csStack-38; phase<=phase+1; end
				1: begin pc[16]<=data[0]; negate<=data[1]; delayedBranch<=data[2]; address<=address+1; phase<=phase+1; end
				2: begin pc[15:8]<=data; address<=address+1; phase<=phase+1; end
				3: begin pc[7:0]<=data; address<=address+1; phase<=phase+1; end
				4: begin stackAddress[15:8]<=data; address<=address+1; phase<=phase+1; end
				5: begin stackAddress[7:0]<=data; address<=address+1; phase<=phase+1; end
				default: begin
					cachedReg<=15;
					if (negate) begin
						phase<=0;
					end else if (delayedBranch) begin
						state<=`STATE_FETCH_OP;
						address<=pc;
					end else begin
						StoreRegisterAndBranch(data, returnValue, negate);
					end
				end
			endcase
		end
		`STATE_READ_FUNCTION: begin
			case (phase)
				0: begin
					if (data==0) begin
						state<=`STATE_FETCH_OP;
					end else begin
						opsToRead<=4*data-1;
						phase<=phase+1;
					end
					currentLocal<=0;
					pc<=address+1;
					address<=address+1;
				end
				default: begin
					if (opsToRead&1) begin
						if (currentLocal<6 && operTypes[(currentLocal>>1)+1]!=`OPER_OMIT) begin
							dataOut<=currentLocal[0]?operand[(currentLocal>>1)+1][7:0]:operand[(currentLocal>>1)+1][15:8];
						end else begin
							dataOut<=data;
						end
						address<=csStack+8+currentLocal;
						writeEnable<=1;
						currentLocal<=currentLocal+1;
					end else begin
						pc<=pc+1;
						address<=pc+1;
						writeEnable<=0;
					end
					if (opsToRead==0) begin
						state<=`STATE_FETCH_OP;						
					end
					opsToRead<=opsToRead-1;
				end
			endcase
		end
		`STATE_FETCH_OP: begin
			phase<=0;
			operTypes[2]<=`OPER_OMIT;
			operTypes[3]<=`OPER_OMIT;
			operTypes[4]<=`OPER_OMIT;
			curPC<=pc;
			$display("Fetching op at %h", pc);
			if (!reset) begin
				state<=`STATE_RESET;
			end else begin
				case (data[7:6])
					2'b10: begin
						// short form
						op[4:0]<=data[3:0];
						operTypes[0]<=data[5:4];
						operTypes[1]<=`OPER_OMIT;
						if (data[5:4]==2'b11) begin
							operNum[1:0]<=`OP_0;
							case (data[3:0])
								`OP0_POP: begin cachedReg<=15; stackAddress<=stackAddress-1; end
								`OP0_NOP: begin /*nop*/ end
								`OP0_SAVE,`OP0_RESTORE,`OP0_VERIFY: state<=`STATE_READ_BRANCH;
								default: state<=`STATE_DO_OP;
							endcase
						end else begin
							operNum[1:0]<=`OP_1;
							state<=`STATE_READ_OPERS;
						end
					end
					2'b11: begin
						// variable form
						op[4:0]<=data[4:0];
						operNum[1:0]<=(data[5]?`OP_VAR:`OP_2);
						state<=`STATE_READ_TYPES;
					end
					default: begin
						// long form
						op[4:0]<=data[4:0];
						operNum[1:0]<=`OP_2;
						operTypes[0]<=(data[6] ? `OPER_VARI : `OPER_SMALL);
						operTypes[1]<=(data[5] ? `OPER_VARI : `OPER_SMALL);
						state<=`STATE_READ_OPERS;
					end
				endcase
			end
			operandIdx<=0;
			pc<=pc+1;
			address<=pc+1;
		end
		`STATE_READ_TYPES: begin
			operTypes[0]<=data[7:6];
			operTypes[1]<=data[5:4];
			operTypes[2]<=data[3:2];
			operTypes[3]<=data[1:0];
			address<=pc+1;
			if (data[7:6]==`OPER_OMIT)
				FinishReadingOps();
			else begin
				state<=`STATE_READ_OPERS;
				pc<=pc+1;
			end
		end
		`STATE_READ_OPERS: begin
			case (operTypes[operandIdx])
				`OPER_SMALL: begin
					operand[operandIdx]<=data[7:0];
					address<=pc+1;
					operandIdx<=operandIdx+1;
					if (operTypes[operandIdx+1]==`OPER_OMIT)
						FinishReadingOps();
					else
						pc<=pc+1;
				end
				`OPER_LARGE: begin
					address<=pc+1;
					if (!readHigh) begin
						operand[operandIdx][15:8]<=data[7:0];
						readHigh<=1;
						pc<=pc+1;
					end else begin
						operand[operandIdx][7:0]<=data[7:0];
						operandIdx<=operandIdx+1;
						readHigh<=0;
						if (operTypes[operandIdx+1]==`OPER_OMIT)
							FinishReadingOps();
						else
							pc<=pc+1;
					end
				end
				default: begin // OPER_VARI
					case (phase)
						0: begin
							if (data==0) begin
								stackAddress<=stackAddress-1;
							end
							if (cachedReg!=15 && data==cachedReg) begin
								operand[operandIdx]<=cachedValue;
								address<=pc+1;
								operandIdx<=operandIdx+1;
								if (operTypes[operandIdx+1]==`OPER_OMIT)
									FinishReadingOps();
								else
									pc<=pc+1;
								if (cachedReg==0)
									cachedReg<=15;
							end else begin
								if (data>=16) begin
									address<=globalsAddress+2*(data-16);
								end else if (data==0) begin
									address<=2*(stackAddress-1);
								end else begin
									address<=csStack+8+2*(data-1);
								end
								phase<=phase+1;
							end
						end
						1: begin
							operand[operandIdx]<=(data<<8);
							address<=address+1;
							phase<=phase+1;
						end
						default: begin
							operand[operandIdx]<=operand[operandIdx]|data;
							address<=pc+1;
							operandIdx<=operandIdx+1;
							if (operTypes[operandIdx+1]==`OPER_OMIT)
								FinishReadingOps();
							else
								pc<=pc+1;
							phase<=0;
						end
					endcase
				end
			endcase
		end
		`STATE_READ_INDIRECT: begin
			case (phase)
				0: begin
					cachedReg<=15;
					store<=operand[0];
					if (operand[0]>=16) begin
						address<=globalsAddress+2*(operand[0]-16);
					end else if (operand[0]==0) begin
						if (op[4:0]!=`OP1_LOAD)
							stackAddress<=stackAddress-1;
						address<=2*(stackAddress-1);
					end else begin
						address<=csStack+8+2*(operand[0]-1);
					end
					phase<=phase+1;
				end
				1: begin
					operand[0][15:8]<=data;
					address<=address+1;
					phase<=phase+1;
				end
				default: begin
					operand[0][7:0]<=data;
					if (op[4:0]==`OP1_LOAD)
						state<=`STATE_READ_STORE;
					else if (operNum==`OP_2)
						state<=`STATE_READ_BRANCH;
					else
						state<=`STATE_DO_OP;
					address<=pc;
					phase<=0;
				end
			endcase
		end
		`STATE_READ_STORE: begin
			case (op[4:0])
				`OP1_GETSIBLING, `OP1_GETCHILD: state<=`STATE_READ_BRANCH;
				default: state<=`STATE_DO_OP;
			endcase
			store<=data;
			pc<=pc+1;
			address<=pc+1;
		end
		`STATE_READ_BRANCH: begin
			if (!readHigh) begin
				if (data[6]) begin
					branch<=data[5:0];
					negate<=!data[7];
					state<=`STATE_DO_OP;
				end else begin
					branch[13:8]<=data[5:0];
					negate<=!data[7];
					readHigh<=1;
				end
			end else begin
				branch[7:0]<=data;
				readHigh<=0;
				state<=`STATE_DO_OP;
			end
			pc<=pc+1;
			address<=pc+1;
		end
		`STATE_DO_OP: begin
			DoOp();
		end
		`STATE_STORE_REGISTER: begin
			case (phase)
				0: begin
					if (store>=16) begin
						address<=globalsAddress+2*(store-16);
					end else if (store==0) begin
						address<=2*stackAddress;
						stackAddress<=stackAddress+1;
					end else begin
						address<=csStack+8+2*(store-1);
					end
					dataOut<=returnValue[15:8];
					writeEnable<=1;
					phase<=phase+1;
				end
				1: begin
					cachedReg<=store;
					cachedValue[15:8]<=dataOut;
					cachedValue[7:0]<=returnValue[7:0];
					dataOut<=returnValue[7:0];
					address<=address+1;
					phase<=phase+1;
				end
				default: begin
					DoBranch(delayedBranch);
					writeEnable<=0;
					phase<=0;
				end
			endcase
		end
		`STATE_DIVIDE: begin
			case (phase)
				0: begin
					negate<=operand[0][15]^operand[1][15];
					readHigh<=operand[0][15];
					if ($signed(operand[0])<0)
						operand[0]<=-operand[0];
					else
						operand[0]<=operand[0];
`ifndef REAL_HARDWARE
					if (operand[1]==0)
						state<=`STATE_HALT;
					else
`endif
					if ($signed(operand[1])<0)
						operand[1]<=-operand[1];
					operand[2]<=1;
					operand[3]<=0;
					phase<=phase+1;
				end
				1: begin
					if (operand[1][15] || operand[0]<=operand[1]) begin
						phase<=phase+1;
					end else begin
						operand[1]<=operand[1]<<1;
						operand[2]<=operand[2]<<1;
					end
				end
				2: begin
					if (operand[1]>operand[0]) begin
						if (operand[2]==1) begin
							if (negate) begin
								operand[0]<=-operand[3];
							end else begin
								operand[0]<=operand[3];
							end
							if (readHigh) begin
								operand[1]<=-operand[0];
							end else begin
								operand[1]<=operand[0];
							end
							readHigh<=0;
							phase<=phase+1;
						end else begin
							operand[1]<=operand[1]>>1;
							operand[2]<=operand[2]>>1;
						end
					end else begin
						operand[0]<=operand[0]-operand[1];
						operand[3]<=operand[3]+operand[2];
					end
				end
				default: begin
					StoreResultSlow(delayedBranch?(operand[1]+divideAddOne):operand[0]);
				end
			endcase
		end
		`STATE_PRINT: begin
`ifdef HARDWARE_PRINT
			case (phase)
				0: begin delayedValue[15:8]<=data; address<=address+1; phase<=phase+1; end
				1: begin delayedValue[7:0] <=data; address<=address+1; phase<=phase+1; end
				2,3,4: begin DoPrint(delayedValue[14:10]); delayedValue[14:5]<=delayedValue[9:0]; end
				5: begin
					printEnable<=0;
					if (delayedValue[15]) begin
						alphabet<=0;
						long<=0;
						case (returnValue[1:0])
							`PRINTEFFECT_FETCH: begin
								address<=pc;
								state<=`STATE_FETCH_OP;
							end
							`PRINTEFFECT_FETCHAFTER: begin
								pc<=address;
								state<=`STATE_FETCH_OP;
							end
							`PRINTEFFECT_RET1: begin
								ReturnFunction(1);
							end
							`PRINTEFFECT_ABBREVRET: begin
								address<=temp;
								delayedValue<=operand[0];
								phase<=operand[1];
								returnValue[1:0]<=returnValue[3:2]; 
							end
						endcase
					end else begin
						phase<=0;
					end
				end
				// branch to abbrev
				6: begin
					address<='h18;
					phase<=phase+1;
					temp<=address;
					operand[0]<=delayedValue;
					returnValue[3:2]=returnValue[1:0];
					returnValue[1:0]=`PRINTEFFECT_ABBREVRET; 
				end
				7: begin address<=address+1; operand[2][7:0]=data; phase<=phase+1; end
				8: begin address<=(operand[2][7:0]<<8)|data+2*store; phase<=phase+1; end
				9: begin address<=address+1; operand[2][7:0]<=data; phase<=phase+1; end
				default: begin address<=2*((operand[2][7:0]<<8)|data); phase<=0; end
			endcase
`else
			if (data[7] || returnValue[1:0]!=`PRINTEFFECT_FETCHAFTER) begin
				if (returnValue[1:0]==`PRINTEFFECT_FETCHAFTER)
					pc<=address+2;
				operand[0]<=`PRINT_CALLBACK; 
				$display("Print from %h\n", temp);
				operand[1]<=temp[0]|((returnValue[1:0]==`PRINTEFFECT_RET1)?2:0); operand[2]<=temp[16:1];
				operTypes[1]=`OPER_LARGE; operTypes[2]=`OPER_LARGE;
				CallFunction(returnValue[1:0]==`PRINTEFFECT_RET1, 1);
			end else begin
				address<=address+2;
			end
`endif
		end
		`STATE_PRINT_CHAR:
		  if (!uart_busy)
		  begin
		     uart_stb <= 1'b0;
		     address<=pc;
		     state<=`STATE_FETCH_OP;
		  end
		default: begin
			$display("HALT");
			operand[1]<=(pc>>1);
			operand[2]<=operand[0];
			operand[3]<=operand[1];
			operand[0]<=`EXCEPTION_CALLBACK;
			//operTypes[0]<=`OPER_LARGE;
			operTypes[1]<=`OPER_LARGE;
			operTypes[2]<=`OPER_LARGE;
			operTypes[3]<=`OPER_LARGE;
			CallFunction(0,1);
		end
	endcase
end

endmodule

module main();

reg clk;
reg reset;
wire [7:0] data;
wire [16:0] address;
wire writeEnable;
wire led0;
wire led1;
wire led2;
wire txd;
wire [7:0] romData;
wire [21:17] romHighAddr;
wire 	     romEnable;

integer file,readData,i,j,numOps,cycles,stateCycles[15:0],opCycles[255:0],ops[255:0];
reg [7:0] rom [128*1024:0];
reg [7:0] ram [128*1024:0];

assign data= !writeEnable ? 8'bZ : ram[address];
assign romData = rom[address];

initial
begin
	$display("Welcome");
	file=$fopen("../hello_world.z3","rb");
	readData=$fread(rom, file);
	$display("File read:%h %d", file, readData);
	$fclose(file);
	reset=1;
	numOps=0;
	cycles=0;

	for (i=0; i<16; i=i+1)
		stateCycles[i]=0;
	for (i=0; i<256; i=i+1) begin
		opCycles[i]=0;
		ops[i]=0;
	end
	//$monitor("%h %h %h State:%d(%d) Op:%h Num:%h OperType:%h%h%h%h OperIdx:%d Operand:%h %h Store:%h Branch:%h", clk, data, address, b.state, b.phase, b.op, b.operNum, b.operTypes[0], b.operTypes[1], b.operTypes[2], b.operTypes[3], b.operandIdx, b.operand[0], b.operand[1], b.store, b.branch);
	for (i=0; i</*505*/10000000; i=i+1) begin
		clk=1;
		#5 clk=0;
	   
		if ( !writeEnable) begin
			ram[address]=data;
		end
`ifdef HARDWARE_PRINT
		if (!printEnable) begin
			$display("PRINT: %c", data);
		end
`endif
		if (b.state==`STATE_HALT) begin
			$display("Halt");
			i=10000000;
		end
		//if (b.curPC<'h1e000)
		begin
			if (b.state==`STATE_FETCH_OP) begin
				ops[b.op+(32*b.operNum)]=ops[b.op+(32*b.operNum)]+1;
				numOps=numOps+1;
			end
			if (b.state!=`STATE_RESET) begin
				cycles=cycles+1;
				opCycles[b.op+(32*b.operNum)]=opCycles[b.op+(32*b.operNum)]+1;
			end
			stateCycles[b.state]=stateCycles[b.state]+1;
		end
		$display("Mem req: %h WE:%d D:%h LEDs:%d%d%d Ops:%d/%d", address, !writeEnable, data, !led0, !led1, !led2, numOps, cycles);
	end
	for (i=0; i<16; i=i+1)
		if (stateCycles[i]>0)
			$display("State:%d %d", i, stateCycles[i]);
	for (i=0; i<256; i=i+1)
		if (opCycles[i]>0)
			$display("OpCyc:%d/%d %d/%d=%d", i/32, i%32, opCycles[i], ops[i], opCycles[i]/ops[i]);
	file=$fopen("ram.dat", "wb");
	for (i=0; i<'h20000; i=i+16) begin
		$fwrite(file, "%05h: ", i);
		for (j=0; j<16; j=j+2)
			$fwrite(file, "%02x%02x ", ram[i+j][7:0], ram[i+j+1][7:0]);
		for (j=0; j<16; j=j+1)
			$fwrite(file, "%c", (ram[i+j][7:0]>=32)?ram[i+j][7:0]:46);
		$fwrite(file, "\n");
	end
	$fwrite(file, "\nBitmap:\n");
	for (i='h1b500; i<'h20000; i=i+30) begin
		for (j=0; j<30; j=j+1)
			$fwrite(file, "%d%d%d%d%d%d%d%d",
		ram[i+j][7], ram[i+j][6],
		ram[i+j][5], ram[i+j][4],
		ram[i+j][3], ram[i+j][2],
		ram[i+j][1], ram[i+j][0]);
		$fwrite(file, "\n");
	end
	$fclose(file);
	$finish;
end

boss b(clk, reset, data, address, writeEnable, led0, led1, led2, txd, romData, romHighAddr, romEnable);

endmodule
