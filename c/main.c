#include <stdint.h>

#define GPIO_OUT   (*(volatile uint32_t *)0xF0000000)
#define GPIO_IN    (*(volatile uint32_t *)0xF0000004)
#define GPIO_DIR   (*(volatile uint32_t *)0xF0000008)

#define MTIME_H    (*(volatile uint32_t *)0xFFFF0000)
#define MTIME_L    (*(volatile uint32_t *)0xFFFF0004)
#define MTIMECMP_H (*(volatile uint32_t *)0xFFFF0008)
#define MTIMECMP_L (*(volatile uint32_t *)0xFFFF000C)

#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" :: "r"(val))
#define set_csr(reg, val)   asm volatile("csrs " #reg ", %0" :: "r"(val))
#define read_csr(reg) ({ uint32_t val; asm volatile("csrr %0, " #reg : "=r"(val)); val; })

// 12MHz clock - 1 second interval
#define TIMER_INTERVAL 3000000ULL

static volatile uint32_t led_state = 0;
static volatile uint32_t tick_count = 0;
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

void __attribute__((interrupt("machine"))) trap_handler() {
    uint32_t cause = read_csr(mcause);
    //GPIO_OUT = 0x11;

    if (cause == 0x80000007) {
        timerFlag = 1;
        // reschedule
        set_timer(TIMER_INTERVAL);
    } else if (cause == 0x8000000B) {
        // external interrupt - flash all LEDs twice
        uint32_t saved = led_state;
        for (int i = 0; i < 2; i++) {
            GPIO_OUT = 0xFF;
            for (volatile int d = 0; d < 50000; d++);
            GPIO_OUT = 0x00;
            for (volatile int d = 0; d < 50000; d++);
        }
        GPIO_OUT = saved;
    }
}

int main() {
    GPIO_DIR = 0x3FF;
    //GPIO_OUT = 0x55;    // startup pattern so we know code is running

    // enable timer and external interrupts
    set_csr(mie, (1 << 7));

    // arm the first timer interrupt
    set_timer(TIMER_INTERVAL);

    // enable global interrupts
    set_csr(mstatus, (1 << 3));

    while (1) {
        if (timerFlag) {
            tick_count++;

            led_state = (led_state << 1) | (led_state >> 9);
            led_state &= 0x3FF;

            if (led_state == 0)
                led_state = 0x01;

            GPIO_OUT = led_state;

            timerFlag = 0;
        }
    }
}
