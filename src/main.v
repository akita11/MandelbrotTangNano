`define N_ITERATE 100

`define N_PIX_X 192
`define N_PIX_Y 128

// for Q12 format
`define BIT_INT 4
`define BIT_FRAC 12
`define N_BIT 16
`define ONE `N_BIT'b0000_000000000001
`define TH  `N_BIT'b0100_000000000000 // 4.0
`define CXS (~(`N_BIT'b0010_000000000000) + `ONE) // -2.0
`define CXE    `N_BIT'b0001_000000000000          // +1.0
`define CYS (~(`N_BIT'b0001_000000000000) + `ONE) // -1.0
`define CYE    `N_BIT'b0001_000000000000          // +1.0
`define DCX    `N_BIT'b0000_000001000000          // 1/64
`define DCY    `N_BIT'b0000_000001000000          // 1/64

module mandelbrot(
    input   clk,
    input   rst_n,
    input   _DTR, // dummy for FTDI-Basic
    output  TXD,
    input   RXD,
    input   _VDD,  // dummy for FTDI-Basic
    output _CTS, // dummy for FTDI-Basic
    output _GND // dummy for FTDI-Basic
);

  // 921600bps x 8 = 7.3728MHz
   
  // z(n+1) <= z(n)^2 + C, z0=0

  // parallel multipluer
  // https://veri.wiki.fc2.com/wiki/%E7%AC%A6%E5%8F%B7%E4%BB%98%E4%B9%97%E7%AE%97%E5%99%A8

    wire 		       clk;
    wire 		       rst;
   
    reg fIterating;
    reg fResult; // 0 = diversed, 1 = iteration max reached
    reg fFinish;
    reg [3:0] st;
    reg [7:0] i;
    reg [8:0] px, py;
    reg [`N_BIT - 1:0] cx, cy, x, y, xx, yy, ma, mb, sa, sb;
    wire [`N_BIT - 1:0] mp, ss;
    reg 		       f_operating;
    reg [`N_BIT - 1:0]  r_cxs, r_cys, r_dcx, r_dcy;
    reg [7:0] 	       r_pix_x, r_pix_y;
    reg [7:0] 	       t_data;
    wire [7:0] 	       r_data;
    reg 		       t_start;
    wire 	       t_busy, r_ready;
    reg [1:0] 	       f_receiving; 		       
    reg [4:0] 	       n_byte;

    assign _CTS = 0, _GND = 0; // dummy for FTDI-Basic
    assign rst = ~rst_n;
    mult m0(ma, mb, mp);  
    add  a0(sa, sb, ss);

    TX8 tx8(clk, rst, t_data, TXD, t_start, t_busy);
    RX8 rx8(clk, rst, RXD, r_data, r_ready);

    always @(posedge clk) begin
        if (f_receiving == 0 && r_ready == 1) begin
            f_receiving <= 1;
        end
        if (f_receiving == 1) begin
            f_receiving <= 2;
            n_byte <= n_byte + 1;
            if (n_byte == 0) r_pix_x <= r_data;
            if (n_byte == 1) r_pix_y <= r_data;
            if (n_byte == 2) r_cxs[15:8] <= r_data;
            if (n_byte == 3) r_cxs[7:0] <= r_data;
            if (n_byte == 4) r_cys[15:8] <= r_data;
            if (n_byte == 5) r_cys[7:0] <= r_data;
            if (n_byte == 6) r_dcx[15:8] <= r_data;
            if (n_byte == 7) r_dcx[7:0] <= r_data;
            if (n_byte == 8) r_dcy[15:8] <= r_data;
            if (n_byte == 9) r_dcy[7:0] <= r_data;
            if (n_byte == 9) begin
                cx <= r_cxs; cy <= r_cys;
                fFinish <= 0;
                f_operating <= 1;
                fIterating <= 1;
                n_byte <= 0;
            end
        end
        if (f_receiving == 2 && r_ready == 0) begin
            f_receiving <= 0;
        end

        if (f_operating == 1) begin
            if (fIterating == 0) begin
                t_data <= i; t_start <= 1;
            end
            else begin
                t_start <= 0;
            end
        end
        else begin
            t_start <= 0;
        end


        if (rst == 1) begin
//	 cx <= 20'b0001_0000000000000000; cy <= 20'b0000_0000000000000001;
//	 cx <= 20'b1111_0000000000000000; cy <= 20'b0000_0000000000000000;
//	 cx <= 20'b1111_0000000000000000; cy <= 20'b0000_0010000000000000;
            px <= 0; py <= 0; // pixel coordinates
            x <= 0; y <= 0;
            i <= 0; fIterating <= 0; st <= 0; fResult <= 0; fFinish <= 1;
            t_start <= 0;
            t_data <= 0;
            f_receiving <= 0;
            f_operating <= 0;
            n_byte <= 0;
            cx <= 0; cy <= 0;
            r_cxs <= 0; r_cys <= 0;
            r_dcx <= 0; r_dcy <= 0;
            r_pix_x <= 0; r_pix_y <= 0;
        end
        else if (f_operating == 1) begin
        // xx = x * x - y * y + cx
        // yy = 2 * x * y + cy

        // st ma mb sa sb  -> mp=ma*mb  ss=sa+sb
        // 0  x  x  0  0      0         0
        // 1  -y y  mp cx     mp=x*x    0
        // 2  2x y  mp ss     mp=-y*y   ss=x*x + cx 
        // 3  0  0  mp cy     mp=2*x*y  ss=x*x-y*y+cx -> xx
        // 4  0  0  0  0      0         ss=2*x*y+cy -> yy

        // st 0   1       2          3              4
        // ma x   -y      2x
        // mb x   y       y
        // mp -   x*x     -y*y       2*x*y
        // sa     mp=x*x  mp=-y*y    mp=2*x*y
        // sb     cx      ss=x*x+cx  cy
        // ss             x*x+cx     x*x-y*y+cx=xx  2*x*y+cy=yy
            if (fIterating == 1) begin
                case (st)
                    0 : begin ma <= x;    mb <= x; sa <= 0;  sb <= 0;  st <= 1; end
                    1 : begin ma <= ~y+1; mb <= y; sa <= mp; sb <= cx; st <= 2; end
                    2 : begin ma <= x<<1; mb <= y; sa <= mp; sb <= ss; st <= 3; end
                    3 : begin ma <= 0;    mb <= 0; sa <= mp; sb <= cy; st <= 4; xx <= ss; end
                    4 : begin ma <= 0;    mb <= 0; sa <= 0;  sb <= 0;  st <= 5; yy <= ss; end
                    5 : begin
                            sa <= (xx[`N_BIT - 1] == 0)?xx:(~xx+1);
                            sb <= (yy[`N_BIT - 1] == 0)?yy:(~yy+1);
                            x <= xx; y <= yy;
                            st <= 6;
                        end
                    6: begin
                            st <= 0;
                            if (ss >= `TH) begin fIterating <= 0; fResult <= 0; end
                            else begin
                                i <= i + 1;
                                if (i == `N_ITERATE - 1) begin
                                    fIterating <= 0; fResult <= 1; 
                                end
                            end
                        end
                endcase
            end
            else begin
                if (t_busy == 1) begin
                end
                else begin
                    // result obtained
                    fIterating <= 1;
                    i <= 0;
                    x <= 0; y <= 0;
                    // cx&cy update
	    
                    // pixel coornidate update
                    py <= py + 1;
                    cy <= cy + r_dcy;
                    if (py == r_pix_y - 1) begin
                        py <= 0;
                        cy <= r_cys;
                        px <= px + 1;
                        cx <= cx + r_dcx;
                        if (px == r_pix_x - 1) begin
                            fFinish <= 1;
                            f_operating <= 0;
                            px <= 0;
                        end
                    end
                end
            end
        end
    end 
endmodule

module add(a, b, x);
   input [`N_BIT - 1:0] a, b;
   output [`N_BIT - 1:0] x;
   assign x = a + b;
endmodule

module mult(a, b, x);
   input [`N_BIT - 1:0] a, b;
   output [`N_BIT - 1:0] x;
   wire [`N_BIT - 1:0] 	 a0, b0;
   wire [2*`N_BIT - 1:0] x_tmp;
   wire 		 sa, sb;
   // 0x10000 x 0x10000 = 0x10000_0000
   // 0x1.0000 x 0x1.0000 = 0x1.0000
   assign sa = a[`N_BIT - 1];
   assign sb = b[`N_BIT - 1];
   assign a0 = (sa == 0)?a:(~a+1);
   assign b0 = (sb == 0)?b:(~b+1);
   assign x_tmp = ((sa ^ sb) == 0)?(a0 * b0):(~(a0 * b0) + 1);
   assign x = x_tmp[`BIT_FRAC + `N_BIT - 1:`BIT_FRAC];
endmodule

module TX8(clk, rst, data, txd, start, busy);
    input clk, rst, start;
    input [7:0] data;
    output      txd, busy;
    reg [4:0]   cnt;
    reg [3:0]   n_bit;
    reg 	       r_busy;
    reg [9:0]   tdata;
    assign txd = tdata[0], busy = r_busy;
   
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            cnt <= 0; n_bit <= 0;
            r_busy <= 0;
            tdata <= 10'b1111111111;
        end
        else begin
            if (r_busy == 0 && start == 1) begin
                r_busy <= 1;
                tdata <= {1'b1, data, 1'b0};
            end
            if (r_busy == 1) begin
                cnt <= cnt + 1;
                if (cnt == 25) begin // 24MHz / 26 = 923,077<-> 921,600bps
                    cnt <= 0;
                    n_bit <= n_bit + 1;
                    tdata[9:0] <= {1'b0, tdata[9:1]};
                    if (n_bit == 9) begin
                        r_busy <= 0;
                        n_bit <= 0;
                        cnt <= 0;
                        tdata <= 10'b1111111111;
                    end
                end
            end
        end
    end
endmodule

module RX8(clk, rst, rxd, data, ready);
    input clk, rst, rxd;
    output [7:0] data;
    output 	ready;
    reg [4:0]   cnt;
    reg [3:0]   n_bit;
    reg [9:0]   rdata;
    reg [2:0]   rxdb0; // @bit=5, 12, 19
    reg 	       rxdb;
    reg 	       r_ready;
    reg [7:0]   data;
   
    assign ready = r_ready;

    always @(rxdb0) begin
        case (rxdb0)
            3'b000 : rxdb <= 0;
            3'b001 : rxdb <= 0;
            3'b010 : rxdb <= 0;
            3'b011 : rxdb <= 1;
            3'b100 : rxdb <= 0;
            3'b101 : rxdb <= 1;
            3'b110 : rxdb <= 1;
            3'b111 : rxdb <= 1;
        endcase
    end
   
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            cnt <= 0; n_bit <= 0;
            r_ready <= 0;
            rdata <= 0; rxdb0 <= 0; rxdb <= 0;
            data <= 0;
        end
        else begin
            if (n_bit == 0 && rxd == 0) begin
                n_bit <= 1;
            end
            if (n_bit != 0) begin
                cnt <= cnt + 1;
                if (cnt == 5) rxdb0[0] <= rxd;
                if (cnt == 12) rxdb0[1] <= rxd;
                if (cnt == 19) rxdb0[2] <= rxd;
                if (cnt == 25) begin // 24MHz / 26 = 923,077<-> 921,600bps
                    cnt <= 0;
                    n_bit <= n_bit + 1;
                    rdata[9:0] <= {rxdb, rdata[9:1]};
                    if (n_bit == 9) begin
                        r_ready <= 0;
                    end
                    if (n_bit == 10) begin
                        data <= rdata[9:2];
                        r_ready <= 1;
                        n_bit <= 0;
                        cnt <= 0;
                    end
                end
            end
        end
    end
endmodule
