
module prj_top(
CLK,
RESET,
PBDAT,
RECDAT,
BCLK,
PBLRC,
RECLRC,
SW1
);

input CLK;
input RESET;
output PBDAT;
input RECDAT;
output BCLK;
output PBLRC;
output RECLRC;
input SW1;

prj  u_prj(
    .CLK(CLK),
    .RESET(RESET),
    .PBDAT(PBDAT),
    .RECDAT(RECDAT),
    .BCLK(BCLK),
    .PBLRC(PBLRC),
    .RECLRC(RECLRC),
    .SWITCH_EFFECT(SW1)
    );

endmodule
