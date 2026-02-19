/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
    assign uio_oe  = 8'b00100000;


    RangeFinder #(.WIDTH(8)) RF(.data_in(ui_in), .clock(clk), .reset(~rst_n), .go(uio_oe[7]), .finish(uio_oe[6]),
                                .range(ou_out),.error(uio_oe[5]));

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule

// Code your design here
module Register 
  #(parameter WIDTH = 16)
  (input logic [WIDTH - 1:0] D,
   input logic clock, en, clear, 
   output logic [WIDTH - 1:0] Q);

  always_ff @(posedge clock) begin 
    if (en)
      Q <= D; 
    else if (clear)
      Q <= '0;
  end
endmodule 

module MagComp
  #(parameter WIDTH = 16)
  (input logic [WIDTH - 1:0] A, B,
   output logic AltB, AeqB, AgtB);

  assign AltB = A < B;
  assign AeqB = A == B; 
  assign AgtB = A > B; 
endmodule

module RangeFinder
   #(parameter WIDTH=16)
    (input  logic [WIDTH-1:0] data_in,
     input  logic             clock, reset,
     input  logic             go, finish,
     output logic [WIDTH-1:0] range,
     output logic             error);

     logic [WIDTH-1:0]max,min;
     logic inStart, enMax, enMin;

     RangeFinderDataPath datapath(data_in,clock,reset,inStart,enMax,enMin,go,finish,max,min);
     RangeFinderFSM FSM(data_in, max, min, clock, reset, go , finish, range,final_max,final_min, error, inStart, enMax, enMin);
endmodule: RangeFinder


module RangeFinderDataPath
   #(parameter WIDTH=16)
    (input  logic [WIDTH-1:0] data_in,
     input  logic             clock, reset,inStart, enMax,enMin,
     input  logic             go, finish,
     output logic [WIDTH-1:0] max, min);
   
    Register low(data_in,clock,inStart||enMin,1'b0,min);
    Register high(data_in,clock,inStart||enMax,1'b0,max);
endmodule: RangeFinderDataPath


module RangeFinderFSM
   #(parameter WIDTH=16)
  (input  logic [WIDTH-1:0] data_in,max,min,
   input  logic             clock, reset,
   input  logic             go, finish,
   output logic [WIDTH-1:0] range,final_max,final_min,
   output logic             error,
   output logic inStart, enMax,enMin);

   enum logic [1:0] {START,CONTINUE, ERROR, DONE} currState, nextState;
   // Output logic
  always_comb begin 
  error = 1'b0;
  inStart=1'b0;
  enMin=1'b0;
  enMax=1'b0;

  case (currState)
    START: begin
      if (go)
        inStart=1'b1;
    end
     
    ERROR: begin
      error = 1'b1; 
      if (go && !finish)
        enMin= (data_in<min);
        enMax= (data_in>max);
         //inStart= 1'b1;
    end
     
    CONTINUE: begin
      enMin= (data_in<min);
      enMax= (data_in>max);
    end
     
    DONE: begin 
    end
    default: begin
    end
  endcase
end

    // Next State logic
  always_comb begin 
    case (currState)
      START: begin
      if (go && finish)
         nextState=ERROR;
      else if (finish)
          nextState=ERROR;
      else if (go)
           nextState=CONTINUE;
      end 

      CONTINUE: begin
      if (go)
         nextState=ERROR;
      else if (finish)
         nextState=DONE;
      else
         nextState=CONTINUE;
      end 

      ERROR: begin
      if (go && !finish)
         nextState= CONTINUE;
      else 
         nextState= ERROR;
      end
      
      DONE: begin
      nextState= START;
      end

      default: begin
      nextState=START;
      end
    endcase
   
  end
   
  always_ff @(posedge clock) begin
    if (reset) begin 
      currState <= START ;
    end
    else begin
      currState <= nextState ;
    end
  end
   
  assign final_max = (data_in > max) ? data_in : max;
  assign final_min = (data_in < min) ? data_in : min;
  always_ff @(posedge clock or posedge reset) begin
  if (reset)
    range <= '0;
  else if (currState == CONTINUE && finish)
    range <= final_max - final_min;
end
  endmodule
