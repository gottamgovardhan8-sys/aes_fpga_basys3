`timescale 1ns / 1ps
//======================================================================
// tb_basys3_top.v
// --------
// System-level testbench for the Basys 3 AES hardware wrapper.
// This simulates physical button presses and reads the physical LEDs.
//======================================================================

module tb_basys3_top();

    //----------------------------------------------------------------
    // 1. Declare Signals
    //----------------------------------------------------------------
    reg clk;
    reg btnC;
    reg btnU;
    
    wire [15:0] led;

    //----------------------------------------------------------------
    // 2. Instantiate the Top-Level Module (Device Under Test)
    //----------------------------------------------------------------
    basys3_top dut (
        .clk(clk),
        .btnC(btnC),
        .btnU(btnU),
        .led(led)
    );

    //----------------------------------------------------------------
    // 3. Clock Generation (100 MHz -> 10ns period -> 5ns half-period)
    //----------------------------------------------------------------
    always #5 clk = ~clk;

    //----------------------------------------------------------------
    // 4. Main Simulation Sequence
    //----------------------------------------------------------------
    initial begin
        // Initialize Inputs
        clk = 0;
        btnC = 0;
        btnU = 0;

        $display("--------------------------------------------------");
        $display("--- Starting Basys 3 System-Level Simulation ---");
        $display("--------------------------------------------------");

        // Step A: Simulate pressing the Center Button (Reset)
        $display("[%0t ns] Pressing Center Button (btnC) for Reset...", $time);
        btnC = 1; 
        #40;        // Hold it down for a few clock cycles
        btnC = 0;   // Release
        #40;        // Wait for the system to settle

        // Step B: Simulate pressing the Up Button (Start Encryption)
        $display("[%0t ns] Pressing Up Button (btnU) to start AES state machine...", $time);
        btnU = 1;
        #20;        // Hold it down briefly (2 clock cycles is enough)
        btnU = 0;   // Release

        // Step C: Wait for the hardware state machine to finish
        $display("[%0t ns] Waiting for AES core to process data...", $time);
        
        // The basys3_top module turns on led[15] for success, or led[0] for failure.
        // We will pause the testbench until one of those LEDs lights up.
        wait (led[15] == 1'b1 || led[0] == 1'b1);
        
        // Add a tiny delay just to let the waveform look clean at the end
        #20;

        // Step D: Evaluate the physical LED outputs
        $display("--------------------------------------------------");
        if (led[15] == 1'b1) begin
            $display(" [PASS] SUCCESS! LED[15] turned ON.");
            $display("        The AES core correctly encrypted the NIST test vector.");
            $display("        Ciphertext bits displayed on LED[14:0]: %b", led[14:0]);
        end else if (led[0] == 1'b1) begin
            $display(" [FAIL] FAILURE! LED[0] turned ON.");
            $display("        The output did not match the expected ciphertext.");
        end else begin
            $display(" [ERR]  TIMEOUT! Neither success nor failure LED turned on.");
        end
        $display("--------------------------------------------------");

        // End the simulation
        $finish;
    end

endmodule