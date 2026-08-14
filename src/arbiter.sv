module rr_arbiter (
    input clk,
    input rst,
    input [2:0] req,
    output logic [2:0] gnt
);

    logic [2:0] mask;
    
    //Update the mask to give lower priority to the recently granted agent
    always_ff @(posedge clk) begin
        if (rst) begin
            mask <= 3'b111;
        end else begin
            if (gnt[0])      mask <= 3'b110;
            else if (gnt[1]) mask <= 3'b100;
            else if (gnt[2]) mask <= 3'b111;
        end
    end

    logic [2:0] masked_req;
    assign masked_req = req & mask;

    //Strict priority arbiter for masked requests
    logic [2:0] masked_gnt;
    assign masked_gnt[0] = masked_req[0];
    assign masked_gnt[1] = ~masked_req[0] & masked_req[1];
    assign masked_gnt[2] = ~masked_req[0] & ~masked_req[1] & masked_req[2];

    //Strict priority arbiter for unmasked requests (fallback)
    logic [2:0] unmasked_gnt;
    assign unmasked_gnt[0] = req[0];
    assign unmasked_gnt[1] = ~req[0] & req[1];
    assign unmasked_gnt[2] = ~req[0] & ~req[1] & req[2];

    // Final grant decision
    assign gnt = (masked_req != 0) ? masked_gnt : (req != 0 ? unmasked_gnt : 3'b000);

`ifdef FORMAL  //we used `ifdef to hide the verificiation methodology from the synthesizer
    
    // FORMAL VERIFICATION BLOCK
   
    
    // Ensure the tool starts in a valid state by forcing a reset on cycle 0
    reg f_past_valid = 0;
    always @(posedge clk) f_past_valid <= 1;
    always @(*) if (!f_past_valid) assume(rst);

    // Setup default clocking and reset conditions for SVA
    default clocking @(posedge clk); endclocking
    default disable iff (rst);

    // PROPERTY 1: Mutual Exclusion (Safety)
    // The arbiter must NEVER grant more than one request at a time.
    assert property ($onehot0(gnt));

    // PROPERTY 2: Spurious Grant Prevention (Safety)
    // A grant can only be issued if the corresponding request is active.
    assert property (gnt != 0 |-> (gnt & req) == gnt);

    // PROPERTY 3: Work Conservation (Liveness/Efficiency)
    // If there is ANY active request, the arbiter MUST issue a grant.
    assert property (req != 0 |-> gnt != 0);

    // PROPERTY 4: Fairness / Maximum Wait Time (Bounded Liveness)
    // We use auxiliary formal counters to prove that if an agent holds 
    // its request, it will be granted within exactly 2 clock cycles.
    int wait_count_0, wait_count_1, wait_count_2;

    always_ff @(posedge clk) begin
        if (rst || gnt[0] || !req[0]) wait_count_0 <= 0;
        else wait_count_0 <= wait_count_0 + 1;

        if (rst || gnt[1] || !req[1]) wait_count_1 <= 0;
        else wait_count_1 <= wait_count_1 + 1;

        if (rst || gnt[2] || !req[2]) wait_count_2 <= 0;
        else wait_count_2 <= wait_count_2 + 1;
    end

    // Assert that no request ever waits more than 2 cycles without a grant
    assert property (wait_count_0 <= 2);
    assert property (wait_count_1 <= 2);
    assert property (wait_count_2 <= 2);

`endif

endmodule