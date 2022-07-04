`default_nettype none

module dlyecho (
    input   wire             clk,
    input   wire             reset,

    // input from fifo
    input   wire [15:0]      din,
    output  logic            request_to_read_input_fifo,
    input   wire             is_input_fifo_empty,

    // output to fifo
    output  logic [15:0]     signal_with_effect,
    output  logic            request_to_write_output_fifo,
    output  logic [15:0]     signal_through,
    output  logic [15:0]     signal_effect_only
);

    // input reg
    logic [15:0]            sigsample_latest;

    // unsigned intermediate variables
    bit [15:0]              effect16;
    bit [15:0]              signal_with_effect16;

    // signed intermediate variables
    bit signed [15:0]       echo_old1, echo_old2, echo_old3;
    bit signed [31:0]       o1, o2, o3;
    bit signed [31:0]       effect32;
    bit signed [31:0]       signal_with_effect32;

    // state machine
    logic [7:0]     counter;
    logic [7:0]     n_counter;

    // ring buffer handler
    logic [14:0]    ringbuf_addr_next_to_write;

    logic           ringbuf_enable;
    logic           ringbuf_en_wr, ringbuf_en_rd_echo1, ringbuf_en_rd_echo2, ringbuf_en_rd_echo3;

    logic           ringbuf_we;

    logic [14:0]    ringbuf_addr;
    logic [14:0]    ringbuf_addr_wr, ringbuf_addr_echo1, ringbuf_addr_echo2, ringbuf_addr_echo3;

    logic [15:0]    ringbuf_din;
    logic [15:0]    ringbuf_dout;


    //bram by ip catalog
    blk_mem_sig_buffer u_ringbuf (
        .clka(clk),    // input wire clka
        .ena(ringbuf_enable),      // input wire ena             active high  when to read, (ena, wea)=(1,0)
        .wea(ringbuf_we),      // input wire [0 : 0] wea     active high  when to write, (ena, wea)=(1,1)
        .addra(ringbuf_addr),  // input wire [14 : 0] addra
        .dina(ringbuf_din),    // input wire [15 : 0] dina
        .douta(ringbuf_dout)  // output wire [15 : 0] douta
    );

    assign ringbuf_enable = 
            ringbuf_en_wr 
            | ringbuf_en_rd_echo1 | ringbuf_en_rd_echo2 |  ringbuf_en_rd_echo3;

    assign ringbuf_addr =
            ringbuf_addr_wr
            | ringbuf_addr_echo1 | ringbuf_addr_echo2 | ringbuf_addr_echo3;

    // state counter

    always_comb begin
        n_counter = 'd0;
        if (counter == 'd0) begin
            if (is_input_fifo_empty == 1'b0) begin
                n_counter = 'd1;
            end
        end else begin
            if (counter < 'd32) begin
                n_counter = counter + 'd1;
            end else begin
                n_counter = 'd0;
            end
        end
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            counter <= 'd0;
        end else begin
            counter <= n_counter;
        end
    end

    // read from fifo

    always_comb begin
        request_to_read_input_fifo = 1'b0;
        if (counter == 'd1) begin
            request_to_read_input_fifo = 1'b1;
        end
    end

    // store the input signal into ringbuffer

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            sigsample_latest <= 'd0;
        end else begin
            if (counter == 'd1) begin
                sigsample_latest <= din;
            end
        end
    end

    always_comb begin
        ringbuf_en_wr  = 1'b0;
        ringbuf_we = 1'b0;
        ringbuf_din = 'd0;
        ringbuf_addr_wr = 'd0;
        if (n_counter == 'd3) begin
            ringbuf_en_wr  = 1'b1;
            ringbuf_we = 1'b1;
            ringbuf_din = sigsample_latest;
            ringbuf_addr_wr = ringbuf_addr_next_to_write;
        end
    end

    // increment memory pointer

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            ringbuf_addr_next_to_write <= 'd0;
        end else begin
            if (counter == 'd3) begin
                ringbuf_addr_next_to_write <= ringbuf_addr_next_to_write + 'd1;
            end
        end
    end

    // read older data to create echo

    always_comb begin
        ringbuf_en_rd_echo1  = 1'b0;
        ringbuf_addr_echo1 = 'd0;
        if (n_counter == 'd5 || n_counter == 'd6) begin
            ringbuf_en_rd_echo1  = 1'b1;
            ringbuf_addr_echo1 = ringbuf_addr_next_to_write + 15'h6A77 ;
            // +15'h6A77 equals "-5512"
        end
    end

    always_comb begin
        ringbuf_en_rd_echo2  = 1'b0;
        ringbuf_addr_echo2 = 'd0;
        if (n_counter == 'd9 || n_counter == 'd10) begin
            ringbuf_en_rd_echo2  = 1'b1;
            ringbuf_addr_echo2 = ringbuf_addr_next_to_write + 15'h54EE ;
            // +15'h54EE equals "-11025"
        end
    end

    always_comb begin
        ringbuf_en_rd_echo3  = 1'b0;
        ringbuf_addr_echo3 = 'd0;
        if (n_counter == 'd13 || n_counter == 'd14) begin
            ringbuf_en_rd_echo3  = 1'b1;
            ringbuf_addr_echo3 = ringbuf_addr_next_to_write + 15'h3F65 ;
            // +15'h3F65 equals "-16538"
        end
    end

    // read older data to create echo, store to registers
    // unsided -> signed
    always_ff@(posedge clk) begin
        if (counter == 'd6) begin
            echo_old1 <= signed'(ringbuf_dout);
        end
        if (counter == 'd10) begin
            echo_old2 <= signed'(ringbuf_dout);
        end
        if (counter == 'd14) begin
            echo_old3 <= signed'(ringbuf_dout);
        end
    end

    // delay echo effect, calclate in signed 32bit
    assign o1 = (32'(echo_old1) * 'sd13) >>> 4;   // 'sd means signed-decimal
    assign o2 = (32'(echo_old2) * 'sd11) >>> 4;   // >>> will preserve sign bit
    assign o3 = (32'(echo_old3) * 'sd9) >>> 4;
    assign effect32 = o1 + o2 + o3;
    assign signal_with_effect32 = 32'(signed'(sigsample_latest)) + o1 + o2 + o3;

    // unsigned 16bit <- signed 16bit <- signed 32bit
    // preserved sign bit plus 15bit value
    assign signal_with_effect16 = {signal_with_effect32[31], signal_with_effect32[14:0]};
    assign effect16 = {effect32[31], effect32[14:0]};

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            signal_with_effect <= 'd0;
            signal_effect_only <= 'd0;
        end else begin
            if (n_counter == 'd15) begin
                signal_with_effect <= signal_with_effect16;
                signal_effect_only <= effect16;
            end
        end
    end

    // result to FIFO
    always_comb begin
        request_to_write_output_fifo = 1'b0;
        if (n_counter == 'd18) begin
            request_to_write_output_fifo = 1'b1;
        end
    end

    assign signal_through = sigsample_latest;

endmodule

`default_nettype wire
