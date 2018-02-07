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

//`define HS_1                                    //Defines the number of HS (High Speed) Data Lanes;  HS_3 = 4 lanes, HS_2 = 3 lanes, HS_1 = 2 lanes, HS_0 = 1 lanes        
//`define LP_CLK                                  //Defines IO control for the LP (Low Power) Clock Lane                                                                     
//`define LP_0                                    //Defines IO control for the LP (Low Power) Data Lane 0                                                                    
//`define LP_1                                    //Defines IO control for the LP (Low Power) Data Lane 1                                                                    
//`define LP_2                                    //Defines IO control for the LP (Low Power) Data Lane 2                                                                    
//`define LP_3                                    //Defines IO control for the LP (Low Power) Data Lane 3   
//`define PLL                                     //adds PLL within the DPHY TX module   
`define HS_0
`define LP_0
`define LP_CLK
`define COLOR_BAR