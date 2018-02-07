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

module filltriangle #(
  
  parameter DATA_WIDTH  = 8           //Parameter for datawidth includes co-ordinates
  
  ) (
  input                   clk       , //Clock input
  input                   reset_n   , //Active low reset input
  
  input                   enable    , //Trigger to start the function
  
  input  [DATA_WIDTH-1:0] x0        , //Co-ordinate x0
  input  [DATA_WIDTH-1:0] y0        , //Co-ordinate y0
  input  [DATA_WIDTH-1:0] x1        , //Co-ordinate x1
  input  [DATA_WIDTH-1:0] y1        , //Co-ordinate y1
  input  [DATA_WIDTH-1:0] x2        , //Co-ordinate x2
  input  [DATA_WIDTH-1:0] y2        , //Co-ordinate y2  
  
  input                   find_next , //Trigger to find next x values to draw a line
  
  output                  valid     , //Output data valid
  output                  done      , //Feedback of task completion
  
  output [DATA_WIDTH-1:0] x0_o      , //x0 co-ordinate output
  output [DATA_WIDTH-1:0] x1_o      , //x1 co-ordinate output  
  output [DATA_WIDTH-1:0] yx_o        //y co-ordinate output  
  );
  
  parameter UD = 1;  
  parameter FSM_WIDTH = 7;
  parameter IDLE  = 7'h01;
  parameter PREP1 = 7'h02;
  parameter WAITF = 7'h04;
  parameter DRAW1 = 7'h08;
  parameter PREP2 = 7'h10;
  parameter DRAW2 = 7'h20;
  parameter DONE  = 7'h40;  
  
  reg    [FSM_WIDTH-1:0]  current_state, next_state;
  reg    [DATA_WIDTH-1:0] x0r, y0r, x1r, y1r, x2r, y2r;
  reg    [DATA_WIDTH-1:0] x0k, x1k, y0k, y1k, y0kp, y1kp;
  reg    [DATA_WIDTH-1:0] delta_x0, delta_y0, delta_x1, delta_y1, delta_x2, delta_y2;
  reg                     delta_x0_neg, delta_x1_neg, delta_x2_neg;
  reg    [DATA_WIDTH:0]   error0, error1;
  reg                     valid_reg, done_reg;
  reg                     next_yx_valid_fl;
  
  wire                    y0_gt_y1 = (y0 > y1);
  wire                    y1_gt_y2 = (y1 > y2);
  wire                    y0_gt_y2 = (y0 > y2);
  wire                    x0_gt_x1 = (x0 > x1);
  wire                    x1_gt_x2 = (x1 > x2);
  wire                    x0_gt_x2 = (x0 > x2);
  wire                    top_y_eq = (y0r == y1r);
  wire                    draw1_done = (y0kp == y1r) && (y1kp == y1r);
  wire                    draw2_done = (y0kp == y2r) && (y1kp == y2r);
  
  wire                    dx0_gt_eq_dy0 = (delta_x0[DATA_WIDTH-1:1] >= delta_y0[DATA_WIDTH-1:1]);
  wire                    dx1_gt_eq_dy1 = (delta_x1[DATA_WIDTH-1:1] >= delta_y1[DATA_WIDTH-1:1]);
  wire                    dx2_gt_eq_dy2 = (delta_x2[DATA_WIDTH-1:1] >= delta_y2[DATA_WIDTH-1:1]);
  wire                    y0k_eq_y0kp = (y0k == y0kp);
  wire                    y1k_eq_y1kp = (y1k == y1kp);
  
  wire                    next_yx_valid = (!y0k_eq_y0kp) && (!y1k_eq_y1kp);
  wire                    next_yx_valid_pe = next_yx_valid && (!next_yx_valid_fl);
  
  wire                    draw_part1 = ((current_state == PREP1) || (current_state == DRAW1));
  wire                    delta_x01_neg = draw_part1 ? delta_x0_neg : delta_x1_neg;
  
  wire                    error0_pos = !error0[DATA_WIDTH];
  wire                    error0_nz  = |error0;
  wire                    error0_check_xm = (error0_pos && (error0_nz || (!delta_x01_neg))); 
  wire                    error0_check_ym = (error0_pos && error0_nz);

  wire                    error1_pos = !error1[DATA_WIDTH];
  wire                    error1_nz  = |error1;
  wire                    error1_check_xm = (error1_pos && (error1_nz || (!delta_x2_neg))); 
  wire                    error1_check_ym = (error1_pos && error1_nz); 

  assign                  x0_o = x0k;
  assign                  x1_o = x1k;
  assign                  yx_o = y1k;
  assign                  valid = valid_reg;
  assign                  done = done_reg;  
  
  
  //Copy of sorted co-ordinates and algorithm parameters
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          x0r <= #UD {DATA_WIDTH{1'b0}};
          y0r <= #UD {DATA_WIDTH{1'b0}};
          x1r <= #UD {DATA_WIDTH{1'b0}};
          y1r <= #UD {DATA_WIDTH{1'b0}};
          x2r <= #UD {DATA_WIDTH{1'b0}};
          y2r <= #UD {DATA_WIDTH{1'b0}};
          delta_x0 <= #UD {DATA_WIDTH{1'b0}};
          delta_y0 <= #UD {DATA_WIDTH{1'b0}};
          delta_x1 <= #UD {DATA_WIDTH{1'b0}};
          delta_y1 <= #UD {DATA_WIDTH{1'b0}};
          delta_x2 <= #UD {DATA_WIDTH{1'b0}};
          delta_y2 <= #UD {DATA_WIDTH{1'b0}};
          delta_x0_neg <= #UD 1'b0;
          delta_x1_neg <= #UD 1'b0;
          delta_x2_neg <= #UD 1'b0;          
        end
      else
      if (enable)
        begin
          case ({y0_gt_y1, y1_gt_y2, y0_gt_y2})
            3'b000,
            3'b001  : begin
                        x0r <= #UD x0;
                        y0r <= #UD y0;
                        x1r <= #UD x1;
                        y1r <= #UD y1;
                        x2r <= #UD x2;
                        y2r <= #UD y2;
                        delta_x0 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y0 <= #UD y1-y0;
                        delta_x1 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y1 <= #UD y2-y1;
                        delta_x2 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y2 <= #UD y2-y0;
                        delta_x0_neg <= #UD x0_gt_x1;
                        delta_x1_neg <= #UD x1_gt_x2;
                        delta_x2_neg <= #UD x0_gt_x2;                        
                      end
            3'b010  : begin
                        x0r <= #UD x0;
                        y0r <= #UD y0;
                        x1r <= #UD x2;
                        y1r <= #UD y2;
                        x2r <= #UD x1;
                        y2r <= #UD y1;
                        delta_x0 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y0 <= #UD y2-y0;
                        delta_x1 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y1 <= #UD y1-y2;
                        delta_x2 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y2 <= #UD y1-y0;  
                        delta_x0_neg <= #UD x0_gt_x2;
                        delta_x1_neg <= #UD !x1_gt_x2;
                        delta_x2_neg <= #UD x0_gt_x1;                        
                      end
            3'b011  : begin
                        x0r <= #UD x2;
                        y0r <= #UD y2;
                        x1r <= #UD x0;
                        y1r <= #UD y0;
                        x2r <= #UD x1;
                        y2r <= #UD y1;
                        delta_x0 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y0 <= #UD y0-y2;
                        delta_x1 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y1 <= #UD y1-y0;
                        delta_x2 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y2 <= #UD y1-y2;
                        delta_x0_neg <= #UD !x0_gt_x2;
                        delta_x1_neg <= #UD x0_gt_x1;
                        delta_x2_neg <= #UD !x1_gt_x2;                        
                      end
            3'b100  : begin
                        x0r <= #UD x1;
                        y0r <= #UD y1;
                        x1r <= #UD x0;
                        y1r <= #UD y0;
                        x2r <= #UD x2;
                        y2r <= #UD y2;
                        delta_x0 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y0 <= #UD y0-y1;
                        delta_x1 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y1 <= #UD y2-y0;
                        delta_x2 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y2 <= #UD y2-y1;
                        delta_x0_neg <= #UD !x0_gt_x1;
                        delta_x1_neg <= #UD x0_gt_x2;
                        delta_x2_neg <= #UD x1_gt_x2;                         
                      end
            3'b101  : begin
                        x0r <= #UD x1;
                        y0r <= #UD y1;
                        x1r <= #UD x2;
                        y1r <= #UD y2;
                        x2r <= #UD x0;
                        y2r <= #UD y0;
                        delta_x0 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y0 <= #UD y2-y1;
                        delta_x1 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y1 <= #UD y0-y2;
                        delta_x2 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y2 <= #UD y0-y1;
                        delta_x0_neg <= #UD x1_gt_x2;
                        delta_x1_neg <= #UD !x0_gt_x2;
                        delta_x2_neg <= #UD !x0_gt_x1;                        
                      end
           3'b110,           
           3'b111   : begin
                        x0r <= #UD x2;
                        y0r <= #UD y2;
                        x1r <= #UD x1;
                        y1r <= #UD y1;
                        x2r <= #UD x0;
                        y2r <= #UD y0;
                        delta_x0 <= #UD x1_gt_x2 ? (x1-x2) : (x2-x1);
                        delta_y0 <= #UD y1-y2;
                        delta_x1 <= #UD x0_gt_x1 ? (x0-x1) : (x1-x0);
                        delta_y1 <= #UD y0-y1;
                        delta_x2 <= #UD x0_gt_x2 ? (x0-x2) : (x2-x0);
                        delta_y2 <= #UD y0-y2;
                        delta_x0_neg <= #UD !x1_gt_x2;
                        delta_x1_neg <= #UD !x0_gt_x1;
                        delta_x2_neg <= #UD !x0_gt_x2;                        
                      end                      
            default : begin
                        x0r <= #UD x0;
                        y0r <= #UD y0;
                        x1r <= #UD x1;
                        y1r <= #UD y1;
                        x2r <= #UD x2;
                        y2r <= #UD y2;
                        delta_x0 <= #UD delta_x0;
                        delta_y0 <= #UD delta_y0;
                        delta_x1 <= #UD delta_x1;
                        delta_y1 <= #UD delta_y1;
                        delta_x2 <= #UD delta_x2;
                        delta_y2 <= #UD delta_y2;
                        delta_x0_neg <= #UD delta_x0_neg;
                        delta_x1_neg <= #UD delta_x1_neg;
                        delta_x2_neg <= #UD delta_x2_neg;                        
                      end
          endcase
        end
      else
        begin
          x0r <= #UD x0r;
          y0r <= #UD y0r;
          x1r <= #UD x1r;
          y1r <= #UD y1r;
          x2r <= #UD x2r;
          y2r <= #UD y2r;
          delta_x0 <= #UD delta_x0;
          delta_y0 <= #UD delta_y0;
          delta_x1 <= #UD delta_x1;
          delta_y1 <= #UD delta_y1;
          delta_x2 <= #UD delta_x2;
          delta_y2 <= #UD delta_y2;
          delta_x0_neg <= #UD delta_x0_neg;
          delta_x1_neg <= #UD delta_x1_neg;
          delta_x2_neg <= #UD delta_x2_neg;          
        end        
    end
    
  //FSM to keep track of function activity
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        current_state <= #UD IDLE;
      else
        current_state <= #UD next_state;  
    end
    
  always @ (current_state or enable or find_next or draw1_done or draw2_done)
    begin
      case (current_state)
        IDLE    : begin
                    if (enable)
                      next_state <= #UD PREP1;
                    else
                      next_state <= #UD IDLE;                    
                  end
        PREP1   : begin
                    next_state <= #UD WAITF;
                  end
        WAITF   : begin
                    if (find_next)
                      next_state <= #UD DRAW1;
                    else
                      next_state <= #UD WAITF;                    
                  end        
        DRAW1   : begin
                    case ({draw2_done, draw1_done})
                      2'b00   : next_state <= #UD DRAW1;
                      2'b01   : next_state <= #UD PREP2;
                      2'b10   : next_state <= #UD DRAW1;
                      2'b11   : next_state <= #UD DONE;
                      default : next_state <= #UD DRAW1;
                    endcase
                  end
        PREP2   : begin
                    next_state <= #UD DRAW2;                    
                  end        
        DRAW2   : begin
                    if (draw2_done)
                      next_state <= #UD DONE;
                    else
                      next_state <= #UD DRAW2;
                  end
        DONE    : begin
                    next_state <= #UD IDLE;
                  end        
        default : begin
                    next_state <= #UD IDLE;
                  end
      endcase
    end    

  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          error0 <= #UD {(DATA_WIDTH+1){1'b0}};
          error1 <= #UD {(DATA_WIDTH+1){1'b0}};
          x0k    <= #UD {DATA_WIDTH{1'b0}};
          y0k    <= #UD {DATA_WIDTH{1'b0}};
          x1k    <= #UD {DATA_WIDTH{1'b0}};
          y1k    <= #UD {DATA_WIDTH{1'b0}};
          y0kp   <= #UD {DATA_WIDTH{1'b0}};
          y1kp   <= #UD {DATA_WIDTH{1'b0}};          
        end
      else
        case (current_state)
          IDLE    : begin
                      error0 <= #UD {(DATA_WIDTH+1){1'b0}};
                      error1 <= #UD {(DATA_WIDTH+1){1'b0}};
                      x0k    <= #UD {DATA_WIDTH{1'b0}};
                      y0k    <= #UD {DATA_WIDTH{1'b0}};
                      x1k    <= #UD {DATA_WIDTH{1'b0}};
                      y1k    <= #UD {DATA_WIDTH{1'b0}};
                      y0kp   <= #UD {DATA_WIDTH{1'b0}};
                      y1kp   <= #UD {DATA_WIDTH{1'b0}};           
                    end
          PREP1   : begin
                      if (top_y_eq)
                        x0k    <= #UD x1r; 
                      else
                        x0k    <= #UD x0r;          
                      y0k    <= #UD y0r;
                      x1k    <= #UD x0r; 
                      y1k    <= #UD y0r;
                      y0kp   <= #UD y0r;
                      y1kp   <= #UD y0r;
                      if (dx0_gt_eq_dy0)
                        error0 <= #UD {delta_y0[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_x0};
                      else
                        error0 <= #UD {delta_x0[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_y0};
                      if (dx2_gt_eq_dy2)
                        error1 <= #UD {delta_y2[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_x2};
                      else
                        error1 <= #UD {delta_x2[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_y2};
                    end
          WAITF   : begin
                      x0k    <= #UD x0k;
                      y0k    <= #UD y0k;
                      x1k    <= #UD x1k;
                      y1k    <= #UD y1k;
                      y0kp   <= #UD y0kp;
                      y1kp   <= #UD y1kp;
                      error0 <= #UD error0;
                      error1 <= #UD error1;                      
                    end          
          DRAW1   : begin
                      casex({y0k_eq_y0kp, dx0_gt_eq_dy0, error0_check_xm, error0_check_ym})
                        4'b0xxx : begin
                                    error0 <= #UD error0;
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k;                                  
                                  end
                        4'b1000,
                        4'b1010 : begin
                                    error0 <= #UD error0 + {delta_x0[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                  end
                        4'b1001,
                        4'b1011 : begin
                                    error0 <= #UD error0 + {delta_x0[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_y0[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x0_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                                    
                                  end
                        4'b1100,
                        4'b1101 : begin
                                    error0 <= #UD error0 + {delta_y0[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x0_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k;                        
                                  end
                        4'b1110,
                        4'b1111 : begin
                                    error0 <= #UD error0 + {delta_y0[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_x0[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x0_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                        
                                  end                        
                        default : begin
                                    error0 <= #UD error0;
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k;
                                  end
                      endcase
                      casex({y1k_eq_y1kp, dx2_gt_eq_dy2, error1_check_xm, error1_check_ym})
                        4'b0xxx : begin
                                    error1 <= #UD error1;
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k;                                  
                                  end
                        4'b1000,
                        4'b1010 : begin
                                    error1 <= #UD error1 + {delta_x2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                  end
                        4'b1001,
                        4'b1011 : begin
                                    error1 <= #UD error1 + {delta_x2[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_y2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                                    
                                  end
                        4'b1100,
                        4'b1101 : begin
                                    error1 <= #UD error1 + {delta_y2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k;                        
                                  end
                        4'b1110,
                        4'b1111 : begin
                                    error1 <= #UD error1 + {delta_y2[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_x2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                        
                                  end                        
                        default : begin
                                    error1 <= #UD error1;
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k;
                                  end                      
                      endcase
                      if (find_next)
                        begin
                          y0kp <= #UD y0k;
                          y1kp <= #UD y1k;
                        end
                      else
                        begin
                          y0kp <= #UD y0kp;
                          y1kp <= #UD y1kp;                        
                        end                        
                    end
          PREP2   : begin
                      x0k    <= #UD x1r;
                      y0k    <= #UD y1r;
                      x1k    <= #UD x1k;
                      y1k    <= #UD y1k;
                      y0kp   <= #UD y1r;
                      y1kp   <= #UD y1kp;
                      error1 <= #UD error1;
                      if (dx1_gt_eq_dy1)
                        error0 <= #UD {delta_y1[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_x1};
                      else
                        error0 <= #UD {delta_x1[DATA_WIDTH-1:0], 1'b0} - {1'b0, delta_y1};        
                    end          
          DRAW2   : begin
                      casex({y0k_eq_y0kp, dx1_gt_eq_dy1, error0_check_xm, error0_check_ym})
                        4'b0xxx : begin
                                    error0 <= #UD error0;
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k;                                  
                                  end
                        4'b1000,
                        4'b1010 : begin
                                    error0 <= #UD error0 + {delta_x1[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                  end
                        4'b1001,
                        4'b1011 : begin
                                    error0 <= #UD error0 + {delta_x1[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_y1[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x1_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                                    
                                  end
                        4'b1100,
                        4'b1101 : begin
                                    error0 <= #UD error0 + {delta_y1[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x1_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k;                        
                                  end
                        4'b1110,
                        4'b1111 : begin
                                    error0 <= #UD error0 + {delta_y1[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_x1[DATA_WIDTH-1:0], 1'b0};
                                    x0k    <= #UD delta_x1_neg ? (x0k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y0k    <= #UD y0k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                        
                                  end                        
                        default : begin
                                    error0 <= #UD error0;
                                    x0k    <= #UD x0k;
                                    y0k    <= #UD y0k;
                                  end
                      endcase
                      casex({y1k_eq_y1kp, dx2_gt_eq_dy2, error1_check_xm, error1_check_ym})
                        4'b0xxx : begin
                                    error1 <= #UD error1;
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k;                                  
                                  end
                        4'b1000,
                        4'b1010 : begin
                                    error1 <= #UD error1 + {delta_x2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                  end
                        4'b1001,
                        4'b1011 : begin
                                    error1 <= #UD error1 + {delta_x2[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_y2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                                    
                                  end
                        4'b1100,
                        4'b1101 : begin
                                    error1 <= #UD error1 + {delta_y2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k;                        
                                  end
                        4'b1110,
                        4'b1111 : begin
                                    error1 <= #UD error1 + {delta_y2[DATA_WIDTH-1:0], 1'b0} - {2'b0, delta_x2[DATA_WIDTH-1:0], 1'b0};
                                    x1k    <= #UD delta_x2_neg ? (x1k - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (x1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                    y1k    <= #UD y1k + {{(DATA_WIDTH-1){1'b0}}, 1'b1};                        
                                  end                        
                        default : begin
                                    error1 <= #UD error1;
                                    x1k    <= #UD x1k;
                                    y1k    <= #UD y1k;
                                  end                      
                      endcase
                      if (find_next)
                        begin
                          y0kp <= #UD y0k;
                          y1kp <= #UD y1k;
                        end
                      else
                        begin
                          y0kp <= #UD y0kp;
                          y1kp <= #UD y1kp;                        
                        end             
                    end
          DONE    : begin
                      error0 <= #UD {(DATA_WIDTH+1){1'b0}};
                      error1 <= #UD {(DATA_WIDTH+1){1'b0}};
                      x0k    <= #UD {DATA_WIDTH{1'b0}};
                      y0k    <= #UD {DATA_WIDTH{1'b0}};
                      x1k    <= #UD {DATA_WIDTH{1'b0}};
                      y1k    <= #UD {DATA_WIDTH{1'b0}};
                      y0kp   <= #UD {DATA_WIDTH{1'b0}};
                      y1kp   <= #UD {DATA_WIDTH{1'b0}};          
                    end
          default : begin
                      error0 <= #UD {(DATA_WIDTH+1){1'b0}};
                      error1 <= #UD {(DATA_WIDTH+1){1'b0}};
                      x0k    <= #UD {DATA_WIDTH{1'b0}};
                      y0k    <= #UD {DATA_WIDTH{1'b0}};
                      x1k    <= #UD {DATA_WIDTH{1'b0}};
                      y1k    <= #UD {DATA_WIDTH{1'b0}};
                      y0kp   <= #UD {DATA_WIDTH{1'b0}};
                      y1kp   <= #UD {DATA_WIDTH{1'b0}};          
                    end
        endcase
    end 
  
  //Generate trigger when next y is available
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        next_yx_valid_fl <= #UD 1'b0;
      else
        next_yx_valid_fl <= next_yx_valid;      
    end
  
  //Handle valid and done signal
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          valid_reg <= #UD 1'b0;
          done_reg  <= #UD 1'b0;
        end
       else
        begin
          done_reg  <= #UD 1'b0;
          case (current_state)
            IDLE    : begin
                        valid_reg <= #UD 1'b0;
                      end
            PREP1   : begin
                        valid_reg <= #UD 1'b1;            
                      end
            WAITF   : begin
                        valid_reg <= #UD 1'b0;
                      end            
            DRAW1   : begin
                        if (next_yx_valid_pe)
                          valid_reg <= #UD 1'b1;
                        else
                          valid_reg <= #UD 1'b0;
                      end
            PREP2   : begin
                        valid_reg <= #UD 1'b0;            
                      end
            DRAW2   : begin
                        if (next_yx_valid_pe)
                          valid_reg <= #UD 1'b1;
                        else
                          valid_reg <= #UD 1'b0;
                      end
            DONE    : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b1;                        
                      end
            default : begin
                        valid_reg <= #UD 1'b0;            
                      end
          endcase
        end        
    end    
    
endmodule