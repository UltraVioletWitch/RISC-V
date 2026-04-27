#include <stdint.h>

#define GPIO_OUT   (*(volatile uint32_t *)0xF0000000)
#define GPIO_IN    (*(volatile uint32_t *)0xF0000004)
#define GPIO_DIR   (*(volatile uint32_t *)0xF0000008)

#define UART_TX  (*(volatile uint32_t *)0xF0000100)
#define UART_RX  (*(volatile uint32_t *)0xF0000104)
#define UART_SR (*(volatile uint32_t *)0xF0000108)

#define UART_ACTIVE (1 << 0)
#define UART_TX_DONE (1 << 1)
#define UART_RX_READY (1 << 2)

#define MTIME_H    (*(volatile uint32_t *)0xFFFF0000)
#define MTIME_L    (*(volatile uint32_t *)0xFFFF0004)
#define MTIMECMP_H (*(volatile uint32_t *)0xFFFF0008)
#define MTIMECMP_L (*(volatile uint32_t *)0xFFFF000C)

#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" :: "r"(val))
#define set_csr(reg, val)   asm volatile("csrs " #reg ", %0" :: "r"(val))
#define clear_csr(reg, val)   asm volatile("csrc " #reg ", %0" :: "r"(val))
#define read_csr(reg) ({ uint32_t val; asm volatile("csrr %0, " #reg : "=r"(val)); val; })

// 12MHz clock - 1 second interval
#define TIMER_INTERVAL 6000000ULL

static volatile int timerFlag = 0;
void set_timer(uint64_t interval) {
    uint32_t lo, hi;
    do {
        hi = MTIME_H;
        lo = MTIME_L;
    } while (MTIME_H != hi);

    uint64_t now  = ((uint64_t)hi << 32) | lo;
    uint64_t next = now + interval;

    MTIMECMP_H = 0xFFFFFFFF;
    MTIMECMP_L = (uint32_t)(next & 0xFFFFFFFF);
    MTIMECMP_H = (uint32_t)(next >> 32);
}

void uart_putc(char c) {
    while (UART_SR & UART_ACTIVE);
    UART_TX = c;
    while (!(UART_SR & UART_TX_DONE));
    UART_SR = UART_TX_DONE;
}

void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

// minimal integer print
void uart_puti(uint32_t n) {
    if (n == 0) { uart_putc('0'); return; }
    char buf[10];
    int i = 0;
    while (n > 0) {
        uint32_t q = 0;
        uint32_t r = n;
        uint32_t d = 10;
        while (r >= d) {
            r -= d;
            q++;
        }
        buf[i++] = '0' + r;
        n = q;
    }
    while (i--)
        uart_putc(buf[i]);
}

void uart_puthex(uint32_t n) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (n >> i) & 0xF;
        uart_putc(nibble < 10 ? '0' + nibble : 'a' + nibble - 10);
    }
}

void uart_rx_echo() {
    char c = UART_RX;
    UART_SR = UART_RX_READY;
    uart_putc(c);
}

void __attribute__((interrupt("machine"))) trap_handler() {
    uint32_t cause = read_csr(mcause);
    //GPIO_OUT = 0x11;

    if (cause == 0x80000007) {
        timerFlag = 1;
        // reschedule
        set_timer(TIMER_INTERVAL);
    }
}

int main() {
    GPIO_DIR = 0x3FF;
    GPIO_OUT = 0x3FF;    // startup pattern so we know code is running

    volatile int tick_count = 0;
    volatile uint32_t led_state = 0;

    uart_puts("UART online!\r\n");
    /*
    uart_puts("tick: ");
    uart_puti(tick_count);
    uart_puts("\r\n");
    */

    set_csr(mie, (1 << 7));
    set_timer(TIMER_INTERVAL);
    set_csr(mstatus, (1 << 3));

    while (1) {

        //GPIO_OUT = UART_SR & 0x3FF;

        if (UART_SR & UART_RX_READY) {
            uart_rx_echo();
        }

        if (timerFlag) {
            tick_count++;
            /*
            uart_puts("tick: ");
            uart_puti(tick_count);
            uart_puts("\r\n");
            */

            led_state = (led_state << 1) | (led_state >> 9);
            led_state &= 0x3FF;

            if (led_state == 0)
                led_state = 0x01;

            GPIO_OUT = led_state;

            timerFlag = 0;
        }
    }
}
