#define GPIO_OUT (*(volatile unsigned int *)0xF0000000)
#define GPIO_IN  (*(volatile unsigned int *)0xF0000004)
#define GPIO_DIR (*(volatile unsigned int *)0xF0000008)

int main() {
    GPIO_DIR = 0xFF;  // upper 16 pins output, lower 16 input
    
    while (1) {
        // blink pin 0
        GPIO_OUT ^= 0xFF;
        
        // read lower pins
        //unsigned int inputs = GPIO_IN & 0xFF;
        
        // mirror inputs to output pins
        volatile int i = 0;
        while (i < 0xFFFFF) {
            //unsigned int inputs = GPIO_IN & 0xFF;
            if (1) {
                i++;
            }
        }
    }
}
