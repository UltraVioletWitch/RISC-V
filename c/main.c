#define GPIO_OUT (*(volatile unsigned int *)0xF0000000)
#define GPIO_IN  (*(volatile unsigned int *)0xF0000004)
#define GPIO_DIR (*(volatile unsigned int *)0xF0000008)

int main() {
    GPIO_DIR = 0x00FF;  // upper 16 pins output, lower 16 input
    
    volatile int i = 0;
    while (1) {
        // blink pin 0
        GPIO_OUT ^= 0x00FF;

        i = 0;
        while (i < 0xFFFFF) {
            unsigned int inputs = GPIO_IN & 0xFF00;
            if (inputs & (1 << 12)) {
                i++;
            }
        }
    }
}
