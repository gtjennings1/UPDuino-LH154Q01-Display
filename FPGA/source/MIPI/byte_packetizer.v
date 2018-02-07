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

//`include "simdef.v" 

module BYTE_PACKETIZER #(
     parameter              word_width = 24    ,
     parameter              lane_width = 2     ,
     parameter              dt         = 6'h3E ,
     parameter              crc16      = 1     ,
	 parameter              version    = 1
)(
     input                   reset_n       ,
     input                   PIXCLK        ,
     input                   VSYNC         ,
     input                   HSYNC         ,
     input                   DE            ,
     input [8-1:0]  PIXDATA       ,
     
     //input cmd11,                           
     input [1:0]             VC            ,
     input [15:0]            WC            ,
                  
     input                   byte_clk      ,   
     //input                   system_run,             
     output                  hs_en         ,
     output [7:0]            byte_D3       ,
     output [7:0]            byte_D2       ,
     output [7:0]            byte_D1       ,
     output [7:0]            byte_D0       ,
     
     input                   EoTp   ,
     output ini_done                          
);
reg cmd_11,cmd_36,cmd_2c,cmd_29;
reg q_DE;
reg [1:0] q_VC;
reg [15:0] q_WC;
wire w_edge_detect, crc_en;
wire [7:0] byte_data_dbg, byte_data_ph, crc_data;
wire [31:0] bytepkt;
wire [5:0]  data_type, data_type_ph;
reg [5:0]  data_type1;
wire [15:0] crc;
reg cmd_2a, cmd_2b;
reg q_cmd_2a, q_cmd_2b;
reg ini_done;
parameter n=24;
reg [n-1:0] cntr;

      parallel2byte #(
          .word_width(word_width)        ,
          .lane_width(lane_width)        ,
          .dt(dt)      
      ) u_parallel2byte(
          .reset_n   (reset_n)           ,
          .PIXCLK    (PIXCLK)            ,
          .DE        (DE)                ,
          .PIXDATA   (PIXDATA)           ,           
          //.cmd_29    (0),     
          //.cmd_11    (0),     
          //.cmd_36    (0),     
          .byte_en   (byte_en_dbg)           ,
          .byte_clk  (byte_clk)          ,
          .byte_data (byte_data_dbg)         ,

          .VSYNC      (VSYNC)                 ,
          .HSYNC      (HSYNC)                 ,
          .VSYNC_start(VSYNC_start)           ,
          .VSYNC_end  (VSYNC_end)             ,
          .HSYNC_start(HSYNC_start)           ,
          .HSYNC_end  (HSYNC_end)             ,
          .data_type  (data_type) 
     );
     
//     assign w_edge_detect = (VSYNC_start | HSYNC_start | VSYNC_end | HSYNC_end | ~q_DE&DE);     
     assign w_edge_detect = (cmd_11 | cmd_29 | ~q_DE&DE);// | cmd_2a | cmd_2b); ///add shut down cmd later;
     
reg cmd11_d0,cmd29_d0, cmd2c_d0, cmd36_d0;    
reg cmd11_d1,cmd29_d1, cmd2c_d1, cmd36_d1;   
reg cmd2a_d0,cmd2a_d1; 
reg [15:0] startup_counter;  

    always @(posedge byte_clk or negedge reset_n)
         if(!reset_n) begin
            cmd_11 <= 0;
            cmd_29 <= 0;
            cmd11_d0 <= 0;
            cmd11_d1 <= 0;
            cmd29_d0 <= 0;
            cmd29_d1 <= 0;
            cntr <=24'd0;
         end
         else begin

            cntr <= &cntr ? cntr : cntr+1;
            
            cmd11_d0 <= cntr[n-1:n-9]==8'b00000010;     
            cmd11_d1 <= cmd11_d0;
            cmd_11   <=(cmd11_d0 & ~cmd11_d1);
            
            cmd29_d0 <= cntr[n-1:n-9]==8'b00110010;
            cmd29_d1 <= cmd29_d0;
            cmd_29   <= cmd29_d0 & ~cmd29_d1;//
            `ifdef SIMULATION 
              ini_done <= 1;
            `else
              ini_done <= &cntr[n-1:n-9];
            `endif
         end
        //assign ini_done = &cntr[n-1:n-9];//==8'b00110011;
        
////////////////////////////////////////////////////     
     always @(posedge byte_clk or negedge reset_n)
          if(!reset_n) begin
               q_DE          <= 0;
               q_VC          <= 0;
               q_WC          <= 0;
          end
          else begin
               q_DE          <= DE;
               q_VC          <= w_edge_detect ? VC : q_VC;
               q_WC          <= cmd_11? (16'h0011 ):
                                //cmd_36? (16'h0836 ):
                                cmd_29? (16'h0029 ):
                                //(cmd_2a | cmd_2b)? (16'h0005) : 
                                w_edge_detect ? WC : 
                                q_WC;
          end    

assign data_type_ph = //cmd_36      ? 6'h15 :  
                       (cmd_11 | cmd_29)? 6'h05 : data_type;                 
     packetheader #(
          .lane_width(lane_width)           
      ) u_packetheader
     (
         .reset_n   (reset_n                                           )           ,
         .short_en  (cmd_11 | cmd_29)           ,
         .long_en   (byte_en_dbg),// | q_cmd_2a | q_cmd_2b)           ,
         .byte_clk  (byte_clk                                          )           ,
         .byte_data (byte_data_dbg                                         )           ,
         .crc_en    (crc_en),
         .crc_data  (crc_data),
         .vc        (q_VC                    )           , //VC
         .dt        (data_type_ph               )           , //data_type ///////////////////add DCS CMD PACKETS 
         .wc        (q_WC                    )           , //WC
         .chksum_rdy(1'd0),//chksum_rdy              )           ,
         .chksum    (16'd0),//crc                     )           ,
         .bytepkt_en(hs_en                   )           ,
         .bytepkt   (bytepkt                 )           ,
         .EoTp      (EoTp                    )
     );

     /*generate
          if(crc16 & lane_width==1) begin     
              crc16_1lane u_crc16(
                  .reset  ((~q_DE&DE)|cmd_2a|cmd_2b   )  ,
                  .clk    (byte_clk      )  ,
                  .enable (crc_en       )  ,
                  .data   (crc_data)  ,
                  .ready  (chksum_rdy   )  ,
                  .crc    (crc)        
              );     
          end
          if(crc16 & lane_width==2) begin     
              crc16_2lane u_crc16(
                  .reset  ((~q_DE&DE)   )  ,
                  .clk    (byte_clk      )  ,
                  .enable (byte_en       )  ,
                  .data   (byte_data)  ,
                  .ready  (chksum_rdy   )  ,
                  .crc    (crc)        
              );     
          end
          if(crc16 & lane_width==4) begin     
              crc16_4lane u_crc16(
                  .reset  ((~q_DE&DE)   )  ,
                  .clk    (byte_clk      )  ,
                  .enable (byte_en       )  ,
                  .data   (byte_data)  ,
                  .ready  (chksum_rdy   )  ,
                  .crc    (crc)        
              );     
          end
    endgenerate    */              
                          
    
	assign byte_D3 = bytepkt[31:24];
	assign byte_D2 = bytepkt[23:16];
	assign byte_D1 = bytepkt[15:8];
	assign byte_D0 = bytepkt[7:0];

endmodule