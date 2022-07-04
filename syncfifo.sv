
`default_nettype none

module syncfifo #(
    parameter WIDTH = 8,
    parameter LENGTH  = 8
) (
    input  wire                 clk,
    input  wire                 reset,
    input  wire [WIDTH-1:0]     din,
    output logic [WIDTH-1:0]    dout,
    input  wire                 write_request,
    input  wire                 read_request,
    output logic                is_empty,
    output logic                is_full
);

    // output reg logic
    logic [WIDTH-1:0]       n_dout;
    logic                   n_is_empty;
    logic                   n_is_full;

    // local logic
    logic                   both_read_and_write_requestd;
    logic                   can_read;
    logic                   can_write;

    // local reg
    localparam LOGLENGTH = $clog2(LENGTH);   // 3 when LENGTH==8
    logic [WIDTH-1:0]       buffer [0:2**LOGLENGTH-1];
    logic [WIDTH-1:0]       n_data_to_write;
    logic [LOGLENGTH:0]     write_ptr, n_write_ptr; // 4bit counter when LENGTH==8
    logic [LOGLENGTH:0]     read_ptr, n_read_ptr;

    // local logic
    assign both_read_and_write_requestd = write_request && read_request;
    assign can_write = write_request && ~is_full;
    assign can_read = read_request && ~is_empty;


    // output reg logic
    always_comb begin
        n_dout = dout;
        if (both_read_and_write_requestd && is_empty) begin
            n_dout = din;   // the first data
        end else begin
            if (can_read)
                n_dout = buffer[LOGLENGTH'(read_ptr)];
        end
    end

    always_comb begin
        n_is_empty = is_empty;
        n_is_full = is_full;
        if (~both_read_and_write_requestd) begin
            if (write_request) begin
                n_is_empty = 'b0;
                n_is_full = ((write_ptr - read_ptr) >= (LOGLENGTH+1)'(LENGTH-1));
                // not full -> full  (==)
                // full -> full (>=)
            end
            if (read_request) begin
                n_is_empty = ((write_ptr == read_ptr) || (write_ptr == read_ptr+1));
                n_is_full = 'b0;
            end
        end
    end


    // local reg logic
    always_comb begin
        n_write_ptr = write_ptr;
        n_read_ptr = read_ptr;
        if (both_read_and_write_requestd) begin
            // read and write are possible even when empty or full
            n_write_ptr = write_ptr + 'd1;
            n_read_ptr = read_ptr + 'd1;
            n_data_to_write = din;
        end else begin
            if (can_write) begin
                n_write_ptr = write_ptr + 'd1;
                n_data_to_write = din;
            end
            if (can_read)
                n_read_ptr = read_ptr + 'd1;
        end
    end


    // update output reg
    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            dout <= 'd0;
            is_empty <= 'd1;
            is_full <= 'd0;
        end else begin
            dout <= n_dout;
            is_empty <= n_is_empty;
            is_full <= n_is_full;
        end
    end


    // update local reg
    always_ff@(posedge clk) begin
        if (both_read_and_write_requestd || can_write)
            buffer[LOGLENGTH'(write_ptr)] <= n_data_to_write;
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            write_ptr <= 'd0;
            read_ptr <= 'd0;
        end else begin
            write_ptr <= n_write_ptr;
            read_ptr <= n_read_ptr;
        end
    end

endmodule

`default_nettype wire
