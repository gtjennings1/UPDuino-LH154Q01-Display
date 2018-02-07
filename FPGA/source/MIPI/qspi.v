/******************************************************************************
Copyright 2017 Gnarly Grey LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
******************************************************************************/

module qspi (
  output sclk,          ///27MHZ output
  output reg ss_n, 
  inout q0,
  output fifo_rdy,
  input q1,
  input q2,
  input q3,
  input clk,            ///27MHz continuous read;
  input reset_n ,
  output [25:0] pixdata ,  ///3x8+ Hstart / Vstart flag;         
  input pixclk  , ///read FIFO clk;
  input pixen  ,  //sent by control logic after HSYNC BLANKING;
  input [3:0] img_id, ///8 images are stored in the memory;
  input start         ///start control; level controlled, 0---hold initial state; 1---start;
);

localparam MAX_PKT_LENGTH = 720; //a line 240*3 = 720
wire q0_in = q0;
wire q0_out;
reg q0_dir;
assign q0 = (q0_dir)?q0_out:1'bz; 
reg [1:0] q3_int,q2_int,q1_int,q0_int;
reg [7:0] rcv_data;
reg  rcv_data_vld;
reg [10:0] rcv_cnt;  //// 240*3*2;   
reg [21:0] shifter;  ////10bit col address not included;
reg line_end;
reg line_end_d0,line_end_d1;
reg sclk_gate;
reg [5:0] shifter_cnt;
reg [1:0] rgb_cnt;
reg [23:0] rgb_data;
reg v_flag;
reg h_flag;
wire almostfull;
reg pix_en_int;
wire fifo_rdy_int,full;
assign fifo_rdy = ~fifo_rdy_int;

//////////////// almostfull not desert!!! use PMI FIFO_DC;
///spi2pixel spi2pixel_inst (
///   .Data({v_flag, h_flag, rgb_data}), 
///	 .WrClock(sclk),  ///sclk , same as receiver clock;
///	 .RdClock(pixclk), 
///	 .WrEn(pix_en_int), //top control guarantee not over flow;
///	 .RdEn(pixen), 
///	 .Reset(~reset_n), 
///	 .RPReset(start), ////////Jan 28
///	 .Q(pixdata), 
///   .Empty(), 
///	 .Full(full), 
///	 .AlmostEmpty(fifo_rdy_int), ///240,dont start before a full line is buffered;
///	 .AlmostFull(almostfull)  //272
///	 )/* synthesis NGD_DRC_MASK=1 */;
localparam FIFO_DPTH = 512;
localparam AFF= FIFO_DPTH-240;

reg [1:0] v_flag_sync, h_flag_sync,pix_en_int_sync;
reg [23:0] rgb_data_sync,rgb_data_d0;

/* pmi_fifo_dc #(
      .pmi_data_width_w     (26),
      .pmi_data_width_r     (26),
      .pmi_data_depth_w     (FIFO_DPTH),
      .pmi_data_depth_r     (FIFO_DPTH),
      .pmi_full_flag        (FIFO_DPTH),
      .pmi_empty_flag       (0),
      .pmi_almost_full_flag (AFF),
      .pmi_almost_empty_flag(240),
      .pmi_regmode ("noreg"),
      .pmi_resetmode  ("async"),
      .pmi_family ("XO2") ,
      .module_type  ("pmi_fifo_dc"),
      .pmi_implementation  ("EBR")
		     ) */
  spi2pixel
  spi2pixel_inst (
      .Data       ({v_flag_sync[1], h_flag_sync[1], rgb_data_sync}),
      .WrClock    (clk),
      .RdClock    (pixclk),
      .WrEn       (pix_en_int_sync[1]),
      .RdEn       (pixen),
      .Reset      (~reset_n),
      .RPReset    (start),
      .Q          (pixdata),
      .Empty      (),
      .Full       (full),
      .AlmostEmpty(fifo_rdy_int),
      .AlmostFull (almostfull))/*synthesis syn_black_box */;

always @(negedge reset_n or posedge clk)
if (~reset_n) begin
   v_flag_sync <= 2'b00;
   h_flag_sync <= 2'b00;
   pix_en_int_sync <= 2'b00;
   rgb_data_sync <= 23'h000000;   
   rgb_data_d0 <= 23'h000000;   
end
else begin
   v_flag_sync <= {v_flag_sync[0],v_flag};
   h_flag_sync <= {h_flag_sync[0],h_flag};
   pix_en_int_sync <= {pix_en_int_sync[0],pix_en_int};
   rgb_data_sync <= rgb_data_d0;   
   rgb_data_d0 <= rgb_data;   
end

/// start, restart control;
reg [5:0] rd_en;
wire rd_start = rd_en[5];
reg almostfull1;
always @(negedge clk or negedge reset_n)
if (~reset_n) begin
   rd_en <= 2'b00;
   almostfull1 <= 0;
end
else begin
   almostfull1<=almostfull;
   rd_en[4:0] <= {rd_en[3:0], ((start | line_end_d1)&~almostfull | (~almostfull & almostfull1))} ; ///restart only when buffer is enouth a whole line(512-272=240);
   rd_en[5] <= (rd_en[4:3]==2'b01)? 1'b1:1'b0;
end

///ss_n and SCLK gate;
always @(negedge clk or negedge reset_n)
if (~reset_n) begin
   sclk_gate <= 1'b0;
   ss_n      <= 1'b1;
end
else if (rd_start)begin
   sclk_gate <= 1'b1;
   ss_n      <= 1'b0;
end
else if (line_end_d1==1)begin
   sclk_gate <= 1'b0;
   ss_n      <= 1'b1;
end
assign sclk = sclk_gate & clk; 

////    cmd==8'h6b                               shifter[31:24]
///     addr[23:22] == 0;                        shifter[23:22]
/// image address       addr[21:18]              shifter[21:18]
///row address; 0-239 ; addr[17:10] ; 240/256;   shifter[17:10]
///line data 0-719; addr[9:0]; Image line data is not continuously stored in SPI flash to simplify logic; 720/1024

///shifter; send command/address  negedge clk domain;
reg vstart;
reg [7:0] col_addr, row_addr;
always @(negedge clk or negedge reset_n)
if (~reset_n)
	      shifter <={8'h6b, 2'b00 ,img_id ,8'h00}; //22bits
else if (rd_start)
	      shifter[7:0]  <= row_addr;
      else if (sclk_gate)
	      shifter <={shifter[20:0],1'b0};
always @(negedge clk or negedge reset_n)
if (~reset_n)
	      row_addr <=8'h00;
else if (~line_end_d1&line_end_d0)
		         if (row_addr<239)
 		            row_addr <= row_addr + 1;
   			     else
			        row_addr <= 8'h00;

assign q0_out = shifter[21];

///////////////////SHIFTER COUNTER
always @(negedge clk or negedge reset_n)
if (~reset_n)
   shifter_cnt <= 6'b000000;
else 
   if (ss_n==1)
      shifter_cnt <= 6'b000000;
   else if (shifter_cnt<40)
      shifter_cnt <= shifter_cnt +1;
/// q0 direction control;
always @(negedge clk or negedge reset_n) 
if (~reset_n)
         q0_dir <= 0;
else if (rd_start)
         q0_dir <= 1;
else if (shifter_cnt > 32)
         q0_dir <= 0;
always @(negedge clk or negedge reset_n) 
if (~reset_n) begin
         line_end_d0 <= 0;
         line_end_d1 <= 0;
end
else begin
         line_end_d0 <= line_end;
         line_end_d1 <= line_end_d0;
end

////////////////////////////////////////receive data, sclk domain////////////////////////
wire reset_n1 = reset_n & ~ss_n;
always @(posedge sclk or negedge reset_n1)
if (~reset_n1)
   rcv_cnt <= 0;
//else if (ss_n)
//   rcv_cnt <= 0;
else if (rcv_cnt < 2*MAX_PKT_LENGTH + 40+2) ///receive clock count
   rcv_cnt <= rcv_cnt + 1'b1;

always @(posedge sclk or negedge reset_n1)
if (~reset_n1)
   line_end <= 0;
//else if (ss_n)
//   line_end <= 0;
else if (rcv_cnt == (2*MAX_PKT_LENGTH + 40+2)) ///Jan 28, for registered receive data;
   line_end <= 1'b1;

always @(posedge sclk or negedge reset_n1)
if (~reset_n1) begin
   h_flag <= 1'b0;
   v_flag <= 1'b0;
   end
//else if (ss_n) begin
//   h_flag <= 1'b0;
//   v_flag <= 1'b0;
//   end
else if (rcv_cnt==42) begin
   h_flag <= 1'b1;
   if (~(|row_addr))
   v_flag <= 1'b1;
   end
   else if (pix_en_int) begin
   h_flag <= 1'b0;
   v_flag <= 1'b0;
   end

always @(posedge sclk or negedge reset_n1)  /////2 SCLK ---> 1 DATA
if (~reset_n1) begin                        /////6 SCLK ---> 1 RGB DATA;
   rcv_data <= 0;
   rcv_data_vld <= 0;
   rgb_cnt <= 0;
   rgb_data <= 0;
end
//else if (ss_n) begin
//   rcv_data <= 0;
//   rcv_data_vld <= 0;
//   rgb_cnt <= 0;
//   rgb_data <= 0;
//   end
else if (rcv_cnt[0]==1'b0 && rcv_cnt>41 && line_end==0 ) begin      ///ss_n will be high after line_end==1;
   if (rgb_cnt>=2) begin
	   rgb_cnt <= 2'b00;
	end
   else begin
	   rgb_cnt <= rgb_cnt + 1;
	end
   if (rgb_cnt==0)
       rgb_data[7:0] <= {q3_int[1],q2_int[1],q1_int[1],q0_int[1],q3_int[0],q2_int[0],q1_int[0],q0_int[0]};
	else if (rgb_cnt==1)
       rgb_data[15:8] <= {q3_int[1],q2_int[1],q1_int[1],q0_int[1],q3_int[0],q2_int[0],q1_int[0],q0_int[0]};
	else
       rgb_data[23:16] <= {q3_int[1],q2_int[1],q1_int[1],q0_int[1],q3_int[0],q2_int[0],q1_int[0],q0_int[0]};
end
always @(posedge sclk or negedge reset_n1)  /////2 SCLK ---> 1 DATA
if (~reset_n1)                        /////6 SCLK ---> 1 RGB DATA;
   pix_en_int <= 0;
//else if (ss_n)
//   pix_en_int <= 0;
else if ( rcv_cnt>43 && line_end==0 ) begin      ///ss_n will be high after line_end==1;
   if (rgb_cnt==0 && pix_en_int==0) begin
	   pix_en_int <= 1;      ////////it seems the data is written to the fifo 2 times
	end
   else begin
	   pix_en_int <= 0;
	end
end

always @(posedge sclk or negedge reset_n1)
if (~reset_n1) begin
   q0_int <= 0;
   q1_int <= 0;
   q2_int <= 0;
   q3_int <= 0;
end
else begin
   q0_int <={q0_int[0], q0_in};
   q1_int <={q1_int[0], q1};
   q2_int <={q2_int[0], q2};
   q3_int <={q3_int[0], q3};
end

endmodule