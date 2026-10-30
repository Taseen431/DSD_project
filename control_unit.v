`timescale 1ns / 1ps
//============================================================================
// Control Unit (FSM) - Updated ATM State Machine
// Now includes: Change PIN, Transaction Inquiry, PIN Hashing
// Menu: Balance | Deposit | Withdraw | History | Change PIN | Exit
// Interfaces with: Register File, ROM, LED Controller, PIN Hash
//============================================================================

module control_unit(
    input             clk,
    input             reset,
    input      [15:0] sw,
    input             btnC,
    input             btnU,
    input             btnD,
    input             btnL,
    input             btnR,
    input             tick_10ms,

    // ALU interface
    input      [15:0] alu_result,
    input             zero_flag,
    input             negative_flag,
    output reg [15:0] alu_a,
    output reg [15:0] alu_b,
    output reg [ 2:0] alu_op,

    // Memory (RAM) interface
    input      [15:0] mem_rdata,
    output reg        mem_read,
    output reg        mem_write,
    output reg [ 4:0] mem_addr,
    output reg [15:0] mem_wdata,

    // PIN Hash interface
    input      [15:0] hash_out,      // Hashed value from pin_hash module
    output reg [15:0] hash_pin_in,   // Raw PIN to be hashed

    // Register File interface
    output reg        rf_wr_entered_pin,
    output reg        rf_wr_stored_hash,
    output reg        rf_wr_balance,
    output reg        rf_wr_tx_amount,
    output reg        rf_wr_alu_result,
    output reg        rf_wr_new_hash,
    output reg [15:0] rf_din_entered_pin,
    output reg [15:0] rf_din_stored_hash,
    output reg [15:0] rf_din_balance,
    output reg [15:0] rf_din_tx_amount,
    output reg [15:0] rf_din_alu_result,
    output reg [15:0] rf_din_new_hash,
    input      [15:0] rf_entered_pin,
    input      [15:0] rf_stored_hash,
    input      [15:0] rf_current_balance,
    input      [15:0] rf_tx_amount,
    input      [15:0] rf_alu_result_reg,
    input      [15:0] rf_new_pin_hash,
    output reg        rf_clear,

    // Display
    output reg [ 3:0] display_mode,
    output reg [15:0] display_data,

    // LED Controller
    output reg [ 3:0] led_mode,
    output     [ 3:0] current_state_out,

    // Timeout
    input             timeout_expired,
    output reg        timeout_reset
);

    //------------------------------------------------------------------------
    // State Encoding (16 states now, need 4 bits)
    //------------------------------------------------------------------------
    localparam S_IDLE           = 4'd0;
    localparam S_USER_SELECT    = 4'd1;
    localparam S_PIN_ENTRY      = 4'd2;
    localparam S_PIN_VERIFY     = 4'd3;
    localparam S_PIN_RESULT     = 4'd4;
    localparam S_MAIN_MENU      = 4'd5;
    localparam S_CHECK_BALANCE  = 4'd6;
    localparam S_WITHDRAW       = 4'd7;
    localparam S_DEPOSIT        = 4'd8;
    localparam S_TRANSACTION    = 4'd9;
    localparam S_DISPENSE       = 4'd10;
    localparam S_ERROR          = 4'd11;
    localparam S_SUCCESS        = 4'd12;
    localparam S_EJECT_CARD     = 4'd13;
    localparam S_CHANGE_PIN     = 4'd14;
    localparam S_TX_INQUIRY     = 4'd15;

    // ALU Operation Codes
    localparam ALU_NOP     = 3'b000;
    localparam ALU_ADD     = 3'b001;
    localparam ALU_SUB     = 3'b010;
    localparam ALU_COMPARE = 3'b011;
    localparam ALU_EQUAL   = 3'b100;

    // LED Modes
    localparam LED_IDLE         = 4'd0;
    localparam LED_STATE        = 4'd1;
    localparam LED_SUCCESS      = 4'd2;
    localparam LED_ERROR        = 4'd3;
    localparam LED_DISPENSE     = 4'd4;
    localparam LED_EJECT        = 4'd5;
    localparam LED_CHANGE_PIN   = 4'd6;
    localparam LED_TX_DEPOSIT   = 4'd7;
    localparam LED_TX_WITHDRAW  = 4'd8;

    //------------------------------------------------------------------------
    // Internal Registers
    //------------------------------------------------------------------------
    reg [ 3:0] state;
    reg [ 1:0] user_id;
    reg [ 2:0] menu_selection;     // 0-5 (6 menu items now)
    reg [ 1:0] tx_type;            // 0=none, 1=deposit, 2=withdraw
    reg [ 2:0] pin_attempts;
    reg [ 2:0] sub_step;
    reg [26:0] delay_counter; // Restored to 27 bits to hold 99,999,999 for 1s delays
    reg [ 7:0] history_indices;      // Tracks indices per user
    reg [ 1:0] view_index;
    reg [15:0] current_balance_local; // Local copy for CU operations

    assign current_state_out = state;

    //------------------------------------------------------------------------
    // Main FSM
    //------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state             <= S_IDLE;
            user_id           <= 2'd0;
            menu_selection    <= 3'd0;
            tx_type           <= 2'd0;
            pin_attempts      <= 3'd0;
            sub_step          <= 3'd0;
            delay_counter     <= 27'd0;
            history_indices   <= 8'd0;
            view_index        <= 2'd0;
            current_balance_local <= 16'd0;
            mem_read          <= 1'b0;
            mem_write         <= 1'b0;
            mem_addr          <= 5'd0;
            mem_wdata         <= 16'd0;
            alu_a             <= 16'd0;
            alu_b             <= 16'd0;
            alu_op            <= ALU_NOP;
            hash_pin_in       <= 16'd0;
            rf_wr_entered_pin <= 1'b0;
            rf_wr_stored_hash <= 1'b0;
            rf_wr_balance     <= 1'b0;
            rf_wr_tx_amount   <= 1'b0;
            rf_wr_alu_result  <= 1'b0;
            rf_wr_new_hash    <= 1'b0;
            rf_din_entered_pin <= 16'd0;
            rf_din_stored_hash <= 16'd0;
            rf_din_balance    <= 16'd0;
            rf_din_tx_amount  <= 16'd0;
            rf_din_alu_result <= 16'd0;
            rf_din_new_hash   <= 16'd0;
            rf_clear          <= 1'b1;
            display_mode      <= 4'd7;
            display_data      <= 16'd0;
            led_mode          <= LED_IDLE;
            timeout_reset     <= 1'b1;
        end else begin
            // Defaults each cycle
            mem_read          <= 1'b0;
            mem_write         <= 1'b0;
            alu_op            <= ALU_NOP;
            timeout_reset     <= 1'b0;
            rf_wr_entered_pin <= 1'b0;
            rf_wr_stored_hash <= 1'b0;
            rf_wr_balance     <= 1'b0;
            rf_wr_tx_amount   <= 1'b0;
            rf_wr_alu_result  <= 1'b0;
            rf_wr_new_hash    <= 1'b0;
            rf_clear          <= 1'b0;



            // Timeout check
            if (timeout_expired && state != S_IDLE) begin
                state    <= S_EJECT_CARD;
                display_mode  <= 4'd5;
                display_data  <= 16'd0;
                sub_step      <= 3'd0;
                delay_counter <= 24'd0;
                led_mode      <= LED_ERROR;
            end else begin

                case (state)
                    //--------------------------------------------------------
                    // IDLE
                    //--------------------------------------------------------
                    S_IDLE: begin
                        display_mode <= 4'd7;     // "IdLE"
                        display_data <= 16'd0;
                        led_mode     <= LED_IDLE;
                        pin_attempts <= 3'd0;
                        sub_step     <= 3'd0;
                        rf_clear     <= 1'b1;     // Clear register file

                        if (btnR) begin
                            state    <= S_USER_SELECT;
                            timeout_reset <= 1'b1;
                            rf_clear      <= 1'b0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end

                    //--------------------------------------------------------
                    // USER_SELECT
                    //--------------------------------------------------------
                    S_USER_SELECT: begin
                        display_mode <= 4'd8;
                        display_data <= {14'd0, sw[1:0]};
                        led_mode     <= LED_STATE;

                        if (btnC) begin
                            user_id       <= sw[1:0];
                            state    <= S_PIN_ENTRY;
                            timeout_reset <= 1'b1;
                        end else if (btnL) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_USER_SELECT;
                        end
                    end

                    //--------------------------------------------------------
                    // PIN_ENTRY - Enter PIN, hash it before storing
                    //--------------------------------------------------------
                    S_PIN_ENTRY: begin
                        display_mode <= 4'd1;     // "----"
                        display_data <= 16'd0;
                        led_mode     <= LED_STATE;

                        // Always feed current switch value to hash module
                        hash_pin_in <= sw;

                        if (btnC) begin
                            // Store raw PIN in register file
                            rf_wr_entered_pin  <= 1'b1;
                            rf_din_entered_pin <= sw;
                            // Start reading stored hashed PIN from memory
                            mem_read           <= 1'b1;
                            mem_addr           <= {user_id, 3'b000};
                            sub_step           <= 3'd0;
                            state         <= S_PIN_VERIFY;
                            timeout_reset      <= 1'b1;
                        end else if (btnL) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_PIN_ENTRY;
                        end
                    end

                    //--------------------------------------------------------
                    // PIN_VERIFY - Compare hashed PINs
                    //--------------------------------------------------------
                    S_PIN_VERIFY: begin
                        led_mode <= LED_STATE;

                        case (sub_step)
                            3'd0: begin
                                // Cycle 0: Re-issue memory read, feed raw PIN to hasher
                                mem_read    <= 1'b1;
                                mem_addr    <= {user_id, 3'b000};
                                hash_pin_in <= rf_entered_pin;
                                sub_step    <= 3'd1;
                                state  <= S_PIN_VERIFY;
                            end
                            3'd1: begin
                                // Cycle 1: Memory data now available, hash_out now valid
                                // Feed raw PIN to hash again to ensure stable output
                                hash_pin_in <= rf_entered_pin;
                                sub_step    <= 3'd2;
                                state  <= S_PIN_VERIFY;
                            end
                            3'd2: begin
                                // Cycle 2: Latch both values into register file
                                rf_wr_stored_hash  <= 1'b1;
                                rf_din_stored_hash <= mem_rdata;   // From memory
                                rf_wr_entered_pin  <= 1'b1;
                                rf_din_entered_pin <= hash_out;    // Hashed PIN
                                sub_step   <= 3'd3;
                                state <= S_PIN_VERIFY;
                            end
                            3'd3: begin
                                // Cycle 3: Wait one cycle for register file to update
                                sub_step   <= 3'd4;
                                state <= S_PIN_VERIFY;
                            end
                            3'd4: begin
                                // Cycle 4: Now compare - register file values are valid
                                alu_a  <= rf_entered_pin;    // Hashed entered PIN
                                alu_b  <= rf_stored_hash;    // Stored hashed PIN
                                alu_op <= ALU_EQUAL;
                                sub_step   <= 3'd5;
                                state <= S_PIN_VERIFY;
                            end
                            3'd5: begin
                                // Cycle 5: Check ALU result
                                sub_step <= 3'd0;
                                if (zero_flag) begin
                                    // PIN correct - read balance
                                    mem_read   <= 1'b1;
                                    mem_addr   <= {user_id, 3'b001};
                                    state <= S_PIN_RESULT;
                                end else begin
                                    pin_attempts <= pin_attempts + 1'b1;
                                    if (pin_attempts >= 3'd2) begin
                                        state <= S_EJECT_CARD;
                                    end else begin
                                        state    <= S_ERROR;
                                        delay_counter <= 24'd0;
                                    end
                                end
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_PIN_VERIFY;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // PIN_RESULT - Latch balance
                    //--------------------------------------------------------
                    S_PIN_RESULT: begin
                        case (sub_step)
                            3'd0: begin
                                mem_read   <= 1'b1;
                                mem_addr   <= {user_id, 3'b001};
                                sub_step   <= 3'd1;
                                state <= S_PIN_RESULT;
                            end
                            3'd1: begin
                                rf_wr_balance  <= 1'b1;
                                rf_din_balance <= mem_rdata;
                                current_balance_local <= mem_rdata;
                                sub_step       <= 3'd0;
                                state     <= S_MAIN_MENU;
                                menu_selection <= 3'd0;
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_MAIN_MENU;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // MAIN_MENU - 6 options now
                    //   0: Balance, 1: Deposit, 2: Withdraw,
                    //   3: Transaction Inquiry, 4: Change PIN, 5: Exit
                    //--------------------------------------------------------
                    S_MAIN_MENU: begin
                        display_mode <= 4'd4;
                        display_data <= {13'd0, menu_selection};
                        led_mode     <= LED_STATE;

                        if (btnU) begin
                            if (menu_selection > 3'd0)
                                menu_selection <= menu_selection - 1'b1;
                            timeout_reset <= 1'b1;
                            state    <= S_MAIN_MENU;
                        end else if (btnD) begin
                            if (menu_selection < 3'd5)
                                menu_selection <= menu_selection + 1'b1;
                            timeout_reset <= 1'b1;
                            state    <= S_MAIN_MENU;
                        end else if (btnC) begin
                            timeout_reset <= 1'b1;
                            sub_step      <= 3'd0;
                            case (menu_selection)
                                3'd0: state <= S_CHECK_BALANCE;
                                3'd1: state <= S_DEPOSIT;
                                3'd2: state <= S_WITHDRAW;
                                3'd3: begin
                                    state    <= S_TX_INQUIRY;
                                    view_index <= history_indices[user_id*2 +: 2] - 1'b1;
                                end
                                3'd4: state <= S_CHANGE_PIN;
                                3'd5: state <= S_EJECT_CARD;
                                default: state <= S_MAIN_MENU;
                            endcase
                        end else if (btnL) begin
                            state <= S_EJECT_CARD;
                        end else begin
                            state <= S_MAIN_MENU;
                        end
                    end

                    //--------------------------------------------------------
                    // CHECK_BALANCE
                    //--------------------------------------------------------
                    S_CHECK_BALANCE: begin
                        display_mode <= 4'd2;
                        display_data <= current_balance_local;
                        led_mode     <= LED_STATE;

                        if (btnC || btnL) begin
                            state    <= S_MAIN_MENU;
                            timeout_reset <= 1'b1;
                        end else begin
                            state <= S_CHECK_BALANCE;
                        end
                    end

                    //--------------------------------------------------------
                    // WITHDRAW
                    //--------------------------------------------------------
                    S_WITHDRAW: begin
                        led_mode <= LED_STATE;

                        case (sub_step)
                            3'd0: begin
                                display_mode <= 4'd3;
                                display_data <= sw;
                                state   <= S_WITHDRAW;

                                if (btnC) begin
                                    rf_wr_tx_amount  <= 1'b1;
                                    rf_din_tx_amount <= sw;
                                    alu_a      <= current_balance_local;
                                    alu_b      <= sw;
                                    alu_op     <= ALU_COMPARE;
                                    sub_step   <= 3'd1;
                                    timeout_reset <= 1'b1;
                                end else if (btnL) begin
                                    state <= S_MAIN_MENU;
                                    sub_step   <= 3'd0;
                                end
                            end
                            3'd1: begin
                                if (negative_flag) begin
                                    state    <= S_ERROR;
                                    sub_step      <= 3'd0;
                                    delay_counter <= 24'd0;
                                end else begin
                                    alu_a  <= current_balance_local;
                                    alu_b  <= rf_din_tx_amount;
                                    alu_op <= ALU_SUB;
                                    sub_step <= 3'd2;
                                    state <= S_WITHDRAW;
                                end
                            end
                            3'd2: begin
                                // Write new balance
                                current_balance_local <= alu_result;
                                rf_wr_balance  <= 1'b1;
                                rf_din_balance <= alu_result;
                                mem_write      <= 1'b1;
                                mem_addr       <= {user_id, 3'b001};
                                mem_wdata      <= alu_result;
                                tx_type        <= 2'd2;
                                sub_step       <= 3'd3;
                                state     <= S_WITHDRAW;
                            end
                            3'd3: begin
                                // Log transaction in history
                                mem_write <= 1'b1;
                                mem_addr  <= {user_id, 1'b1, history_indices[user_id*2 +: 2]}; 
                                mem_wdata <= rf_tx_amount; // Bit 15 is 0 by default for withdrawal
                                history_indices[user_id*2 +: 2] <= history_indices[user_id*2 +: 2] + 1'b1;
                                sub_step  <= 3'd0;
                                state <= S_TRANSACTION;
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_WITHDRAW;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // DEPOSIT
                    //--------------------------------------------------------
                    S_DEPOSIT: begin
                        led_mode <= LED_STATE;

                        case (sub_step)
                            3'd0: begin
                                display_mode <= 4'd3;
                                display_data <= sw;
                                state   <= S_DEPOSIT;

                                if (btnC) begin
                                    rf_wr_tx_amount  <= 1'b1;
                                    rf_din_tx_amount <= sw;
                                    alu_a     <= current_balance_local;
                                    alu_b     <= sw;
                                    alu_op    <= ALU_ADD;
                                    sub_step  <= 3'd1;
                                    timeout_reset <= 1'b1;
                                end else if (btnL) begin
                                    state <= S_MAIN_MENU;
                                    sub_step   <= 3'd0;
                                end
                            end
                            3'd1: begin
                                // Write new balance
                                current_balance_local <= alu_result;
                                rf_wr_balance  <= 1'b1;
                                rf_din_balance <= alu_result;
                                mem_write      <= 1'b1;
                                mem_addr       <= {user_id, 3'b001};
                                mem_wdata      <= alu_result;
                                tx_type        <= 2'd1;
                                sub_step       <= 3'd2;
                                state     <= S_DEPOSIT;
                            end
                            3'd2: begin
                                // Log transaction in history
                                mem_write <= 1'b1;
                                mem_addr  <= {user_id, 1'b1, history_indices[user_id*2 +: 2]};
                                mem_wdata <= rf_tx_amount | 16'h8000; // Flag bit 15 for DEPOSIT
                                history_indices[user_id*2 +: 2] <= history_indices[user_id*2 +: 2] + 1'b1;
                                sub_step  <= 3'd0;
                                state <= S_TRANSACTION;
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_DEPOSIT;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // TRANSACTION - Show confirmation
                    //--------------------------------------------------------
                    S_TRANSACTION: begin
                        led_mode     <= LED_STATE;
                        display_mode <= 4'd2;
                        display_data <= current_balance_local;

                        if (tx_type == 2'd2)
                            state <= S_DISPENSE;
                        else
                            state <= S_SUCCESS;

                        delay_counter <= 24'd0;
                        sub_step      <= 3'd0;
                    end

                    //--------------------------------------------------------
                    // DISPENSE - Cash dispensing animation
                    //--------------------------------------------------------
                    S_DISPENSE: begin
                        led_mode     <= LED_DISPENSE;
                        display_mode <= 4'd2;
                        display_data <= rf_tx_amount;

                        if (delay_counter >= 24'd99_999_999) begin
                            state    <= S_SUCCESS;
                            delay_counter <= 24'd0;
                        end else begin
                            delay_counter <= delay_counter + 1'b1;
                            state    <= S_DISPENSE;
                        end
                    end

                    //--------------------------------------------------------
                    // CHANGE_PIN - Enter new PIN, hash and store
                    //--------------------------------------------------------
                    S_CHANGE_PIN: begin
                        led_mode <= LED_CHANGE_PIN;

                        case (sub_step)
                            3'd0: begin
                                // Show new PIN entry prompt
                                display_mode <= 4'd9;     // "----"
                                display_data <= 16'd0;
                                state   <= S_CHANGE_PIN;
                                hash_pin_in  <= sw;       // Continuously feed switches to hasher

                                if (btnC) begin
                                    hash_pin_in      <= sw;
                                    sub_step         <= 3'd1;
                                    timeout_reset    <= 1'b1;
                                end else if (btnL) begin
                                    state <= S_MAIN_MENU;
                                    sub_step   <= 3'd0;
                                end
                            end
                            3'd1: begin
                                // Wait one cycle for hash to stabilize
                                hash_pin_in <= hash_pin_in;
                                sub_step    <= 3'd2;
                                state  <= S_CHANGE_PIN;
                            end
                            3'd2: begin
                                // Store hashed new PIN in register file
                                rf_wr_new_hash  <= 1'b1;
                                rf_din_new_hash <= hash_out;
                                sub_step        <= 3'd3;
                                state      <= S_CHANGE_PIN;
                            end
                            3'd3: begin
                                // Wait for register file to update
                                sub_step   <= 3'd4;
                                state <= S_CHANGE_PIN;
                            end
                            3'd4: begin
                                // Write hashed PIN to memory (RAM)
                                mem_write <= 1'b1;
                                mem_addr  <= {user_id, 3'b000}; // PIN address
                                mem_wdata <= rf_new_pin_hash;
                                sub_step  <= 3'd0;
                                state <= S_SUCCESS;
                                delay_counter <= 24'd0;
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_CHANGE_PIN;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // TX_INQUIRY - View transaction history
                    //--------------------------------------------------------
                    S_TX_INQUIRY: begin
                        led_mode <= LED_STATE;

                        case (sub_step)
                            3'd0: begin
                                // Read transaction from history
                                mem_read   <= 1'b1;
                                mem_addr   <= {user_id, 1'b1, view_index};
                                sub_step   <= 3'd1;
                                state <= S_TX_INQUIRY;
                            end
                            3'd1: begin
                                // Display the transaction amount
                                display_mode <= 4'd10;     // History numeric
                                display_data <= mem_rdata & 16'h7FFF; // Strip MSB so actual int displays
                                led_mode     <= mem_rdata[15] ? LED_TX_DEPOSIT : LED_TX_WITHDRAW;
                                state   <= S_TX_INQUIRY;
                                sub_step     <= 3'd2;
                            end
                            3'd2: begin
                                // Wait for user navigation
                                display_mode <= 4'd10;
                                display_data <= mem_rdata & 16'h7FFF; // Maintain stripped display
                                led_mode     <= mem_rdata[15] ? LED_TX_DEPOSIT : LED_TX_WITHDRAW;
                                state   <= S_TX_INQUIRY;

                                if (btnU) begin
                                    // Previous transaction
                                    if (view_index > 2'd0)
                                        view_index <= view_index - 1'b1;
                                    sub_step      <= 3'd0;
                                    timeout_reset <= 1'b1;
                                end else if (btnD) begin
                                    // Next transaction
                                    if (view_index < 2'd3)
                                        view_index <= view_index + 1'b1;
                                    sub_step      <= 3'd0;
                                    timeout_reset <= 1'b1;
                                end else if (btnL || btnC) begin
                                    // Back to menu
                                    state <= S_MAIN_MENU;
                                    sub_step   <= 3'd0;
                                    timeout_reset <= 1'b1;
                                end
                            end
                            default: begin
                                sub_step   <= 3'd0;
                                state <= S_TX_INQUIRY;
                            end
                        endcase
                    end

                    //--------------------------------------------------------
                    // SUCCESS
                    //--------------------------------------------------------
                    S_SUCCESS: begin
                        display_mode <= 4'd6;     // "donE"
                        display_data <= 16'd0;
                        led_mode     <= LED_SUCCESS;

                        if (delay_counter >= 24'd99_999_999) begin
                            state     <= S_MAIN_MENU;
                            delay_counter  <= 24'd0;
                            menu_selection <= 3'd0;
                        end else begin
                            delay_counter <= delay_counter + 1'b1;
                            state    <= S_SUCCESS;
                        end
                    end

                    //--------------------------------------------------------
                    // ERROR
                    //--------------------------------------------------------
                    S_ERROR: begin
                        display_mode <= 4'd5;     // "Err"
                        display_data <= 16'd0;
                        led_mode     <= LED_ERROR;

                        if (delay_counter >= 24'd99_999_999) begin
                            delay_counter <= 24'd0;
                            if (pin_attempts < 3'd3)
                                state <= S_PIN_ENTRY;
                            else
                                state <= S_EJECT_CARD;
                        end else begin
                            delay_counter <= delay_counter + 1'b1;
                            state    <= S_ERROR;
                        end
                    end

                    //--------------------------------------------------------
                    // EJECT_CARD
                    //--------------------------------------------------------
                    S_EJECT_CARD: begin
                        display_mode <= 4'd7;     // "IdLE"
                        led_mode     <= LED_EJECT;

                        if (delay_counter >= 24'd99_999_999) begin
                            state    <= S_IDLE;
                            delay_counter <= 24'd0;
                            pin_attempts  <= 3'd0;
                            rf_clear      <= 1'b1; // Clear all temporary data
                        end else begin
                            delay_counter <= delay_counter + 1'b1;
                            state    <= S_EJECT_CARD;
                        end
                    end

                    //--------------------------------------------------------
                    default: begin
                        state <= S_IDLE;
                    end
                endcase
            end // timeout else
        end // reset else
    end // always

endmodule
