`default_nettype none

module prj (

    input   wire            CLK,
    input   wire            RESET,

    // codec data
    output  logic           PBDAT,
    input   wire            RECDAT,

    // codec control
    output  logic           BCLK,
    output  logic           PBLRC,
    output  logic           RECLRC,

    // switch input
    input   wire            SWITCH_EFFECT

);

    // between ssm2603 and infifo
    logic [15:0]    recdat_from_adconv_left;
    logic           req_write_to_fifo_left;
    logic           full_infifo_left;
    logic [15:0]    recdat_from_adconv_right;
    logic           req_write_to_fifo_right;
    logic           full_infifo_right;

    // between outfifo and ssm2603
    logic           req_read_from_fifo_to_da_left;
    logic           req_read_from_fifo_to_da_right;

    // between infifo and effector
    logic [15:0]    data_from_infifo_left;
    logic           req_read_from_fifo_left;
    logic           empty_infifo_left;
    logic [15:0]    data_from_infifo_right;
    logic           req_read_from_fifo_right;
    logic           empty_infifo_right;

    // between effector and outfifo
    logic [15:0]    signal_with_effect_left;
    logic           req_write_to_outfifo_left;
    logic [15:0]    data_from_through_left;
    logic [15:0]    data_from_effect_left;
    logic [15:0]    signal_to_outfifo_left;
    logic [15:0]    signal_with_effect_right;
    logic           req_write_to_outfifo_right;
    logic [15:0]    data_from_through_right;
    logic [15:0]    data_from_effect_right;
    logic [15:0]    signal_to_outfifo_right;

    // betwen outfifo and ssm2603
    logic [15:0]    data_read_from_fifo_to_da_left;
    logic           empty_outfifo_left;
    logic           full_outfifo_left;
    logic [15:0]    data_read_from_fifo_to_da_right;
    logic           empty_outfifo_right;
    logic           full_outfifo_right;


    // 
    //  A/D D/A Converter
    // 

    ssm2603 u_ssm2603(
        .MCLK(CLK),
        .RESET(RESET),
        .PBDAT(PBDAT),
        .RECDAT(RECDAT),
        .BCLK(BCLK),
        .PBLRC(PBLRC),
        .RECLRC(RECLRC),
        .RECDATLEFT(recdat_from_adconv_left),
        .RECDATRIGHT(recdat_from_adconv_right),
        .FIFO_REQ_WRITE_LEFT(req_write_to_fifo_left),
        .FIFO_REQ_WRITE_RIGHT(req_write_to_fifo_right),
        .PBDATLEFT(data_read_from_fifo_to_da_left),
        .PBDATRIGHT(data_read_from_fifo_to_da_right),
        .FIFO_REQ_READ_LEFT(req_read_from_fifo_to_da_left),
        .FIFO_REQ_READ_RIGHT(req_read_from_fifo_to_da_right)  );


    // 
    //  Left Channel fifo and effector 
    // 
    syncfifo #(.WIDTH(16), .LENGTH(8)) u_infifo_left (
        .clk(CLK),
        .reset(RESET),

        // write from ssm
        .din(recdat_from_adconv_left),
        .write_request(req_write_to_fifo_left), 

        // read to intrmd
        .dout(data_from_infifo_left),
        .read_request(req_read_from_fifo_left),

        .is_empty(empty_infifo_left), 
        .is_full(full_infifo_left)
        );

    dlyecho u_dlyecho_left(
        .clk(CLK),
        .reset(RESET),
        .din(data_from_infifo_left),
        .request_to_read_input_fifo(req_read_from_fifo_left),
        .is_input_fifo_empty(empty_infifo_left),
        .signal_with_effect(signal_with_effect_left),
        .request_to_write_output_fifo(req_write_to_outfifo_left),
        .signal_through(data_from_through_left),
        .signal_effect_only(data_from_effect_left) );

    always_comb begin
        signal_to_outfifo_left = data_from_through_left;
        if (SWITCH_EFFECT == 'b1) begin
            signal_to_outfifo_left = signal_with_effect_left;
        end
    end

    syncfifo #(.WIDTH(16), .LENGTH(8)) u_outfifo_left (
        .clk(CLK),
        .reset(RESET),

        // write from intermd
        .din(signal_to_outfifo_left),
        .write_request(req_write_to_outfifo_left), 

        // ssm will read
        .dout(data_read_from_fifo_to_da_left),
        .read_request(req_read_from_fifo_to_da_left),
        .is_empty(empty_outfifo_left), 
        .is_full(full_outfifo_left)
        );


    // 
    //  Right Channel fifo and effector 
    // 

    syncfifo #(.WIDTH(16), .LENGTH(8)) u_infifo_right (
        .clk(CLK),
        .reset(RESET),
        .din(recdat_from_adconv_right),
        .dout(data_from_infifo_right),
        .write_request(req_write_to_fifo_right), 
        .read_request(req_read_from_fifo_right),
        .is_empty(empty_infifo_right), 
        .is_full(full_infifo_right)
        );

    dlyecho u_dlyecho_right (
        .clk(CLK),
        .reset(RESET),
        .din(data_from_infifo_right),
        .request_to_read_input_fifo(req_read_from_fifo_right),
        .is_input_fifo_empty(empty_infifo_right),
        .signal_with_effect(signal_with_effect_right),
        .request_to_write_output_fifo(req_write_to_outfifo_right),
        .signal_through(data_from_through_right),
        .signal_effect_only(data_from_effect_right) );

    always_comb begin
        signal_to_outfifo_right = data_from_through_right;
        if (SWITCH_EFFECT == 'b1) begin
            signal_to_outfifo_right = signal_with_effect_right;
        end
    end

    syncfifo #(.WIDTH(16), .LENGTH(8)) u_outfifo_right (
        .clk(CLK),
        .reset(RESET),

        // write from intermd
        .din(signal_to_outfifo_right),
        .write_request(req_write_to_outfifo_right), 

        // ssm will read
        .dout(data_read_from_fifo_to_da_right),
        .read_request(req_read_from_fifo_to_da_right),
        .is_empty(empty_outfifo_right), 
        .is_full(full_outfifo_right)
        );


endmodule

`default_nettype wire
