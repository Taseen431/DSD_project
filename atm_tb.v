`timescale 1ns / 1ps
//============================================================================
// ATM Testbench - Version 2
// Tests: Card insert, PIN (hashed), Balance, Deposit, Withdraw,
//        Transaction Inquiry, Change PIN, Wrong PIN lockout,
//        Insufficient funds
//============================================================================

module atm_tb;

    reg         clk;
    reg  [15:0] sw;
    reg         btnC, btnU, btnD, btnL, btnR;

    wire [15:0] led;
    wire [ 6:0] seg;
    wire        dp;
    wire [ 3:0] an;

    // Instantiate DUT
    atm_top DUT (
        .clk(clk), .sw(sw),
        .btnC(btnC), .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .led(led), .seg(seg), .dp(dp), .an(an)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Button press task (15ms hold for debouncer)
    localparam PRESS_HOLD   = 15_000_000;
    localparam RELEASE_WAIT =  5_000_000;

    task press_button;
        input integer btn;
        begin
            case (btn)
                0: btnC = 1;
                1: btnU = 1;
                2: btnD = 1;
                3: btnL = 1;
                4: btnR = 1;
            endcase
            #PRESS_HOLD;
            case (btn)
                0: btnC = 0;
                1: btnU = 0;
                2: btnD = 0;
                3: btnL = 0;
                4: btnR = 0;
            endcase
            #RELEASE_WAIT;
        end
    endtask

    // Main test
    initial begin
        sw = 16'd0;
        btnC = 0; btnU = 0; btnD = 0; btnL = 0; btnR = 0;

        // Wait for power-on reset
        #10_000_000;

        $display("========================================");
        $display("  ATM v2 - Simulation with PIN Hashing");
        $display("========================================");

        //--- Test 1: Insert Card ---
        $display("\n[TEST 1] Insert Card");
        press_button(4);  // btnR
        $display("  LEDs: %016b", led);

        //--- Test 2: Select User 0 ---
        $display("\n[TEST 2] Select User 0");
        sw = 16'd0;
        #1_000_000;
        press_button(0);  // btnC
        $display("  LEDs: %016b", led);

        //--- Test 3: Enter PIN 1234 (will be hashed internally) ---
        $display("\n[TEST 3] Enter PIN 1234 (hashed verification)");
        sw = 16'd1234;
        #1_000_000;
        press_button(0);  // btnC
        #10_000_000;      // Wait for hash + verify
        $display("  LEDs: %016b", led);

        //--- Test 4: Check Balance ---
        $display("\n[TEST 4] Check Balance (menu item 0)");
        press_button(0);  // btnC on Balance
        $display("  LEDs: %016b", led);
        press_button(0);  // Back to menu

        //--- Test 5: Deposit 500 ---
        $display("\n[TEST 5] Deposit 500");
        press_button(2);  // btnD to Deposit (item 1)
        press_button(0);  // Select
        sw = 16'd500;
        #1_000_000;
        press_button(0);  // Confirm
        #100_000_000;     // Wait for success
        $display("  LEDs: %016b", led);

        //--- Test 6: Withdraw 200 ---
        $display("\n[TEST 6] Withdraw 200");
        press_button(2);  // Down to Deposit
        press_button(2);  // Down to Withdraw (item 2)
        press_button(0);  // Select
        sw = 16'd200;
        #1_000_000;
        press_button(0);  // Confirm
        #200_000_000;     // Wait for dispense + success
        $display("  LEDs: %016b", led);

        //--- Test 7: Transaction Inquiry ---
        $display("\n[TEST 7] Transaction Inquiry");
        press_button(2);  // Down to Deposit
        press_button(2);  // Down to Withdraw
        press_button(2);  // Down to History (item 3)
        press_button(0);  // Select
        #5_000_000;
        $display("  LEDs: %016b  (viewing history)", led);
        // Navigate history
        press_button(2);  // btnD = next entry
        #5_000_000;
        press_button(0);  // Back to menu

        //--- Test 8: Change PIN to 4321 ---
        $display("\n[TEST 8] Change PIN to 4321");
        press_button(2);  // Down to Deposit
        press_button(2);  // Down to Withdraw
        press_button(2);  // Down to History
        press_button(2);  // Down to Change PIN (item 4)
        press_button(0);  // Select
        sw = 16'd4321;    // New PIN
        #1_000_000;
        press_button(0);  // Confirm new PIN
        #100_000_000;     // Wait for success
        $display("  LEDs: %016b  (PIN changed)", led);

        //--- Test 9: Exit ---
        $display("\n[TEST 9] Exit");
        press_button(2);  // Down x5 to Exit
        press_button(2);
        press_button(2);
        press_button(2);
        press_button(2);
        press_button(0);  // Confirm Exit
        #200_000_000;
        $display("  LEDs: %016b  (IDLE)", led);

        //--- Test 10: Login with NEW PIN 4321 ---
        $display("\n[TEST 10] Login with new PIN 4321");
        press_button(4);  // Insert card
        sw = 16'd0;       // User 0
        #1_000_000;
        press_button(0);  // Confirm user
        sw = 16'd4321;    // New PIN
        #1_000_000;
        press_button(0);  // Confirm PIN
        #10_000_000;
        $display("  LEDs: %016b  (should be in MENU if PIN works)", led);

        // Check balance (should be 5300 = 5000 + 500 - 200)
        press_button(0);  // Check Balance
        #5_000_000;
        $display("  Balance check after PIN change");

        // Exit
        press_button(0);  // Back
        press_button(2); press_button(2); press_button(2);
        press_button(2); press_button(2);
        press_button(0);  // Exit
        #200_000_000;

        //--- Test 11: Old PIN should fail ---
        $display("\n[TEST 11] Old PIN 1234 should FAIL");
        press_button(4);  // Insert card
        sw = 16'd0;
        #1_000_000;
        press_button(0);  // User 0
        sw = 16'd1234;    // OLD PIN
        #1_000_000;
        press_button(0);  // Confirm
        #150_000_000;
        $display("  LEDs: %016b  (should show ERROR)", led);

        #200_000_000;

        //--- Test 12: Insufficient funds ---
        $display("\n[TEST 12] Insufficient funds");
        press_button(4);  // Insert card
        sw = 16'd3;       // User 3
        #1_000_000;
        press_button(0);
        sw = 16'd9999;    // User 3 PIN
        #1_000_000;
        press_button(0);
        #10_000_000;

        // Withdraw 9000 from 1500 balance
        press_button(2);  // Deposit
        press_button(2);  // Withdraw
        press_button(0);  // Select
        sw = 16'd9000;
        #1_000_000;
        press_button(0);  // Confirm
        #150_000_000;
        $display("  LEDs: %016b  (should show ERROR)", led);

        #200_000_000;

        $display("\n========================================");
        $display("  All Tests Complete at %0t ns", $time);
        $display("========================================");
        $finish;
    end

endmodule
