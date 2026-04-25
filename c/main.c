#define GPIO_OUT (*(volatile unsigned int *)0xF0000000)
#define GPIO_IN  (*(volatile unsigned int *)0xF0000004)
#define GPIO_DIR (*(volatile unsigned int *)0xF0000008)

int main() {
    GPIO_DIR = 0x00FF;

    volatile int i = 0;
    volatile int pins = 0;

    int rising = 1;

    GPIO_OUT = pins & 0xFF;

    while (1) {
        i = 0;
        while (i < 0xFFFF) {
            if ((GPIO_IN >> 12) & 1) {
                i++;
            }
        }

        if (rising) {
            pins++;
        } else {
            pins --;
        }

        GPIO_OUT = pins & 0xFF;

        if (pins == 0xFF) {
            rising = 0;
        } else if (pins == 0x00) {
            rising = 1;
        }
    }
}
