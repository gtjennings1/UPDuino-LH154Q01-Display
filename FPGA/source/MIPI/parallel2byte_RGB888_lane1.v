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

module parallel2byte #(
     parameter              word_width = 24        ,
     parameter              lane_width = 2         ,
     parameter              dt         = 6'h3E     
)(
     input                  reset_n                ,
     input                  PIXCLK                 ,
     input                  DE                     ,
     input [8-1:0] PIXDATA                ,           
     
     output                 byte_en                ,
     input                  byte_clk               ,
     output reg [31:0]      byte_data              ,
     
     input                  VSYNC                  ,
     input                  HSYNC                  ,
     output                 VSYNC_start            ,
     output                 VSYNC_end              ,
     output                 HSYNC_start            ,
     output                 HSYNC_end              ,
     output [5:0]           data_type
);
wire [7:0] data2, data1, data0;
reg [2:0] read_cntr, q_read_cntr, q_read_cntr1;
wire read_en;
wire read_0, read_1, read_2;
reg [4:0] q_byte_en;
reg q_VSYNC, q_HSYNC;
reg qq_VSYNC, qq_HSYNC; /// VSYNC/HSYNC cross pixclk byteclk
reg read_en1;

    //pixel2byte_fifo u_fifo_23_16(.Data(PIXDATA[23:16]), .WrClock(PIXCLK), .RdClock(byte_clk), .WrEn(DE), .RdEn(read_0), .Reset(~reset_n), .RPReset(~reset_n), .Q(data0), .Empty(empty0), .Full( ), .AlmostEmpty( ), .AlmostFull( )); //red
    //pixel2byte_fifo u_fifo_15_8 (.Data(PIXDATA[15:8] ), .WrClock(PIXCLK), .RdClock(byte_clk), .WrEn(DE), .RdEn(read_1), .Reset(~reset_n), .RPReset(~reset_n), .Q(data1), .Empty(empty1), .Full( ), .AlmostEmpty( ), .AlmostFull( )); //green
    //pixel2byte_fifo u_fifo_7_0  (.Data(PIXDATA[7:0]  ), .WrClock(PIXCLK), .RdClock(byte_clk), .WrEn(DE), .RdEn(read_2), .Reset(~reset_n), .RPReset(~reset_n), .Q(data2), .Empty(empty2), .Full( ), .AlmostEmpty( ), .AlmostFull( )); //blue
assign read_en    = DE;//~empty2 & ~empty1 & ~empty0;
         
////updated for 1 lane
assign read_0     = (read_cntr==3'b010) ? 1'b1 : 0;
assign read_1     = (read_cntr==3'b011) ? 1'b1 : 0;
assign read_2     = (read_cntr==3'b100) ? 1'b1 : 0;
always @(posedge byte_clk or negedge reset_n)
    if(!reset_n) begin
         read_cntr  <= 0;
		 read_en1 <= 0;
    end
    else begin 
		read_en1 <= read_en;
         read_cntr  <= (read_en & read_cntr==3'b100) ? 3'b010       :
                       (read_en |    read_en1              ) ? read_cntr+1 : 0;
    end
    
always @(posedge byte_clk or negedge reset_n)
    if(!reset_n) begin    
         byte_data    <= 0;
         q_read_cntr  <= 0;
         q_read_cntr1 <= 0;
    end
    else begin
         byte_data <= PIXDATA[7:0];//(q_read_cntr==2) ? {8'hF0} ://data0} :
                      //(q_read_cntr==3) ? {8'h00} ://data1} :
                      //(q_read_cntr==4) ? {8'h00} ://data2} 
                      //0;
         q_read_cntr  <= read_cntr;
         q_read_cntr1 <= q_read_cntr;
    end
    
always @(posedge byte_clk or negedge reset_n)
    if(!reset_n)
        q_byte_en <= 0;
    else
        q_byte_en <= DE;//{q_byte_en[3:0], read_en};

assign byte_en = q_byte_en[0];//q_byte_en[3];
//Data type and short packet type controller  --> create an independent module for this later 
   
    always @(posedge byte_clk or negedge reset_n)
         if(!reset_n) begin
            q_VSYNC <= 0;
            q_HSYNC <= 0;  
            qq_VSYNC <= 0;
            qq_HSYNC <= 0;  
         end
         else begin
            q_VSYNC <= VSYNC;
            q_HSYNC <= HSYNC; 
            qq_VSYNC <= q_VSYNC;
            qq_HSYNC <= q_HSYNC; 
         end
    assign VSYNC_start =  VSYNC & ~q_VSYNC;  
    assign HSYNC_start =  HSYNC & ~q_HSYNC;
    assign VSYNC_end   = ~VSYNC &  q_VSYNC;
    assign HSYNC_end   = ~HSYNC &  q_HSYNC;
/*
    assign VSYNC_start =  q_VSYNC & ~qq_VSYNC;  
    assign HSYNC_start =  q_HSYNC & ~qq_HSYNC;
    assign VSYNC_end   = ~q_VSYNC &  qq_VSYNC;
    assign HSYNC_end   = ~q_HSYNC &  qq_HSYNC;
*/    
    assign data_type =  VSYNC_start ? 6'h01 :
                        VSYNC_end   ? 6'h11 :
                        HSYNC_start ? 6'h21 :
                        HSYNC_end   ? 6'h31 :   
                       dt;  
////////////////////////////////////////////////////  

endmodule