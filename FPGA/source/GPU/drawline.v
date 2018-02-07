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

`timescale 1 ns/100ps

module drawline #(
  
  parameter DATA_WIDTH  = 8           //Parameter for datawidth includes co-ordinates
  
  ) (
  
  input                   clk       , //Clock input
  input                   reset_n   , //Active low reset input
  input                   clk_en    , //Clock enable to slow down output data
  
  input                   enable    , //Trigger to start the function
  
  input  [DATA_WIDTH-1:0] x0        , //Co-ordinate x0
  input  [DATA_WIDTH-1:0] y0        , //Co-ordinate y0
  input  [DATA_WIDTH-1:0] x1        , //Co-ordinate x1
  input  [DATA_WIDTH-1:0] y1        , //Co-ordinate y1
  
  output                  valid     , //Output data valid
  output                  done      , //Feedback of task completion
  
  output [DATA_WIDTH-1:0] x_o       , //X co-ordinate output
  output [DATA_WIDTH-1:0] y_o         //Y co-ordinate output
  );
  
  parameter UD = 1;  
  parameter FSM_WIDTH = 4;
  parameter IDLE = 4'b0001;
  parameter PREP = 4'b0010;
  parameter DRAW = 4'b0100;
  parameter DONE = 4'b1000;
  
  
  reg    [FSM_WIDTH-1:0]  current_state, next_state;
  
  reg    [DATA_WIDTH-1:0] x0r, y0r, x1r, y1r;
  reg    [DATA_WIDTH-1:0] delta_x, delta_y, xk, yk;
  reg    [DATA_WIDTH+1:0] error;
  
  reg                     delta_x_neg, delta_y_neg;
  
  reg                     valid_reg, done_reg;
  
  wire                    x0_gt_x1 = (x0 > x1);
  wire                    y0_gt_y1 = (y0 > y1);
  
  wire                    dx_gt_eq_dy = (delta_x[DATA_WIDTH-1:0] >= delta_y[DATA_WIDTH-1:0]);
  
  wire                    completed = ((xk==x1r) && (yk==y1r));
  
  wire                    error_pos = !error[DATA_WIDTH+1];
  wire                    error_nz  = |error;
  wire                    error_check_xm = (error_pos && (error_nz || (!delta_x_neg))); 
  wire                    error_check_ym = (error_pos && (error_nz || (!delta_y_neg)));
  
  assign                  valid = valid_reg;
  assign                  done = done_reg;
  
  assign                  x_o = (current_state == DRAW) ? xk : {DATA_WIDTH{1'b0}};
  assign                  y_o = (current_state == DRAW) ? yk : {DATA_WIDTH{1'b0}};
  
  //FSM to keep track of function activity
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        current_state <= #UD IDLE;
      else
        current_state <= #UD next_state;  
    end
  
  always @ (current_state or enable or completed or clk_en)
    begin
      case(current_state)
        IDLE    : begin
                    if (enable)
                      next_state <= #UD PREP;
                    else
                      next_state <= #UD IDLE;                    
                  end
        PREP    : begin
			              if (clk_en)
					            next_state <= #UD DRAW;
					          else  
                      next_state <= #UD PREP;
                  end        
        DRAW    : begin
                    if (completed)
                      next_state <= #UD DONE;
                    else
                      next_state <= #UD DRAW;                    
                  end
        DONE    : begin
                    next_state <= #UD IDLE;
                  end
        default : begin
                    next_state <= #UD IDLE;
                  end        
      endcase
    end
  
  //Store necessary parameters for function in internal registers
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          x0r <= #UD {DATA_WIDTH{1'b0}};
          y0r <= #UD {DATA_WIDTH{1'b0}};
          x1r <= #UD {DATA_WIDTH{1'b0}};
          y1r <= #UD {DATA_WIDTH{1'b0}};
          delta_x <= #UD {DATA_WIDTH{1'b0}};
          delta_y <= #UD {DATA_WIDTH{1'b0}};
          delta_x_neg <= #UD 1'b0;
          delta_y_neg <= #UD 1'b0;
        end
      else
      if (enable)
        begin
          x0r <= #UD x0;
          y0r <= #UD y0;
          x1r <= #UD x1;
          y1r <= #UD y1;
          delta_x <= #UD x0_gt_x1 ? (x0 - x1) : (x1 - x0);
          delta_y <= #UD y0_gt_y1 ? (y0 - y1) : (y1 - y0);
          delta_x_neg <= #UD x0_gt_x1;
          delta_y_neg <= #UD y0_gt_y1;          
        end
      else
        begin
          x0r <= #UD x0r;
          y0r <= #UD y0r;
          x1r <= #UD x1r;
          y1r <= #UD y1r;
          delta_x <= #UD delta_x;
          delta_y <= #UD delta_y;
          delta_x_neg <= #UD delta_x_neg;
          delta_y_neg <= #UD delta_y_neg;
        end        
    end
   
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          error <= #UD {(DATA_WIDTH+2){1'b0}};
          xk    <= #UD {DATA_WIDTH{1'b0}};
          yk    <= #UD {DATA_WIDTH{1'b0}};           
        end
      else
        case(current_state)
          IDLE    : begin
                      error <= #UD {(DATA_WIDTH+2){1'b0}};
                      xk    <= #UD {DATA_WIDTH{1'b0}};
                      yk    <= #UD {DATA_WIDTH{1'b0}};
                    end  
          PREP    : begin
                     if (clk_en)
                      begin
                        xk    <= #UD x0r;
                        yk    <= #UD y0r;
                        if (dx_gt_eq_dy)
                          error <= #UD {1'b0, delta_y, 1'b0} - {2'b0, delta_x}; //check if any problem not dividing delta_x by 2
                        else
                          error <= #UD {1'b0, delta_x, 1'b0} - {2'b0, delta_y};                      
                      end
                    else
                      begin
                        error <= #UD {(DATA_WIDTH+2){1'b0}};
                        xk    <= #UD {DATA_WIDTH{1'b0}};
                        yk    <= #UD {DATA_WIDTH{1'b0}};						  
                      end	  
                    end
          DRAW    : begin
                      if (clk_en)
                        begin
                          case ({dx_gt_eq_dy, error_check_xm, error_check_ym})
                            3'b000,
                            3'b010  : begin
                                        error <= #UD error + {1'b0, delta_x, 1'b0};
                                        xk    <= #UD xk;
                                        yk    <= #UD delta_y_neg ? (yk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (yk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                      end 
                            3'b001,
                            3'b011  : begin
                                        error <= #UD error + {1'b0, delta_x, 1'b0} - {1'b0, delta_y, 1'b0};
                                        xk    <= #UD delta_x_neg ? (xk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (xk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                        yk    <= #UD delta_y_neg ? (yk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (yk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                      end
                            3'b100,
                            3'b101  : begin
                                        error <= #UD error + {1'b0, delta_y, 1'b0};
                                        xk    <= #UD delta_x_neg ? (xk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (xk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                        yk    <= #UD yk;
                                      end  
                            3'b110,
                            3'b111  : begin
                                        error <= #UD error + {1'b0, delta_y, 1'b0} - {1'b0, delta_x, 1'b0};
                                        xk    <= #UD delta_x_neg ? (xk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (xk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});
                                        yk    <= #UD delta_y_neg ? (yk - {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : (yk + {{(DATA_WIDTH-1){1'b0}}, 1'b1});                                  
                                      end  
                            default : begin
                                        error <= #UD error;
                                        xk    <= #UD xk;
                                        yk    <= #UD yk;
                                      end  
                          endcase
                        end
                      else
                        begin
                          error <= #UD error;
                          xk    <= #UD xk;
                          yk    <= #UD yk;
                        end                      
                    end
          DONE    : begin
                      error <= #UD {(DATA_WIDTH+2){1'b0}};
                      xk    <= #UD {DATA_WIDTH{1'b0}};
                      yk    <= #UD {DATA_WIDTH{1'b0}};
                    end          
          default : begin
                      error <= #UD {(DATA_WIDTH+2){1'b0}};
                      xk    <= #UD {DATA_WIDTH{1'b0}};
                      yk    <= #UD {DATA_WIDTH{1'b0}};
                    end
        endcase        
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
          case (current_state)
            IDLE    : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;           
                      end            
            PREP    : begin
				                if (clk_en)
                          valid_reg <= #UD 1'b1;
						            else
						              valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;
                      end
            DRAW    : begin
                        if (clk_en)
                          valid_reg <= #UD 1'b1;
                        else
                          valid_reg <= #UD 1'b0;                        
                        done_reg  <= #UD 1'b0;            
                      end
            DONE    : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b1;            
                      end
            default : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;            
                      end
          endcase
        end        
    end    

endmodule  