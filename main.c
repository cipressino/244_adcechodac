#include "xparameters.h"
#include "xiic.h"
#include "xil_printf.h"
#include <sleep.h>

static const u8 s_iic_deviceid_ssm2603 = 0x1a;
static XIic s_iic_ssm2603;

unsigned write_reg_ssm2603(XIic* iic, u8 address, u16 data) {
    u8 buffer[2];
    unsigned res;

    buffer[0] = (address << 1) | ( (data>>8) & 0b1);
    buffer[1] = data & 0xff;
    res = XIic_Send(iic->BaseAddress, s_iic_deviceid_ssm2603, buffer, 2, XIIC_STOP);

    return res;
}

int main(void){
    XIic* iicptr = &s_iic_ssm2603;

    xil_printf("configuring ssm2603 ...\n");

    int iicinit = XIic_Initialize(iicptr, XPAR_IIC_0_DEVICE_ID);
    if (iicinit != XST_SUCCESS) {
        xil_printf("failed XIic_Initialize -> %d\n", iicinit);
        return XST_FAILURE;
    }

    write_reg_ssm2603(iicptr, 0x6, 0b001110000); // CLKOUT,OSC,Out<=Off others<=On
    write_reg_ssm2603(iicptr, 0x0, 0b000010111);
    write_reg_ssm2603(iicptr, 0x1, 0b000010111);
    write_reg_ssm2603(iicptr, 0x2, 0b001111001);
    write_reg_ssm2603(iicptr, 0x3, 0b001111001);
    write_reg_ssm2603(iicptr, 0x4, 0b000010010); //LineIn
    write_reg_ssm2603(iicptr, 0x5, 0b000000000); //DACMU disabled
    write_reg_ssm2603(iicptr, 0x7, 0b000000001); //Slave,16bit,Leftjust
    write_reg_ssm2603(iicptr, 0x8, 0b000100000); //11.2896MHz, 44.1kHz, notUsb
    usleep(1000); // Zybo Z7 DMA Audio Demo
    write_reg_ssm2603(iicptr, 0x9, 0b000000001); //Activate
    write_reg_ssm2603(iicptr, 0x6, 0b001100000); //CLKOUT,OSC<=Off  Out<=On

    xil_printf("configuring ssm2603 done.\n");

    u32 counter = 0;
    while(1) {
        usleep(1000000);
        counter += 1;
        xil_printf("%d seconds spent\n", counter);
    }

    return XST_SUCCESS;
}
