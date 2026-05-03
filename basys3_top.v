`timescale 1ns / 1ps

module basys3_top (
    input wire clk,         // 100MHz clock from Basys 3
    input wire btnC,        // Center Button (Reset)
    input wire btnU,        // Up Button (Start Encryption)
    output reg [15:0] led   // 16 LEDs on the board
);

    // Convert active-high physical button to active-low reset for the AES core
    wire reset_n = ~btnC;

    // Memory mapped bus signals
    reg cs, we;
    reg [7:0] address;
    reg [31:0] write_data;
    wire [31:0] read_data;

    // Instantiate the AES core
    aes aes_inst (
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs),
        .we(we),
        .address(address),
        .write_data(write_data),
        .read_data(read_data)
    );

    // State machine variables
    reg [5:0] state;
    reg [31:0] res0, res1, res2, res3;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= 0;
            cs <= 0; we <= 0; address <= 0; write_data <= 0;
            led <= 16'b0;
        end else begin
            case (state)
                // Wait for user to press the 'Up' button
                0: begin 
                    cs <= 0; we <= 0;
                    if (btnU) state <= 1; 
                end

                // --- WRITE 128-BIT NIST TEST KEY ---
               // --- WRITE NEW 128-BIT KEY ---
                1: begin cs<=1; we<=1; address<=8'h10; write_data<=32'h00010203; state<=2; end 
                2: begin cs<=1; we<=1; address<=8'h11; write_data<=32'h04050607; state<=3; end 
                3: begin cs<=1; we<=1; address<=8'h12; write_data<=32'h08090a0b; state<=4; end 
                4: begin cs<=1; we<=1; address<=8'h13; write_data<=32'h0c0d0e0f; state<=5; end
                // Zero-out the unused 256-bit key registers (Safety measure)
                5: begin cs<=1; we<=1; address<=8'h14; write_data<=32'h00000000; state<=6; end 
                6: begin cs<=1; we<=1; address<=8'h15; write_data<=32'h00000000; state<=7; end 
                7: begin cs<=1; we<=1; address<=8'h16; write_data<=32'h00000000; state<=8; end 
                8: begin cs<=1; we<=1; address<=8'h17; write_data<=32'h00000000; state<=9; end 

                // --- CONFIGURE & INITIALIZE KEY EXPANSION ---
                // Config: Encrypt mode (0), 128-bit key (0) -> write '1' to encdec bit
                9:  begin cs<=1; we<=1; address<=8'h0a; write_data<=32'h00000001; state<=10; end 
                // Ctrl: Set init bit to start key expansion
                10: begin cs<=1; we<=1; address<=8'h08; write_data<=32'h00000001; state<=11; end 
                
                // CRITICAL FIX: Give the AES core a few clock cycles to drop its 'ready' flag 
                // before we start checking it, preventing the race condition.
                11: begin cs<=0; we<=0; state<=12; end 
                12: begin state<=13; end
                13: begin state<=14; end
                14: begin state<=15; end

                // --- POLL STATUS UNTIL READY ---
                15: begin cs<=1; we<=0; address<=8'h09; state<=16; end 
                16: begin if (read_data[0]) state <= 17; else state <= 15; end 

                // --- WRITE 128-BIT NIST PLAINTEXT BLOCK ---
               // --- WRITE NEW 128-BIT PLAINTEXT BLOCK ---
                17: begin cs<=1; we<=1; address<=8'h20; write_data<=32'h00112233; state<=18; end 
                18: begin cs<=1; we<=1; address<=8'h21; write_data<=32'h44556677; state<=19; end 
                19: begin cs<=1; we<=1; address<=8'h22; write_data<=32'h8899aabb; state<=20; end 
                20: begin cs<=1; we<=1; address<=8'h23; write_data<=32'hccddeeff; state<=21; end

                // --- START ENCRYPTION ---
                // Ctrl: Set 'next' bit to start encryption round
                21: begin cs<=1; we<=1; address<=8'h08; write_data<=32'h00000002; state<=22; end 

                // CRITICAL FIX: Give the AES core a few clock cycles to drop its 'valid' flag
                22: begin cs<=0; we<=0; state<=23; end
                23: begin state<=24; end
                24: begin state<=25; end
                25: begin state<=26; end

                // --- POLL STATUS UNTIL VALID ---
                26: begin cs<=1; we<=0; address<=8'h09; state<=27; end
                27: begin if (read_data[1]) state <= 28; else state <= 26; end

                // --- READ RESULTS ---
                28: begin cs<=1; we<=0; address<=8'h30; state<=29; end
                29: begin res0 <= read_data; address<=8'h31; state<=30; end
                30: begin res1 <= read_data; address<=8'h32; state<=31; end
                31: begin res2 <= read_data; address<=8'h33; state<=32; end
                32: begin res3 <= read_data; state<=33; end

                // --- VERIFY & OUTPUT FOR PROFESSOR ---
                // --- VERIFY & OUTPUT FOR PROFESSOR ---
                33: begin
                    cs <= 0; we <= 0;
                    
                    // Check against the NEW expected ciphertext
                    if (res0 == 32'h69c4e0d8 && res1 == 32'h6a7b0430 && 
                        res2 == 32'hd8cdb780 && res3 == 32'h70b4c55a) begin
                        
                        // PERFECT MATCH!
                        led[15]   <= 1'b1;          // Far-left LED turns ON (Success indicator)
                        led[14:8] <= 7'b0000000;    // Middle LEDs stay OFF
                        led[7:0]  <= res3[7:0];     // Last 8 LEDs show new ciphertext bits
                        
                    end else begin
                        // FAILURE
                        led <= 16'b1010_1010_1010_1010; 
                    end
                    state <= 34; // Move to holding state
                end

                34: begin
                    // Encryption is done. Wait here infinitely until physical Center Button is pressed.
                end
                
                default: state <= 0;
            endcase
        end
    end
endmodule