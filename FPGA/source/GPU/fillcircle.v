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

module fillcircle #(
  
  parameter DATA_WIDTH  = 8           //Parameter for datawidth includes co-ordinates
  
  ) (
  
  input                   clk       , //Clock input
  input                   reset_n   , //Active low reset input
  
  input                   enable    , //Trigger to start the function
  
  input  [DATA_WIDTH-1:0] x0        , //Co-ordinate x0
  input  [DATA_WIDTH-1:0] y0        , //Co-ordinate y0
  input  [DATA_WIDTH-1:0] rad       , //Circle radius
  
  input                   find_next , //Trigger to find next x values to draw a line
  
  output                  valid     , //Output data valid
  output                  done      , //Feedback of task completion
  
  output [DATA_WIDTH-1:0] x0_o      , //X1 co-ordinate output
  output [DATA_WIDTH-1:0] x1_o      , //X2 co-ordinate output
  output [DATA_WIDTH-1:0] yx_o        //Common Y co-ordinate output
  
  );
  
  parameter UD = 1;  
  parameter FSM_WIDTH = 5;
  parameter IDLE = 5'b00001;
  parameter PREP = 5'b00010;
  parameter WAIT = 5'b00100;
  parameter DRAW = 5'b01000;
  parameter DONE = 5'b10000;

  reg    [FSM_WIDTH-1:0]  current_state, next_state;
  reg    [DATA_WIDTH-1:0] x0r, y0r, radr;
  reg    [DATA_WIDTH-1:0] xk, yk, x0_o_reg, x1_o_reg, yx_o_reg;
  reg    [DATA_WIDTH:0]   delta_x, delta_y, error;

  reg    [1:0]            data_out_seq_cnt;
  reg                     valid_trig, valid_reg, done_reg;  
  
  wire                    completed = !( xk < yk); 

  wire                    err_gt_eq_0 = ~error[DATA_WIDTH]; 
  
  wire   [DATA_WIDTH:0]   delta_x_p_2 = delta_x + {{(DATA_WIDTH-1){1'b0}}, 2'b10};
  wire   [DATA_WIDTH:0]   delta_x_p_3 = delta_x + {{(DATA_WIDTH-1){1'b0}}, 2'b11};
  wire   [DATA_WIDTH:0]   delta_y_p_2 = delta_y + {{(DATA_WIDTH-1){1'b0}}, 2'b10};
  wire                    next_iteration = (data_out_seq_cnt == 2'h3);
  wire                    first_valid = (current_state == PREP);
  wire                    valid_trig_en = first_valid || find_next;
  
  assign                  x0_o  = x0_o_reg;
  assign                  x1_o  = x1_o_reg;
  assign                  yx_o  = yx_o_reg;
  assign                  valid = valid_reg;
  assign                  done  = done_reg;

  //FSM to keep track of function activity
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        current_state <= #UD IDLE;
      else
        current_state <= #UD next_state;  
    end
  
  always @ (current_state or enable or completed or valid_reg or next_iteration)
    begin
      case(current_state)
        IDLE    : begin
                    if (enable)
                      next_state <= #UD PREP;
                    else
                      next_state <= #UD IDLE;                    
                  end
        PREP    : begin
                    next_state <= #UD WAIT;
                  end
        WAIT    : begin
			              if (valid_reg && next_iteration)
					            next_state <= #UD DRAW;
					          else  
                      next_state <= #UD WAIT;        
                  end        
        DRAW    : begin
                    if (completed && next_iteration)
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
          x0r  <= #UD {DATA_WIDTH{1'b0}};
          y0r  <= #UD {DATA_WIDTH{1'b0}};
          radr <= #UD {DATA_WIDTH{1'b0}};
        end
      else
      if (enable)
        begin
          x0r  <= #UD x0;
          y0r  <= #UD y0;
          radr <= #UD rad;        
        end
      else
        begin
          x0r  <= #UD x0r;
          y0r  <= #UD y0r;
          radr <= #UD radr;
        end        
    end

  //Process variables
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          error   <= #UD {(DATA_WIDTH+1){1'b0}};
          delta_x <= #UD {(DATA_WIDTH+1){1'b0}};
          delta_y <= #UD {(DATA_WIDTH+1){1'b0}};          
          xk      <= #UD {DATA_WIDTH{1'b0}};
          yk      <= #UD {DATA_WIDTH{1'b0}};         
        end
      else
        begin
          case (current_state)
            IDLE    : begin
                        error   <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_x <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_y <= #UD {(DATA_WIDTH+1){1'b0}};          
                        xk      <= #UD {DATA_WIDTH{1'b0}};
                        yk      <= #UD {DATA_WIDTH{1'b0}};            
                      end
            PREP    : begin
                        error   <= #UD {{(DATA_WIDTH){1'b0}}, 1'b1} - {1'b0, radr};
                        delta_x <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_y <= #UD {(DATA_WIDTH+1){1'b0}} - {radr, 1'b0};          
                        xk      <= #UD {DATA_WIDTH{1'b0}};
                        yk      <= #UD radr;             
                      end
            WAIT    : begin
                        error   <= #UD error;
                        delta_x <= #UD delta_x;
                        delta_y <= #UD delta_y;
                        xk      <= #UD xk;
                        yk      <= #UD yk;                                      
                      end            
            DRAW    : begin
                        if (next_iteration && find_next)
                          begin
                            if (err_gt_eq_0)
                              begin
                                error   <= #UD error + delta_y_p_2 + delta_x_p_3;
                                delta_x <= #UD delta_x_p_2;
                                delta_y <= #UD delta_y_p_2;
                                xk      <= #UD xk + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                yk      <= #UD yk - {{(DATA_WIDTH-1){1'b0}}, 1'b1};                            
                              end
                            else
                              begin
                                error   <= #UD error + delta_x_p_3;
                                delta_x <= #UD delta_x_p_2;
                                delta_y <= #UD delta_y;
                                xk      <= #UD xk + {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                                yk      <= #UD yk;                          
                              end
                          end
                        else
                          begin
                            error   <= #UD error;
                            delta_x <= #UD delta_x;
                            delta_y <= #UD delta_y;
                            xk      <= #UD xk;
                            yk      <= #UD yk;                          
                          end                          
                      end
            DONE    : begin
                        error   <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_x <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_y <= #UD {(DATA_WIDTH+1){1'b0}};          
                        xk      <= #UD {DATA_WIDTH{1'b0}};
                        yk      <= #UD {DATA_WIDTH{1'b0}};            
                      end
            default : begin
                        error   <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_x <= #UD {(DATA_WIDTH+1){1'b0}};
                        delta_y <= #UD {(DATA_WIDTH+1){1'b0}};          
                        xk      <= #UD {DATA_WIDTH{1'b0}};
                        yk      <= #UD {DATA_WIDTH{1'b0}};            
                      end
          endcase
        end        
    end
  
  //Data output sequence counter as at a time as many as eight co-ordinates available
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        data_out_seq_cnt <= #UD 2'h0;
      else
      if (current_state == IDLE)
        data_out_seq_cnt <= #UD 2'h0;
      else
      if (find_next)
        data_out_seq_cnt <= #UD data_out_seq_cnt + 2'h1;
      else
        data_out_seq_cnt <= #UD data_out_seq_cnt;      
    end
  
  //Flop clk_en to synchronize output  
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        valid_trig <= #UD 1'b0;
      else
        valid_trig <= #UD valid_trig_en;      
    end  
  
  //Generate output co-ordinates
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          x0_o_reg <= #UD {DATA_WIDTH{1'b0}};
          x1_o_reg <= #UD {DATA_WIDTH{1'b0}};
          yx_o_reg <= #UD {DATA_WIDTH{1'b0}};
        end
      else
        begin
          case (data_out_seq_cnt)
            2'h0    : begin
                        x0_o_reg <= #UD x0r - yk;
                        x1_o_reg <= #UD x0r + yk;
                        yx_o_reg <= #UD y0r - xk;
                      end
            2'h1    : begin
                        x0_o_reg <= #UD x0r + xk;
                        x1_o_reg <= #UD x0r - xk;
                        yx_o_reg <= #UD y0r + yk;            
                      end
            2'h2    : begin
                        x0_o_reg <= #UD x0r + xk;
                        x1_o_reg <= #UD x0r - xk;
                        yx_o_reg <= #UD y0r - yk;            
                      end
            2'h3    : begin
                        x0_o_reg <= #UD x0r + yk;
                        x1_o_reg <= #UD x0r - yk;
                        yx_o_reg <= #UD y0r + xk;            
                      end
            // 3'h4    : begin
                        // x_o_reg <= #UD x0r - yk;
                        // y_o_reg <= #UD y0r + xk;            
                      // end
            // 3'h5    : begin
                        // x_o_reg <= #UD x0r - xk;
                        // y_o_reg <= #UD y0r + yk;            
                      // end
            // 3'h6    : begin
                        // x_o_reg <= #UD x0r - xk;
                        // y_o_reg <= #UD y0r - yk;            
                      // end
            // 3'h7    : begin
                        // x_o_reg <= #UD x0r + yk;
                        // y_o_reg <= #UD y0r - xk;            
                      // end
            default : begin
                        x0_o_reg <= #UD x0_o_reg;
                        x1_o_reg <= #UD x1_o_reg;
                        yx_o_reg <= #UD yx_o_reg;            
                      end
          endcase
        end        
    end    
    
  //Generate valid signal
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        valid_reg <= #UD 1'b0;
      else
      if (valid_trig)
        case(current_state)
          IDLE    : valid_reg <= #UD 1'b0;
          PREP    : valid_reg <= #UD 1'b0;
          WAIT    : valid_reg <= #UD 1'b1;
          DRAW    : valid_reg <= #UD 1'b1;
          DONE    : valid_reg <= #UD 1'b0;
          default : valid_reg <= #UD 1'b0;
        endcase
      else
        valid_reg <= #UD 1'b0;      
    end
  
  //Generate done signal
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        done_reg <= #UD 1'b0;
      else
      if (current_state == DONE)
        done_reg <= #UD 1'b1;
      else
        done_reg <= #UD 1'b0;      
    end    
  
endmodule  