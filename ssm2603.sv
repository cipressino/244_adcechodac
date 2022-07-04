`default_nettype none

module ssm2603 (
    input   wire            MCLK,
    input   wire            RESET,

    // codec clock
    output  logic           BCLK,

    // ADC
    output  logic           RECLRC,
    input   wire            RECDAT,

    // DAC
    output  logic           PBDAT,
    output  logic           PBLRC,

    // ADC result to upper module
    output  logic [15:0]    RECDATLEFT,
    output  logic [15:0]    RECDATRIGHT,
    output  logic           FIFO_REQ_WRITE_LEFT,
    output  logic           FIFO_REQ_WRITE_RIGHT,

    // sound data from upper module to DAC
    input   wire  [15:0]    PBDATLEFT,
    input   wire  [15:0]    PBDATRIGHT,
    output  logic           FIFO_REQ_READ_LEFT,
    output  logic           FIFO_REQ_READ_RIGHT
);

    // 16 bit quantization
    localparam divider256_when_Lch_lsb_recorded = 8'h3E;
    localparam divider256_when_Rch_lsb_recorded = 8'hBE;

    logic           clk;
    logic           reset;

    logic [1:0]     divider4;

    logic [7:0]     divider256;
    logic [7:0]     n_divider256;

    logic [15:0]    sound_data;
    logic [15:0]    n_sound_data; 

    logic [15:0]    reading_data;
    logic [15:0]    n_reading_data;


    // just renaming
    assign clk = MCLK;
    assign reset = RESET;


    // BCLK generator

    assign BCLK = divider4[1];

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            divider4 <= 2'b10;
        end else begin
            divider4 <= divider4 + 2'b01;
        end
    end


    // PBLRC, RECLRC generator

    assign PBLRC = ~divider256[7];
    assign RECLRC = ~divider256[7];

    always_comb begin
        n_divider256 = divider256 + 8'h1;
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            divider256 <= 8'hfe;
        end else begin
            divider256 <= n_divider256;
        end
    end


    // PB data before sending

    logic [15:0]        pbsound_data_left;
    logic [15:0]        pbsound_data_right;

    always_comb begin
        FIFO_REQ_READ_LEFT = 1'b0;
        FIFO_REQ_READ_RIGHT = 1'b0;
        if (n_divider256 == 8'hff) begin
            FIFO_REQ_READ_LEFT = 1'b1;
        end
        if (n_divider256 == 8'h7f) begin
            FIFO_REQ_READ_RIGHT = 1'b1;
        end
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            pbsound_data_left <= 16'h0000;
            pbsound_data_right <= 16'h0000;
        end else begin
            if (n_divider256 == 8'hff) begin
                // get a data from FIFO
                pbsound_data_left <=  PBDATLEFT;
            end
            if (n_divider256 == 8'h7f) begin
                // get a data from FIFO
                pbsound_data_right <=  PBDATRIGHT;
            end
        end
    end


    // prepare data to be sent for L / R channel

    always_comb begin
        n_sound_data = sound_data;

        if (divider256 == 8'hff) begin
            n_sound_data = pbsound_data_left;

        end else if (divider256 == 8'h7f) begin
            n_sound_data = pbsound_data_right;

        end else begin
            if (divider4 == 2'b11) begin
                n_sound_data = {sound_data[14:0], 1'b0} ;
            end
        end
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            sound_data <= 16'h0000;
        end else begin
            sound_data <= n_sound_data;
        end
    end


    // PBDAT to D/A converter

    assign PBDAT = sound_data[15];


    // read RECDAT

    always_comb begin
        n_reading_data = reading_data;

        // clear working register (actually not needed)
        if (divider256 == 8'h7e || divider256 == 8'hfe) begin
            n_reading_data = 'd0;
        end

        // read RECDAT at BCLK rise edge
        if (divider4 == 2'b01) begin
            n_reading_data = {reading_data[14:0], RECDAT} ;
        end
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            reading_data <= 16'b0;
        end else begin
            reading_data <= n_reading_data;
        end
    end


    // store the data when LSB read

    logic [15:0]        n_RECDATLEFT;
    logic [15:0]        n_RECDATRIGHT;

    always_comb begin
        n_RECDATLEFT = RECDATLEFT;
        n_RECDATRIGHT = RECDATRIGHT;
        if (n_divider256 == divider256_when_Lch_lsb_recorded) begin
            n_RECDATLEFT = n_reading_data;
        end
        if (n_divider256 == divider256_when_Rch_lsb_recorded) begin
            n_RECDATRIGHT = n_reading_data;
        end
    end

    always_ff@(posedge clk) begin
        if (reset == 1'b1) begin
            RECDATLEFT <= 'd0;
            RECDATRIGHT <= 'd0;
        end else begin
            RECDATLEFT <= n_RECDATLEFT;
            RECDATRIGHT <= n_RECDATRIGHT;
        end
    end

    always_comb begin
        FIFO_REQ_WRITE_LEFT = 1'b0;
        FIFO_REQ_WRITE_RIGHT = 1'b0;
        if (divider256 == divider256_when_Lch_lsb_recorded) begin
            FIFO_REQ_WRITE_LEFT = 1'b1;
        end
        if (divider256 == divider256_when_Rch_lsb_recorded) begin
            FIFO_REQ_WRITE_RIGHT = 1'b1;
        end
    end

endmodule

`default_nettype wire
