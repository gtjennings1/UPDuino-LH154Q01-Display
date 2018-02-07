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

`timescale 1ns/100ps

module cfg_ctrl (
  input          reset_n  ,
  input          byte_clk ,
  input          uart_rdy ,
  input  [7:0]   uart_data,
  output         ram_wr   ,
  output [19:0]  ram_addr ,
  output [7:0]   ram_data , 
  output         reset_out
  );
  
  parameter      ROTATION   = 2'b00;  //2'b00 - Normal (0 degree), 2'b01 - 90 degree, 2'b10 - 180 degree, 2'b11 - 270 (-90) degree
  parameter      DISPLAY_NO = 8'h06;  //Change this value from 8'h01 to 8'h06 to generate FPGA bit map for corresponding display on six display demo setup 
  //Register Map
  parameter      CTLSTS_BRG = 8'h00;
  parameter      CTLSTS_REG = 8'h00 | (DISPLAY_NO << 4);
  parameter      COLORR_REG = 8'h01;
  parameter      COLORG_REG = 8'h02;
  parameter      COLORB_REG = 8'h03;
  parameter      PNT1X1_REG = 8'h04;
  parameter      PNT1Y1_REG = 8'h05;
  parameter      PNT2X2_REG = 8'h06;
  parameter      PNT2Y2_REG = 8'h07;
  parameter      PNT3X3_REG = 8'h08;
  parameter      PNT3Y3_REG = 8'h09;
  parameter      RADIUS_REG = 8'h0A;
  parameter      BM_NMR_REG = 8'h0B;
  parameter      FNT_CH_REG = 8'h0C;
  parameter      FNT_SZ_REG = 8'h0D;
  
  //State to differentiate address and data from data received on UART;
  parameter      UART_IDLE = 3'b001;
  parameter      UART_RDY1 = 3'b010;
  parameter      UART_RDY2 = 3'b100;
  
  //State to enable different graphic function
  parameter      GFX_IDLE     = 27'h0000001;
  parameter      GFX_PUTPIXEL = 27'h0000002;
  parameter      GFX_DRAWLINE = 27'h0000004;
  parameter      GFX_LINW_LN1 = 27'h0000008;
  parameter      GFX_DRAWRGLE = 27'h0000010;
  parameter      GFX_RECW_LN1 = 27'h0000020;
  parameter      GFX_RECW_LN2 = 27'h0000040;
  parameter      GFX_RECW_LN3 = 27'h0000080;
  parameter      GFX_RECW_LN4 = 27'h0000100;
  parameter      GFX_DRAWTGLE = 27'h0000200;
  parameter      GFX_TRIW_LN1 = 27'h0000400;
  parameter      GFX_TRIW_LN2 = 27'h0000800;
  parameter      GFX_TRIW_LN3 = 27'h0001000;
  parameter      GFX_DRAWCRCL = 27'h0002000;
  parameter      GFX_CRCL_W   = 27'h0004000;
  parameter      GFX_FILLRGLE = 27'h0008000;
  parameter      GFX_FLRGLE_W = 27'h0010000;
  parameter      GFX_FILLTGLE = 27'h0020000;
  parameter      GFX_FTGLE_W1 = 27'h0040000;
  parameter      GFX_FTGLE_W2 = 27'h0080000;
  parameter      GFX_FILLCRCL = 27'h0100000;
  parameter      GFX_FCRCL_W1 = 27'h0200000;
  parameter      GFX_FCRCL_W2 = 27'h0400000;
  parameter      GFX_DRAWBITM = 27'h0800000;
  parameter      GFX_BITMAP_W = 27'h1000000;
  parameter      GFX_DRAWFONT = 27'h2000000;
  parameter      GFX_FONTCH_W = 27'h4000000;
  
  //Graphics function parameters
  parameter      FUN_PUTPIXEL = 4'b0000;
  parameter      FUN_DRAWLINE = 4'b0001;
  parameter      FUN_DRAWRGLE = 4'b0010;
  parameter      FUN_DRAWTGLE = 4'b0011;
  parameter      FUN_DRAWCRCL = 4'b0100;
  parameter      FUN_FILLRGLE = 4'b0101;
  parameter      FUN_FILLTGLE = 4'b0110;
  parameter      FUN_FILLCRCL = 4'b0111;
  parameter      FUN_DRAWBITM = 4'b1000;
  parameter      FUN_DRAWFONT = 4'b1001;
  
  //Unit delay for simulation
  parameter      UD = 1;
  
  reg    [2:0]   uart_cstate, uart_nstate;
  reg    [7:0]   uart_data_fl;
  
  reg    [7:0]   addr;
  
  reg    [7:0]   ctlsts = 8'h00, colorr, colorg, colorb, pnt1x1, pnt1y1, pnt2x2, pnt2y2, pnt3x3, pnt3y3, radius;
  
  reg    [26:0]  gfx_cstate, gfx_nstate;
  
  reg            drawline_en; 
  reg            drawcrcl_en;
  reg            ftri_en, ftri_find_n;
  reg            fcrc_en, fcrc_find_n;
  reg            drawbtmp_en;
  reg            drawfont_en;
  reg            mem_wr;
  reg    [7:0]   mem_wr_fl;
  reg            ram_wr_reg;
  reg    [7:0]   ram_data_reg;
  reg    [19:0]  ram_addr_reg;
  
  reg    [19:0]  mem_addr;
  
  reg    [3:0]   clk_en_cnt;
  
  reg    [7:0]   x0reg, y0reg, x1reg, y1reg, x2reg, y2reg, radreg, bitmap, charac, charsz;
  
  reg    [7:0]   frec_yk, frec_yl;
  
  reg            ftri_done_lt, ftri_valid_lt;
  reg            fcrc_done_lt, fcrc_valid_lt;
  reg    [1:0]   rotate_disp;
  reg    [7:0]   mem_x, mem_y;
  
  wire           clk = byte_clk;
  
  wire           uart_addr_wr = (uart_cstate == UART_RDY1);
  wire           uart_data_wr = (uart_cstate == UART_RDY2);
  wire           start = ctlsts[7];
  wire           sw_reset = ctlsts[5];
  wire           ready = (gfx_cstate == GFX_IDLE);
  
  wire   [7:0]   line_x, line_y;
  wire           line_done, line_wr;
  wire   [7:0]   crcl_x, crcl_y;  
  wire           crcl_done, crcl_wr;
  wire           ftri_valid, ftri_done;
  wire   [7:0]   ftri_x0, ftri_x1, ftri_yx;
  wire   [7:0]   btmp_x, btmp_y;
  wire           btmp_done, btmp_wr;
  wire   [7:0]   font_x, font_y;
  wire           font_done, font_wr;

  wire           fcrc_valid, fcrc_done;
  wire   [7:0]   fcrc_x0, fcrc_x1, fcrc_yx;  
  
  wire           clk_en = (clk_en_cnt == 4'h3);
  wire           gfx_en = drawline_en || drawcrcl_en || drawbtmp_en || drawfont_en;
  
  wire           rect_filled = (frec_yk == frec_yl);
  
  wire           y2_gt_y1 = (pnt2y2 > pnt1y1);
  
  wire           ftri_done_comb = (ftri_done_lt || ftri_done);
  wire           ftri_valid_comb = (ftri_valid_lt || ftri_valid);
  
  wire           fcrc_done_comb = (fcrc_done_lt || fcrc_done);
  wire           fcrc_valid_comb = (fcrc_valid_lt || fcrc_valid);
  
  wire           int_reset_n = reset_n;// && (!sw_reset);
  
  assign         ram_wr   = ram_wr_reg;
  assign         ram_data = ram_data_reg;
  assign         ram_addr = ram_addr_reg;
  assign         reset_out = sw_reset;
  
  //State machine to manage state of data received on UART
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        uart_cstate <= #UD UART_IDLE;
      else
        uart_cstate <= #UD uart_nstate;      
    end
  
  always @ (uart_cstate or uart_rdy)
    begin
      case (uart_cstate)
        UART_IDLE : begin
                      if (uart_rdy)
                        uart_nstate <= #UD UART_RDY1;
                      else
                        uart_nstate <= #UD UART_IDLE;                      
                    end
        UART_RDY1 : begin
                      if (uart_rdy)
                        uart_nstate <= #UD UART_RDY2;
                      else
                        uart_nstate <= #UD UART_RDY1;                      
                    end
        UART_RDY2 : begin
                      uart_nstate <= #UD UART_IDLE;
                    end
        default   : begin
                      uart_nstate <= #UD UART_IDLE;
                    end        
      endcase
    end
  
  //Register data received on UART to sync. up with state machine
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        uart_data_fl <= #UD 8'h00;
      else
      if (uart_rdy)
        uart_data_fl <= #UD uart_data;
      else
        uart_data_fl <= #UD uart_data_fl;      
    end
    
  //Store address receved on UART
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        addr <= #UD 8'h00;
      else
      if (uart_addr_wr)
        addr <= #UD uart_data_fl;
      else
        addr <= #UD addr;      
    end
  
  //Write registers
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          ctlsts <= #UD 8'h00; 
          colorr <= #UD 8'h00; 
          colorg <= #UD 8'h00; 
          colorb <= #UD 8'h00; 
          pnt1x1 <= #UD 8'h00; 
          pnt1y1 <= #UD 8'h00; 
          pnt2x2 <= #UD 8'h00;
          pnt2y2 <= #UD 8'h00; 
          pnt3x3 <= #UD 8'h00; 
          pnt3y3 <= #UD 8'h00; 
          radius <= #UD 8'h00;
          bitmap <= #UD 8'h00;
          charac <= #UD 8'h00;
          charsz <= #UD 8'h00;
        end
      else
      if (uart_data_wr)
        begin
          ctlsts <= #UD ctlsts; 
          colorr <= #UD colorr; 
          colorg <= #UD colorg; 
          colorb <= #UD colorb; 
          pnt1x1 <= #UD pnt1x1; 
          pnt1y1 <= #UD pnt1y1; 
          pnt2x2 <= #UD pnt2x2;
          pnt2y2 <= #UD pnt2y2; 
          pnt3x3 <= #UD pnt3x3; 
          pnt3y3 <= #UD pnt3y3; 
          radius <= #UD radius;
          bitmap <= #UD bitmap;
          charac <= #UD charac;
          charsz <= #UD charsz;          
          case(addr)
            CTLSTS_BRG  : ctlsts <= #UD uart_data_fl;
            CTLSTS_REG  : ctlsts <= #UD uart_data_fl;
            COLORR_REG  : colorr <= #UD uart_data_fl;
            COLORG_REG  : colorg <= #UD uart_data_fl;
            COLORB_REG  : colorb <= #UD uart_data_fl;
            PNT1X1_REG  : pnt1x1 <= #UD uart_data_fl;
            PNT1Y1_REG  : pnt1y1 <= #UD uart_data_fl;
            PNT2X2_REG  : pnt2x2 <= #UD uart_data_fl;
            PNT2Y2_REG  : pnt2y2 <= #UD uart_data_fl;
            PNT3X3_REG  : pnt3x3 <= #UD uart_data_fl;
            PNT3Y3_REG  : pnt3y3 <= #UD uart_data_fl;
            RADIUS_REG  : radius <= #UD uart_data_fl;
            BM_NMR_REG  : bitmap <= #UD uart_data_fl;
            FNT_CH_REG  : charac <= #UD uart_data_fl;
            FNT_SZ_REG  : charsz <= #UD uart_data_fl;
            default     : ;
          endcase
        end
      else
        begin
          ctlsts <= #UD {1'b0, ready, 1'b0, ctlsts[4:0]}; 
          colorr <= #UD colorr; 
          colorg <= #UD colorg; 
          colorb <= #UD colorb; 
          pnt1x1 <= #UD pnt1x1; 
          pnt1y1 <= #UD pnt1y1; 
          pnt2x2 <= #UD pnt2x2;
          pnt2y2 <= #UD pnt2y2; 
          pnt3x3 <= #UD pnt3x3; 
          pnt3y3 <= #UD pnt3y3; 
          radius <= #UD radius;
          bitmap <= #UD bitmap;
          charac <= #UD charac;
          charsz <= #UD charsz;
        end        
    end 

  //State machine to enable graphics function
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        gfx_cstate <= #UD GFX_IDLE;
      else
        gfx_cstate <= #UD gfx_nstate;      
    end
  
  always @ (gfx_cstate or start or line_done or crcl_done or rect_filled or fcrc_done_comb 
            or fcrc_valid_comb or ftri_done_comb or ftri_valid_comb or btmp_done or font_done)
    begin
      case (gfx_cstate)
        GFX_IDLE      : begin
                          if (start)
                             case(ctlsts[3:0])
                               FUN_PUTPIXEL : gfx_nstate <= #UD GFX_PUTPIXEL;
                               FUN_DRAWLINE : gfx_nstate <= #UD GFX_DRAWLINE;
                               FUN_DRAWRGLE : gfx_nstate <= #UD GFX_DRAWRGLE;
                               FUN_DRAWTGLE : gfx_nstate <= #UD GFX_DRAWTGLE;
                               FUN_DRAWCRCL : gfx_nstate <= #UD GFX_DRAWCRCL;
                               FUN_FILLRGLE : gfx_nstate <= #UD GFX_FILLRGLE;
                               FUN_FILLTGLE : gfx_nstate <= #UD GFX_FILLTGLE;
                               FUN_FILLCRCL : gfx_nstate <= #UD GFX_FILLCRCL;
                               FUN_DRAWBITM : gfx_nstate <= #UD GFX_DRAWBITM;
                               FUN_DRAWFONT : gfx_nstate <= #UD GFX_DRAWFONT;
                               default      : gfx_nstate <= #UD GFX_IDLE;
                             endcase
                          else
                            gfx_nstate <= #UD GFX_IDLE;                      
                        end
        GFX_PUTPIXEL  : begin
                          gfx_nstate <= #UD GFX_IDLE;
                        end
        GFX_DRAWLINE  : begin
                          gfx_nstate <= #UD GFX_LINW_LN1;
                        end
        GFX_LINW_LN1  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_LINW_LN1;                          
                        end
        GFX_DRAWRGLE  : begin
                          gfx_nstate <= #UD GFX_RECW_LN1;
                        end                        
        GFX_RECW_LN1  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_RECW_LN2;
                          else
                            gfx_nstate <= #UD GFX_RECW_LN1;                          
                        end
        GFX_RECW_LN2  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_RECW_LN3;
                          else
                            gfx_nstate <= #UD GFX_RECW_LN2;                          
                        end
        GFX_RECW_LN3  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_RECW_LN4;
                          else
                            gfx_nstate <= #UD GFX_RECW_LN3;                          
                        end
        GFX_RECW_LN4  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_RECW_LN4;                          
                        end                        
        GFX_DRAWTGLE  : begin
                          gfx_nstate <= #UD GFX_TRIW_LN1;
                        end
        GFX_TRIW_LN1  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_TRIW_LN2;
                          else
                            gfx_nstate <= #UD GFX_TRIW_LN1;                          
                        end
        GFX_TRIW_LN2  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_TRIW_LN3;
                          else
                            gfx_nstate <= #UD GFX_TRIW_LN2;                          
                        end
        GFX_TRIW_LN3  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_TRIW_LN3;                          
                        end  
        GFX_DRAWCRCL  : begin
                          gfx_nstate <= #UD GFX_CRCL_W;
                        end        
        GFX_CRCL_W    : begin
                          if (crcl_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_CRCL_W;                          
                        end
        GFX_FILLRGLE  : begin
                          gfx_nstate <= #UD GFX_FLRGLE_W;
                        end
        GFX_FLRGLE_W  : begin
                          if (line_done && rect_filled)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_FLRGLE_W;                          
                        end                        
        GFX_FILLTGLE  : begin
                          gfx_nstate <= #UD GFX_FTGLE_W1;
                        end
        GFX_FTGLE_W1  : begin
                          if (ftri_done_comb)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                          if (ftri_valid_comb)
                            gfx_nstate <= #UD GFX_FTGLE_W2;
                          else
                            gfx_nstate <= #UD GFX_FTGLE_W1;                          
                        end
        GFX_FTGLE_W2  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_FTGLE_W1;
                          else
                            gfx_nstate <= #UD GFX_FTGLE_W2;                          
                        end
        GFX_FILLCRCL  : begin
                          gfx_nstate <= #UD GFX_FCRCL_W1;
                        end
        GFX_FCRCL_W1  : begin
                          if (fcrc_done_comb)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                          if (fcrc_valid_comb)
                            gfx_nstate <= #UD GFX_FCRCL_W2;
                          else
                            gfx_nstate <= #UD GFX_FCRCL_W1;                          
                        end 
        GFX_FCRCL_W2  : begin
                          if (line_done)
                            gfx_nstate <= #UD GFX_FCRCL_W1;
                          else
                            gfx_nstate <= #UD GFX_FCRCL_W2;                          
                        end 
        GFX_DRAWBITM  : begin
                          gfx_nstate <= #UD GFX_BITMAP_W;
                        end
        GFX_BITMAP_W  : begin
                          if (btmp_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_BITMAP_W;                          
                        end                        
        GFX_DRAWFONT  : begin
                          gfx_nstate <= #UD GFX_FONTCH_W;
                        end
        GFX_FONTCH_W  : begin
                          if (font_done)
                            gfx_nstate <= #UD GFX_IDLE;
                          else
                            gfx_nstate <= #UD GFX_FONTCH_W;                          
                        end        
        default       : begin
                          gfx_nstate <= #UD GFX_IDLE;
                        end                        
      endcase
    end
  
  
  //Generate enable signal and co-ordinate for graphics functions
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          drawline_en <= #UD 1'b0;
          drawcrcl_en <= #UD 1'b0;
          drawbtmp_en <= #UD 1'b0;
          drawfont_en <= #UD 1'b0;
          x0reg <= #UD 8'h00;
          y0reg <= #UD 8'h00;
          x1reg <= #UD 8'h00;
          y1reg <= #UD 8'h00;
          x2reg <= #UD 8'h00;
          y2reg <= #UD 8'h00;
          radreg <= #UD 8'h00;
          frec_yk <= #UD 8'h00;
          frec_yl <= #UD 8'h00;
          ftri_en <= #UD 1'b0;
          ftri_find_n <= #UD 1'b0;
          fcrc_en <= #UD 1'b0;
          fcrc_find_n <= #UD 1'b0;          
        end
      else
        begin
          x0reg <= #UD x0reg;
          y0reg <= #UD y0reg;
          x1reg <= #UD x1reg;
          y1reg <= #UD y1reg;
          x2reg <= #UD x2reg;
          y2reg <= #UD y2reg;
          radreg <= #UD radreg;
          frec_yk <= #UD frec_yk;
          frec_yl <= #UD frec_yl;
          drawline_en <= #UD 1'b0; 
          drawcrcl_en <= #UD 1'b0;
          drawbtmp_en <= #UD 1'b0;
          drawfont_en <= #UD 1'b0;
          ftri_en <= #UD 1'b0;
          ftri_find_n <= #UD 1'b0;
          fcrc_en <= #UD 1'b0;
          fcrc_find_n <= #UD 1'b0;          
          case (gfx_cstate)
/*
            GFX_IDLE      : begin
                            end
            GFX_PUTPIXEL  : begin
                            end
*/  
            GFX_DRAWLINE  : begin
                              drawline_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;
                              x1reg <= #UD pnt2x2;
                              y1reg <= #UD pnt2y2;
                            end
/*                            
            GFX_LINW_LN1  : begin
                            end
*/                            
            GFX_DRAWRGLE  : begin
                              drawline_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;
                              x1reg <= #UD pnt2x2;
                              y1reg <= #UD pnt1y1;                              
                            end
            GFX_RECW_LN1  : begin
                              if (line_done)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD pnt1x1;
                                  y0reg <= #UD pnt1y1;
                                  x1reg <= #UD pnt1x1;
                                  y1reg <= #UD pnt2y2;                                  
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg;                                  
                                end                                
                            end
            GFX_RECW_LN2  : begin
                              if (line_done)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD pnt1x1;
                                  y0reg <= #UD pnt2y2;
                                  x1reg <= #UD pnt2x2;
                                  y1reg <= #UD pnt2y2;                                  
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg;                                   
                                end                                
                            end
            GFX_RECW_LN3  : begin
                              if (line_done)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD pnt2x2;
                                  y0reg <= #UD pnt1y1;
                                  x1reg <= #UD pnt2x2;
                                  y1reg <= #UD pnt2y2;                                  
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg;                                  
                                end
                            end
/*                            
            GFX_RECW_LN4  : begin
                            end
*/                            
            GFX_DRAWTGLE  : begin
                              drawline_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;
                              x1reg <= #UD pnt2x2;
                              y1reg <= #UD pnt2y2;                              
                            end
            GFX_TRIW_LN1  : begin
                              if (line_done)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD pnt2x2;
                                  y0reg <= #UD pnt2y2;
                                  x1reg <= #UD pnt3x3;
                                  y1reg <= #UD pnt3y3;                                  
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg;                                  
                                end
                            end
            GFX_TRIW_LN2  : begin
                              if (line_done)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD pnt1x1;
                                  y0reg <= #UD pnt1y1;
                                  x1reg <= #UD pnt3x3;
                                  y1reg <= #UD pnt3y3;                                  
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg;                                  
                                end
                            end
/*                            
            GFX_TRIW_LN3  : begin
                            end
*/                            
            GFX_DRAWCRCL  : begin
                              drawcrcl_en <= #UD 1'b1;
                              x0reg  <= #UD pnt1x1;
                              y0reg  <= #UD pnt1y1; 
                              radreg <= #UD radius;                              
                            end
/*          
            GFX_CRCL_W    : begin
                            end
*/                            
            GFX_FILLRGLE  : begin
                              drawline_en <= #UD 1'b1;
                              if (y2_gt_y1)
                                begin
                                  y0reg <= #UD pnt1y1;
                                  y1reg <= #UD pnt1y1;
                                  frec_yk <= #UD pnt1y1 + 8'h01;
                                  frec_yl <= #UD pnt2y2 + 8'h01;                                  
                                end
                              else
                                begin
                                  y0reg <= #UD pnt2y2;
                                  y1reg <= #UD pnt2y2;
                                  frec_yk <= #UD pnt2y2 + 8'h01;
                                  frec_yl <= #UD pnt1y1 + 8'h01;                                
                                end                                
                              x0reg <= #UD pnt1x1;
                              x1reg <= #UD pnt2x2;
                            end
            GFX_FLRGLE_W  : begin
                              if (line_done && (!rect_filled))
                                begin
                                  drawline_en <= #UD 1'b1;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD frec_yk;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD frec_yk;
                                  frec_yk <= #UD frec_yk + 8'h01;                                   
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  x0reg <= #UD x0reg;
                                  y0reg <= #UD y0reg;
                                  x1reg <= #UD x1reg;
                                  y1reg <= #UD y1reg; 
                                  frec_yk <= #UD frec_yk;                                  
                                end
                            end   
                            
            GFX_FILLTGLE  : begin
                              ftri_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;
                              x1reg <= #UD pnt2x2;
                              y1reg <= #UD pnt2y2;
                              x2reg <= #UD pnt3x3;
                              y2reg <= #UD pnt3y3;                              
                            end
            GFX_FTGLE_W1  : begin
                              if (ftri_valid_comb)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  ftri_find_n <= #UD 1'b1;
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  ftri_find_n <= #UD 1'b0;                                  
                                end                                
                              x0reg <= #UD ftri_x0;
                              y0reg <= #UD ftri_yx;
                              x1reg <= #UD ftri_x1;
                              y1reg <= #UD ftri_yx;            
                            end
            GFX_FILLCRCL  : begin
                              fcrc_en <= #UD 1'b1;
                              x0reg  <= #UD pnt1x1;
                              y0reg  <= #UD pnt1y1; 
                              radreg <= #UD radius;                                                            
                            end
            GFX_FCRCL_W1  : begin
                              if (fcrc_valid_comb)
                                begin
                                  drawline_en <= #UD 1'b1;
                                  fcrc_find_n <= #UD 1'b1;
                                end
                              else
                                begin
                                  drawline_en <= #UD 1'b0;
                                  fcrc_find_n <= #UD 1'b0;                                  
                                end                                
                              x0reg <= #UD fcrc_x0;
                              y0reg <= #UD fcrc_yx;                              
                              x1reg <= #UD fcrc_x1;
                              y1reg <= #UD fcrc_yx; 
                            end
            GFX_DRAWBITM  : begin
                              drawbtmp_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;            
                            end
            GFX_DRAWFONT  : begin
                              drawfont_en <= #UD 1'b1;
                              x0reg <= #UD pnt1x1;
                              y0reg <= #UD pnt1y1;                              
                            end            
            default       : begin
                              drawline_en <= #UD 1'b0;
                              drawcrcl_en <= #UD 1'b0; 
                              drawbtmp_en <= #UD 1'b0;                              
                            end
          endcase
        end        
    end
  
  //Generate clk_en signal to slow down graphics function to match write bandwidth available
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        clk_en_cnt <= #UD 4'h0;
      else
      if (gfx_en)
        clk_en_cnt <= #UD 4'h0;
      else
      if (clk_en)
        clk_en_cnt <= #UD 4'h0;
      else
        clk_en_cnt <= #UD clk_en_cnt + 4'h1;      
    end   
  
  //Latch ftri_done and ftri_valid when FSM is waiting for line_done;
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          ftri_done_lt  <= #UD 1'b0;
          ftri_valid_lt <= #UD 1'b0;
        end
      else
      if (gfx_cstate == GFX_FTGLE_W1) 
        begin
          ftri_done_lt  <= #UD 1'b0;
          ftri_valid_lt <= #UD 1'b0;        
        end
      else
        begin
          ftri_done_lt  <= #UD ftri_done_comb;
          ftri_valid_lt <= #UD ftri_valid_comb;        
        end        
    end

  //Latch fcrc_done and fcrc_valid when FSM is waiting for line_done;
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          fcrc_done_lt  <= #UD 1'b0;
          fcrc_valid_lt <= #UD 1'b0;
        end
      else
      if (gfx_cstate == GFX_FCRCL_W1) 
        begin
          fcrc_done_lt  <= #UD 1'b0;
          fcrc_valid_lt <= #UD 1'b0;        
        end
      else
        begin
          fcrc_done_lt  <= #UD fcrc_done_comb;
          fcrc_valid_lt <= #UD fcrc_valid_comb;        
        end        
    end    
    
  //Instance of drawline accelerator
  drawline #(
    
    .DATA_WIDTH ( 8         ) //Parameter for datawidth includes co-ordinates, color, memory data
    
    ) drawline (
    
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input
    .clk_en   ( clk_en      ), //Clock enable to slow down output data    
    .enable   ( drawline_en ), //Trigger to start the function    
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .x1       ( x1reg       ), //Co-ordinate x1
    .y1       ( y1reg       ), //Co-ordinate y1
    .valid    ( line_wr     ), //Output data valid
    .done     ( line_done   ), //Feedback of task completion  
    .x_o      ( line_x      ), //x co-ordinate output
    .y_o      ( line_y      )  //y co-ordinate output
  );
  
  //Instance of drawcircle accelerator  
  drawcircle #(
  
    .DATA_WIDTH ( 8          ) //Parameter for datawidth includes co-ordinates,
  
    ) drawcircle (
  
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input
    .clk_en   ( clk_en      ), //Clock enable to slow down output data
    .enable   ( drawcrcl_en ), //Trigger to start the function  
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .rad      ( radreg      ), //Circle radius
    .valid    ( crcl_wr     ), //Output data valid
    .done     ( crcl_done   ), //Feedback of task completion  
    .x_o      ( crcl_x      ), //X co-ordinate output
    .y_o      ( crcl_y      )  //Y co-ordinate output
  );    

  filltriangle #(
  
    .DATA_WIDTH ( 8          ) //Parameter for datawidth includes co-ordinates
  
  ) filltriangle (
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input
//  .clk_en   ( clk_en      ), //Clock enable to slow down output data    
    .enable   ( ftri_en     ), //Trigger to start the function    
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .x1       ( x1reg       ), //Co-ordinate x1
    .y1       ( y1reg       ), //Co-ordinate y1
    .x2       ( x2reg       ), //Co-ordinate x2
    .y2       ( y2reg       ), //Co-ordinate y2      
    .find_next( ftri_find_n ), //Trigger to find next x values to draw a line    
    .valid    ( ftri_valid  ), //Output data valid
    .done     ( ftri_done   ), //Feedback of task completion    
    .x0_o     ( ftri_x0     ), //x0 co-ordinate output
    .x1_o     ( ftri_x1     ), //x1 co-ordinate output  
    .yx_o     ( ftri_yx     )  //y co-ordinate output  
  );

  fillcircle #(
  
    .DATA_WIDTH ( 8          ) //Parameter for datawidth includes co-ordinates
  
  ) fillcircle (
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input   
    .enable   ( fcrc_en     ), //Trigger to start the function    
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .rad      ( radreg      ), //Circle radius     
    .find_next( fcrc_find_n ), //Trigger to find next x values to draw a line    
    .valid    ( fcrc_valid  ), //Output data valid
    .done     ( fcrc_done   ), //Feedback of task completion    
    .x0_o     ( fcrc_x0     ), //x0 co-ordinate output
    .x1_o     ( fcrc_x1     ), //x1 co-ordinate output  
    .yx_o     ( fcrc_yx     )  //y co-ordinate output  
  );

  drawbitmap #(
    
    .DATA_WIDTH ( 8 )          //Parameter for datawidth includes co-ordinates
    
  ) drawbitmap (    
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input
    .clk_en   ( clk_en      ), //Clock enable to slow down output data    
    .enable   ( drawbtmp_en ), //Trigger to start the function    
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .bm_no    ( bitmap      ), //Bitmap number
    .valid    ( btmp_wr     ), //Output data valid
    .done     ( btmp_done   ), //Feedback of task completion  
    .x_o      ( btmp_x      ), //X co-ordinate output
    .y_o      ( btmp_y      )  //Y co-ordinate output  
  );  

  drawfont #(
    
    .DATA_WIDTH  ( 8 )          //Parameter for datawidth includes co-ordinates
    
  ) drawfont (
    
    .clk      ( clk         ), //Clock input
    .reset_n  ( int_reset_n ), //Active low reset input
    .clk_en   ( clk_en      ), //Clock enable to slow down output data    
    .enable   ( drawfont_en ), //Trigger to start the function    
    .x0       ( x0reg       ), //Co-ordinate x0
    .y0       ( y0reg       ), //Co-ordinate y0
    .char     ( charac      ), //Character ASCII code
    .size     ( charsz      ), //Character size
    .valid    ( font_wr     ), //Output data valid
    .done     ( font_done   ), //Feedback of task completion  
    .x_o      ( font_x      ), //X co-ordinate output
    .y_o      ( font_y      )  //Y co-ordinate output  
  );  
  
  //rotate_disp parameter latch
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        rotate_disp <= ROTATION;
      //if (reset_out)
      //  rotate_disp <= ctlsts[4:3];
      else
        rotate_disp <= rotate_disp;      
    end
  
  //Pass co-ordinate to generate memory address
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin          
          //mem_addr <= #UD 20'h00000;
          mem_x    <= #UD 8'h00;
          mem_y    <= #UD 8'h00;          
          mem_wr   <= #UD 1'b0;
        end
      else
        begin
          case (gfx_cstate)
            GFX_PUTPIXEL  : begin
                              case (rotate_disp)
                                2'b00   : begin
                                            mem_x <= #UD pnt1x1;
                                            mem_y <= #UD pnt1y1;
                                          end                                        
                                2'b01   : begin
                                            mem_x <= #UD 8'd239 - pnt1y1;
                                            mem_y <= #UD pnt1x1;
                                          end                                          
                                2'b10   : begin
                                            mem_x <= #UD 8'd239 - pnt1x1;
                                            mem_y <= #UD 8'd239 - pnt1y1;
                                          end                                          
                                2'b11   : begin
                                            mem_x <= #UD pnt1y1;
                                            mem_y <= #UD 8'd239 - pnt1x1;
                                          end
                                default : begin
                                            mem_x <= #UD mem_x;
                                            mem_y <= #UD mem_y;
                                          end
                              endcase
                              mem_wr   <= #UD 1'b1;            
                            end
            GFX_LINW_LN1,
            GFX_RECW_LN1,
            GFX_RECW_LN2,
            GFX_RECW_LN3,
            GFX_RECW_LN4,
            GFX_TRIW_LN1,
            GFX_TRIW_LN2,
            GFX_TRIW_LN3,
            GFX_FLRGLE_W,
            GFX_FTGLE_W2,
            GFX_FCRCL_W2  : begin
                              case (rotate_disp)
                                2'b00   : begin
                                            mem_x <= #UD line_x;
                                            mem_y <= #UD line_y;
                                          end                                        
                                2'b01   : begin
                                            mem_x <= #UD 8'd239 - line_y;
                                            mem_y <= #UD line_x;
                                          end                                          
                                2'b10   : begin
                                            mem_x <= #UD 8'd239 - line_x;
                                            mem_y <= #UD 8'd239 - line_y;
                                          end                                          
                                2'b11   : begin
                                            mem_x <= #UD line_y;
                                            mem_y <= #UD 8'd239 - line_x;
                                          end
                                default : begin
                                            mem_x <= #UD mem_x;
                                            mem_y <= #UD mem_y;
                                          end
                              endcase                              
                              mem_wr   <= #UD line_wr;
                            end         
            GFX_CRCL_W    : begin
                              case (rotate_disp)
                                2'b00   : begin
                                            mem_x <= #UD crcl_x;
                                            mem_y <= #UD crcl_y;
                                          end                                        
                                2'b01   : begin
                                            mem_x <= #UD 8'd239 - crcl_y;
                                            mem_y <= #UD crcl_x;
                                          end                                          
                                2'b10   : begin
                                            mem_x <= #UD 8'd239 - crcl_x;
                                            mem_y <= #UD 8'd239 - crcl_y;
                                          end                                          
                                2'b11   : begin
                                            mem_x <= #UD crcl_y;
                                            mem_y <= #UD 8'd239 - crcl_x;
                                          end
                                default : begin
                                            mem_x <= #UD mem_x;
                                            mem_y <= #UD mem_y;
                                          end
                              endcase                                        
                              mem_wr   <= #UD crcl_wr;
                            end
            GFX_BITMAP_W  : begin
                              case (rotate_disp)
                                2'b00   : begin
                                            mem_x <= #UD btmp_x;
                                            mem_y <= #UD btmp_y;
                                          end                                        
                                2'b01   : begin
                                            mem_x <= #UD 8'd239 - btmp_y;
                                            mem_y <= #UD btmp_x;
                                          end                                          
                                2'b10   : begin
                                            mem_x <= #UD 8'd239 - btmp_x;
                                            mem_y <= #UD 8'd239 - btmp_y;
                                          end                                          
                                2'b11   : begin
                                            mem_x <= #UD btmp_y;
                                            mem_y <= #UD 8'd239 - btmp_x;
                                          end
                                default : begin
                                            mem_x <= #UD mem_x;
                                            mem_y <= #UD mem_y;
                                          end
                              endcase                                        
                              mem_wr   <= #UD btmp_wr;
                            end
            GFX_FONTCH_W  : begin
                              case (rotate_disp)
                                2'b00   : begin
                                            mem_x <= #UD font_x;
                                            mem_y <= #UD font_y;
                                          end                                        
                                2'b01   : begin
                                            mem_x <= #UD 8'd239 - font_y;
                                            mem_y <= #UD font_x;
                                          end                                          
                                2'b10   : begin
                                            mem_x <= #UD 8'd239 - font_x;
                                            mem_y <= #UD 8'd239 - font_y;
                                          end                                          
                                2'b11   : begin
                                            mem_x <= #UD font_y;
                                            mem_y <= #UD 8'd239 - font_x;
                                          end
                                default : begin
                                            mem_x <= #UD mem_x;
                                            mem_y <= #UD mem_y;
                                          end
                              endcase                                        
                              mem_wr   <= #UD font_wr;
                            end                              
            default       : begin
                              mem_x <= #UD mem_x;
                              mem_y <= #UD mem_y;                              
                              mem_wr <= #UD 1'b0;            
                            end
          endcase
        end
    end    
  
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        mem_addr <= #UD 20'h00000;
      else
      if (mem_wr)
        mem_addr <= #UD (mem_y * 720) + (mem_x * 3);
      else
        mem_addr <= #UD mem_addr;      
    end    
    
  //Flop mem_wr two times to write color G and B in memory
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          mem_wr_fl <= #UD 8'h00;
        end
      else
        begin
          mem_wr_fl <= #UD {mem_wr_fl[6:0], mem_wr};
        end        
    end    
  
  //Generate address, data, and wr signal for DPRAM
  always @ (posedge clk or negedge int_reset_n)
    begin
      if (!int_reset_n)
        begin
          ram_wr_reg   <= #UD 1'b0;
          ram_data_reg <= #UD 8'h0;
          ram_addr_reg <= #UD 20'h00000;
        end
      else
        begin
          case (mem_wr_fl[2:0])
            3'b001  : begin
                        ram_wr_reg   <= #UD 1'b1;
                        ram_data_reg <= #UD {colorr[7:4], 4'h0};
                        ram_addr_reg <= #UD mem_addr;
                      end
            3'b010  : begin
                        ram_wr_reg   <= #UD 1'b1;
                        ram_data_reg <= #UD {colorg[7:4], 4'h0};
                        ram_addr_reg <= #UD mem_addr + 1;            
                      end
            3'b100  : begin
                        ram_wr_reg   <= #UD 1'b1;
                        ram_data_reg <= #UD {colorb[7:4], 4'h0};
                        ram_addr_reg <= #UD mem_addr + 2;            
                      end
            default : begin
                        ram_wr_reg   <= #UD 1'b0;
                        ram_data_reg <= #UD ram_data_reg;
                        ram_addr_reg <= #UD ram_addr_reg;            
                      end
          endcase
        end        
    end
    
    
endmodule  