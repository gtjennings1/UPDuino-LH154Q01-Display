// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2006 by Lattice Semiconductor Corporation
// --------------------------------------------------------------------
//
// Permission:
//
//   Lattice Semiconductor grants permission to use this code for use
//   in synthesis for any Lattice programmable logic product.  Other
//   use of this code, including the selling or duplication of any
//   portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL or Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Lattice Semiconductor Corporation
//                     5555 NE Moore Court
//                     Hillsboro, OR 97214
//                     U.S.A
//
//                     TEL: 1-800-Lattice (USA and Canada)
//                          503-268-8001 (other locations)
//
//                     web: http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
// --------------------------------------------------------------------
//
// Revision History :

module uart_rx_fsm(                   
    // System clock 
    // asynchronous active high reset 
    input wire        i_clk,
    input wire        i_rst,
    input wire        i_rx_clk,
    //Rx FSM Control signal from Master Controller
    input wire        i_start_rx,
    //Rx configurations from Master Controller
    input wire        i_loopback_en,
    input wire        i_parity_even,
    input wire        i_parity_en,               
    input wire [1:0]  i_no_of_data_bits,  
    input wire        i_stick_parity_en,
    input wire        i_clear_linestatusreg,               
    input wire        i_clear_rxdataready,
    //Rx data valid and Rx Data to CPU
    output reg [7:0]  o_rx_data, 
    output reg        o_timeout,      
    
    output wire       bit_sample_en,
             
    //To UART Master Controller
    output wire       o_parity_error,
    output wire       o_framing_error,
    output wire       o_break_interrupt,               
    output wire       o_rx_data_ready,
    //Serial data for loopback operations
    input wire        i_int_serial_data,
    //Serial data in from MODEM
    input wire        i_serial_data
    );

    parameter [3:0] /*synopsys enum state_info*/ IDLE_STATE           = 4'b0000,
                   START_DETECT_STATE   = 4'b0001,
                   SAMPLE_START_STATE = 4'b1111,
                   Rx_1BIT_STATE        = 4'b0010,
                   Rx_2BIT_STATE        = 4'b0011,
                   Rx_3BIT_STATE        = 4'b0100,
                   Rx_4BIT_STATE        = 4'b0101,
                   Rx_5BIT_STATE        = 4'b0110,
                   Rx_6BIT_STATE        = 4'b0111,
                   Rx_7BIT_STATE        = 4'b1000,
                   Rx_8BIT_STATE        = 4'b1001,
                   PARITY_CHECK_STATE   = 4'b1010,
                   STOP_DETECT_STATE    = 4'b1011;
    // DATA_VALIDATION_STATE     = 4'b1100;    
    
    //Internal signals 
    reg [3:0]  /*synopsys enum state_info*/  state; /*synopsys enum state_vector state*/
    reg        check_bit;    
    reg        modem_serial_data;
    reg [10:0] rx_data;
    reg        parity_error;
    reg        framing_error;
    reg        stick_parity_bit;
    reg        clear_line_status;
    reg        clear_data_ready;
    reg        timeout_counter_begin;   
    reg        clearrxdataready1;
    reg        rx_clk_reg1;
    reg        rx_clk_reg2;
    wire       rx_clk_en;
    wire       rx_sample_en;
    reg        data_validation;
    reg        loopback_en_latch;
    
    //synchronizer for incoming i_serial_data from MODEM
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            modem_serial_data <= 1'b1;
        end else begin
            if(!i_loopback_en)
                //For regular Rx operations
                modem_serial_data <= i_serial_data;
            else
                // for loop back operations
                modem_serial_data <= i_int_serial_data; 
        end 
    end // always @ (posedge i_clk or posedge i_rst) 
    
    ////////////////////////////////////////////////////////////////
    // UART Rx FSM
    ////////////////////////////////////////////////////////////////
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            state <= IDLE_STATE;
            framing_error <= 1'b0;
            stick_parity_bit <= 1'b0;   
            timeout_counter_begin <= 1'b1;
            data_validation <= 1'b0;
            rx_data <= 10'b0;    
        end else begin
            case(state)
                
                IDLE_STATE         :  begin
                    state <= START_DETECT_STATE; 
                    timeout_counter_begin <= 1'b1;
                end
                
                //Wait for START signal from MODEM 
                START_DETECT_STATE :
                    if(rx_sample_en) begin
                        //Check if modem serial is still '0'
                        if(!modem_serial_data) begin
                            state <= Rx_1BIT_STATE; 
                            framing_error <= 1'b0;
                            timeout_counter_begin <= 1'b0;
                            data_validation <= 1'b0;
                            rx_data[10] <= modem_serial_data; 
                        end else if(clear_data_ready) begin
                            data_validation <= 1'b0;
                            rx_data <= 10'b0000_0000_00; 
                        end
                    end
                
                Rx_1BIT_STATE      : 
                    if(rx_sample_en) begin 
                        state <= Rx_2BIT_STATE;
                        rx_data[9] <= modem_serial_data; 
                    end
                
                Rx_2BIT_STATE      : 
                    if(rx_sample_en) begin 
                        state <= Rx_3BIT_STATE;
                        rx_data[8] <= modem_serial_data; 
                    end
                
                Rx_3BIT_STATE      : 
                    if(rx_sample_en) begin
                        state <= Rx_4BIT_STATE;
                        rx_data[7] <= modem_serial_data; 
                    end
                
                Rx_4BIT_STATE      : 
                    if(rx_sample_en) begin
                        state <= Rx_5BIT_STATE;
                        rx_data[6] <= modem_serial_data; 
                    end
                
                //Check for no of bits in operation
                //If 5 bits, then check if parity needs to be checked else go to stop detect state                      
                Rx_5BIT_STATE      : 
                    if(rx_sample_en) begin
                        rx_data[5] <= modem_serial_data; 
                        if(i_no_of_data_bits == 2'b00) begin
                            if(i_parity_en) begin
                                state <= PARITY_CHECK_STATE;
                            end else begin 
                                state <= STOP_DETECT_STATE;
                            end 
                        end else begin 
                            state <= Rx_6BIT_STATE;
                        end
                    end // if (rx_sample_en)
                
                //Check for no of bits in operation
                //If 6 bits, then check if parity needs to be checked else go to stop detect state                      
                Rx_6BIT_STATE      :
                    if(rx_sample_en) begin
                        rx_data[4] <= modem_serial_data; 
                        if(i_no_of_data_bits == 2'b01) begin
                            if(i_parity_en) begin
                                state <= PARITY_CHECK_STATE;
                            end else begin 
                                state <= STOP_DETECT_STATE;
                            end 
                        end else begin 
                            state <= Rx_7BIT_STATE;
                        end
                    end // if (rx_sample_en)
                
                //Check for no of bits in operation
                //If 7 bits, then check if parity needs to be checked else go to stop detect state
                Rx_7BIT_STATE      : 
                    if(rx_sample_en) begin
                        rx_data[3] <= modem_serial_data; 
                        if(i_no_of_data_bits == 2'b10) begin
                            if(i_parity_en) begin
                                state <= PARITY_CHECK_STATE;
                            end else begin 
                                state <= STOP_DETECT_STATE;
                            end 
                        end else begin 
                            state <= Rx_8BIT_STATE;
                        end
                    end // if (rx_sample_en)
                
                //Check if parity needs to be checked else go to stop detect state
                Rx_8BIT_STATE      :
                    if(rx_sample_en) begin
                        rx_data[2] <= modem_serial_data; 
                        if(i_parity_en) begin
                            state <= PARITY_CHECK_STATE;
                        end else begin
                            state <= STOP_DETECT_STATE;
                        end  
                    end                
                
                PARITY_CHECK_STATE :
                    if(rx_sample_en) begin
                        rx_data[1] <= modem_serial_data; 
                        state <= STOP_DETECT_STATE;
                        stick_parity_bit <= modem_serial_data;
                    end
                
                //Check for stop bit and proceed to START_DETECT_STATE 
                STOP_DETECT_STATE  : 
                    if(rx_sample_en) begin
                        rx_data[0] <= modem_serial_data; 
                        data_validation <= 1'b1;
                        if(modem_serial_data == 1'b0) begin
                            state <= IDLE_STATE; 
                            framing_error <= 1'b1;
                        end else begin
                            state <= IDLE_STATE; 
                            framing_error <= 1'b0;
                        end
                    end // if (rx_sample_en)
                
                default            : state <= IDLE_STATE;
            endcase // case (state)
        end
    end // always @ (posedge i_clk or posedge i_rst)

    //Cleared on Line status clear request from Master controller
    assign o_framing_error = (!clear_line_status) ? framing_error : 1'b0;
    
    /////////////////////////////////////////////////////////////////////////////
    // Deserialization of data, 
    /////////////////////////////////////////////////////////////////////////////
    wire [10:0] receive_data;

    assign receive_data = {rx_data[0], rx_data[1], rx_data[2], rx_data[3], rx_data[4], rx_data[5],
                           rx_data[6], rx_data[7], rx_data[8], rx_data[9], rx_data[10]};

    reg break_interrupt;
    
    /////////////////////////////////////////////////////////////////////////////
    //Break Interrupt generation
    //In data valid state all the bits are of rx_data are zero then a Break Interrupt is generated
    /////////////////////////////////////////////////////////////////////////////
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            break_interrupt <= 1'b0;
        end else begin
            //Cleared on Line status clear request from Master controller 
            if(clear_line_status)begin 
                break_interrupt <= 1'b0;
            end else if(data_validation) begin
                if(rx_data == 10'b0) begin
                    break_interrupt <= 1'b1;
                end else begin
                    break_interrupt <= 1'b0;
                end   
            end // if (state == DATA_VALIDATION_STATE & !latch_clear_line_status)
        end
    end // always @ (posedge i_clk or posedge i_rst)

    assign o_break_interrupt = break_interrupt;
    
    /////////////////////////////////////////////////////////////////////////////
    // Parity Check logic and Parity error detect
    /////////////////////////////////////////////////////////////////////////////
    //Parity check logic
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            check_bit <= 1'b0;
        end else begin
            if(state == STOP_DETECT_STATE) begin
                check_bit <= rx_data[9] ^ rx_data[8] ^ rx_data[7] ^ rx_data[6] ^ rx_data[5] ^ rx_data[4]
                    ^ rx_data[3] ^ rx_data[2] ^ rx_data[1]; 
            end else begin 
                check_bit <= 1'b0;
            end 
        end 
    end // always @ (posedge i_clk or posedge i_rst)

    //Parity Error detection logic
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            parity_error <= 1'b0;
        end else begin
            if(state == STOP_DETECT_STATE & !clear_line_status) begin
                if(i_parity_en) begin
                    if(i_parity_even & !i_stick_parity_en) begin
                        if(check_bit) 
                            parity_error <= 1'b1;
                        else    
                            parity_error <= 1'b0;
                    end else if (!i_parity_even & !i_stick_parity_en) begin
                        if(check_bit) 
                            parity_error <= 1'b0;
                        else    
                            parity_error <= 1'b1;
                    end else if (i_parity_even & i_stick_parity_en) begin
                        if(stick_parity_bit)
                            parity_error <= 1'b1;
                        else
                            parity_error <= 1'b0;
                    end else
                        if(stick_parity_bit)
                            parity_error <= 1'b0;
                        else
                            parity_error <= 1'b1;
                end else
                    parity_error <= 1'b0;
                
            end else if(clear_line_status) 
                parity_error <= 1'b0;   
        end 
    end // always @ (posedge i_clk or posedge i_rst)    

    assign o_parity_error = !break_interrupt ?  parity_error
                            : 1'b0;    

    /////////////////////////////////////////////////////////////////////////////
    // Rx Data ready and Rx Data generation logic
    /////////////////////////////////////////////////////////////////////////////
    
    reg rx_data_ready;    

    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_rx_data     <= 0;
        end else begin
            if(data_validation) begin
                if(i_parity_en) begin
                    case(i_no_of_data_bits)
                        2'b00 :
                            o_rx_data <= {1'b0, 1'b0, 1'b0, receive_data[5:1]};
                        2'b01 :
                            o_rx_data <= {1'b0, 1'b0, receive_data[6:1]};
                        2'b10 :
                            o_rx_data <= {1'b0, receive_data[7:1]};
                        2'b11 :
                            o_rx_data <= receive_data[7:0];
                    endcase
                end else begin
                    case(i_no_of_data_bits)
                        2'b00 :
                            o_rx_data <= {1'b0, 1'b0, 1'b0, receive_data[5:1]};
                        2'b01 :
                            o_rx_data <= {1'b0, 1'b0, receive_data[6:1]};
                        2'b10 :
                            o_rx_data <= {1'b0, receive_data[7:1]};
                        2'b11 :
                            o_rx_data <= receive_data[7:0];
                    endcase
                end // else: !if(parity_en)
            end else begin
                o_rx_data       <= 0;
            end
        end
    end // always @ (posedge i_clk or posedge i_rst)
    
    wire rx_data_ready1;
    reg  rx_data_ready_reg1;
    reg  rx_data_ready_reg2;

    //Cleared on data status clear request from Master controller 
    assign rx_data_ready1 = data_validation;

    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            rx_data_ready_reg1 <= 1'b0;
            rx_data_ready_reg2 <= 1'b0; 
        end else begin
            rx_data_ready_reg1 <= rx_data_ready1;
            rx_data_ready_reg2 <= rx_data_ready_reg1; 
        end
    end
    
    //Made into a synchronous pulse
    assign o_rx_data_ready = rx_data_ready_reg1 & !rx_data_ready_reg2;   

    
    /////////////////////////////////////////////////////////////////////////////
    //Sampling clock and character timeout  generation logic
    /////////////////////////////////////////////////////////////////////////////
    
    //Registering and pulsing of RxCLK
    //This is in view of Clock domain crossing
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            rx_clk_reg1 <= 1'b0;
            rx_clk_reg2 <= 1'b0;
        end else begin 
            rx_clk_reg1 <= i_rx_clk;
            rx_clk_reg2 <= rx_clk_reg1;
        end
    end
    
    assign rx_clk_en = rx_clk_reg1 & !rx_clk_reg2;
            
    reg [3:0] rx_sampling_counter;
    reg       rx_sampling_clock;
    reg       rx_sampling_clock_reg1;
    reg       rx_sampling_clock_reg2;
    reg       rx_sampling_start;

    //Start sampling on falling edge of serial data line in start state
    //This is mainly used for centering purpose
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            rx_sampling_start <= 1'b0; 
        end else begin
            if(state == START_DETECT_STATE) begin
                if(!modem_serial_data) 
                    rx_sampling_start <= 1'b1;
                else 
                    rx_sampling_start <= 1'b0;
            end else if(state == IDLE_STATE) 
                rx_sampling_start <= 1'b0;
        end // else: !if(i_rst)
    end // always @ (posedge i_clk or posedge i_rst)
    
    //RX_CLK = 16xBaud Rate, a divide by 16 logic gives us the required sampling clock
    always @(posedge i_rx_clk or posedge i_rst) begin
        if(i_rst) begin
            rx_sampling_counter <= 0;
            rx_sampling_clock <= 1'b0;            
        end else begin
            case (state)
                //Sampling counter reset to zero 
                IDLE_STATE : begin
                    rx_sampling_counter <= 0;
                end                        
                default : begin
                    if(rx_sampling_start) begin
                    //4 bit counter
                        if(rx_sampling_counter == 4'b1111) begin 
                            rx_sampling_counter <= 0;
                        end else begin
                            rx_sampling_counter <= rx_sampling_counter + 1;
                        end
                        //Divide by 16 logic
                        if(rx_sampling_counter < 4'b1000) begin
                            rx_sampling_clock <= 1'b0;
                        end else begin
                            rx_sampling_clock <= 1'b1;
                        end
                    end else 
                        rx_sampling_counter <= 0; 
                end // case: default
            endcase
        end
    end // always @ (posedge i_rx_clk or posedge i_rst)        

    //Registering sampling clock for obtaining pulsed rx_sample_en
    always @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            rx_sampling_clock_reg1 <= 0;
            rx_sampling_clock_reg2 <= 0;
        end else begin
            rx_sampling_clock_reg1 <= rx_sampling_clock;
            rx_sampling_clock_reg2 <= rx_sampling_clock_reg1;
        end
    end

    //Pulsed rx_sample_en signal
    assign rx_sample_en = rx_sampling_clock_reg1 & !rx_sampling_clock_reg2;
    
    //Clearrxready signal received from NXP_16550_reg
    always @(posedge i_clk or posedge i_rst)begin
        if(i_rst)begin
            clearrxdataready1 <= 1'b0;
        end else begin
            clearrxdataready1 <= i_clear_rxdataready;
        end
    end // always @ (posedge i_clk or posedge i_rst)
    
    reg [5:0] timeout_counter;
    
    //Timeout counter for generating character timeout interrupt
    //Setto 4 character lengths = 48 bits
    //One character length is 12 bits - 1 Start,8 Data,1 Parity, 2 stop  
    always @(posedge i_rst or posedge i_clk) begin 
        if(i_rst) begin
            timeout_counter <= 6'b000_000;
        end else begin
            if(clearrxdataready1)
                timeout_counter <= 6'b000_000;
            else if(rx_clk_en) begin
                if(timeout_counter_begin & timeout_counter == 6'b110_000)
                    timeout_counter <= 6'b110_000;
                else if(timeout_counter_begin)
                    timeout_counter <= timeout_counter + 1'b1;
                else
                    timeout_counter <= 0;
            end    
        end
    end // always @ (posedge i_rst or posedge i_clk)

    //Timeout signal clear and drive logic    
    always @(posedge i_rst or posedge i_clk) begin
        if(i_rst) begin
            o_timeout <= 1'b0;
        end else begin
             if(timeout_counter == 6'b110_000) 
                o_timeout <= 1'b1;
            else
                o_timeout <= 1'b0;
        end
    end

    //Clear line status 
    always @(posedge i_clk or posedge i_rst)begin
        if(i_rst) begin
            clear_line_status <= 1'b0;
        end else begin
            if (i_clear_linestatusreg) 
                clear_line_status <= 1'b1;
            else if (i_start_rx)
                clear_line_status <= 1'b0;
        end 
    end

    //Clear data ready
    always @ (posedge i_clk or posedge i_rst) begin 
        if(i_rst) begin
            clear_data_ready <= 1'b0;
        end else begin
            if (i_clear_rxdataready) 
                clear_data_ready <= 1'b1;
            else if (i_start_rx)
                clear_data_ready <= 1'b0;
        end 
    end
    
    // Beginning of automatic ASCII enum decoding
     reg [167:0]         state_ASCII;            // Decode of state
     always @(state) begin
         case ({state})
             IDLE_STATE:            state_ASCII = "idle_state           ";
             START_DETECT_STATE:    state_ASCII = "start_detect_state   ";
             SAMPLE_START_STATE:    state_ASCII = "sample_start_state   ";
             Rx_1BIT_STATE:         state_ASCII = "rx_1bit_state        ";
             Rx_2BIT_STATE:         state_ASCII = "rx_2bit_state        ";
             Rx_3BIT_STATE:         state_ASCII = "rx_3bit_state        ";
             Rx_4BIT_STATE:         state_ASCII = "rx_4bit_state        ";
             Rx_5BIT_STATE:         state_ASCII = "rx_5bit_state        ";
             Rx_6BIT_STATE:         state_ASCII = "rx_6bit_state        ";
             Rx_7BIT_STATE:         state_ASCII = "rx_7bit_state        ";
             Rx_8BIT_STATE:         state_ASCII = "rx_8bit_state        ";
             PARITY_CHECK_STATE:    state_ASCII = "parity_check_state   ";
             STOP_DETECT_STATE:     state_ASCII = "stop_detect_state    ";
             default:               state_ASCII = "%Error               ";
         endcase
    end
     // End of automatics
     
   assign bit_sample_en = rx_sample_en ;
        
endmodule

