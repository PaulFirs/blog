---
title: "Bootloader. Cortex-M Nuances, STM32 Memory Structure and Pre-configuration"
description: "Part 1 of a series of articles on creating a bootloader for STM32"
date: 2024-01-28
tags: ["MCU", "embedded", "stm32", "bootloader"]
---

## Preface
I decided to start a series of articles on the topic of bootloader for STM32. Perhaps this will serve as a guide for beginning developers, or maybe it will help true demiurges in the field of embedded development.

I'll start with the main thing, namely the structure of the narrative. I plan to make several articles that will progress from a global question to a local one:
1. [[Bootloader. Part 1. Cortex-M Nuances, STM32 Memory Structure and Pre-configuration]]
2. Bootloader. Part 2. Bootloader Program. Time to Flash
3. Bootloader. Part 3. Protection from Hangs and How to Return to Bootloader for Reflashing
4. Bootloader. Part 4. Encryption

### How the MCU Starts

We'll do the analysis using the example of the popular microcontroller (hereinafter MCU) STM32.
The MCU starts from address 0x00000000 then at 0x00000004. This memory area maps the memory contents from an address depending on which BOOT pin we pulled.

Many people know this table:

| boot0 | boot1 | BOOT mode | Aliasing |
| ---- | ---- | ---- | ---- |
| x | 0 | Main Flash memory |  Main Flash memory is selected as boot space |
| 0 | 1 | System memory | System memory is selected as boot space |
| 1 | 1 | Embedded SRAM | Embedded SRAM is selected as boot space |
This is exactly what describes from which address the MCU memory will be mapped. We need the memory to be mapped from the memory sector where the main firmware is stored (this is the first row of the table), namely address 0x08000000. If you want to run the bootloader from STM32 via UART (address 0x1FFF0000), then connect the boot1 pin to logic one (but not today).

Address 0x08000000 is the address where our firmware starts. At this address, a pointer to the stack is stored (stack pointer register - SP). And at address 0x08000004, a pointer to the reset vector is stored.

A bit of theory about the architecture:
When our program is mapped to address 0x00000000 (the contents of address 0x08000000 are mapped to it), everything will be the same there. The controller starts and looks at what is at 0x00000000, writes the contents and already knows that the stack starts (or the end of RAM memory) from a certain address, it starts with 0x2xxxxxxx. This is exactly the end of RAM memory, where the stack begins.
After that, the controller reads the contents of memory address 0x00000004 (the contents of address 0x08000004 are mapped to it). Here a pointer to the reset function is stored, which is already located at some 0x08xxxxxxx address. Here it starts working in the user memory area we need, and not in some imaginary system memory.


## General Provisions for Bootloader
### Requirements for bootloader
Bootloader is essentially a separate part of the entire firmware that can/should work independently.
- our program must start from it (if it dies, the chip turns into a brick (in most cases));
- it must be indestructible (if it dies, we will no longer have access to the chip);
- it must switch to the main firmware (because it does not perform business logic);
- Bonus task: no one should know how we reflash the chip.

### Our MCU Program Must Start from the Bootloader:

This is the first point of our requirements. So how should we start? Same as always. Configure the MCU, generate code and write firmware. No! Let's wait with the last point. First, we need to work with memory. There is such a file as STM32F765ZGTX_FLASH.ld or STM32F407VETX_FLASH.ld or STM32F091CCUX_FLASH.ld (depending on the selected controller, the beginning of the file may be different, but the essence is the same). This is a linker script file. It specifies how memory will be distributed in the MCU.
All memory is described in the structure (for chip STM32F407VE):
```
MEMORY
{
CCMRAM (xrw) : ORIGIN = 0x10000000, LENGTH = 64K
RAM (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
FLASH (rx) : ORIGIN = 0x8000000, LENGTH = 512K
}
```
Here the entire firmware is stored in the FLASH area, but we want to have two firmwares (one for the bootloader, another for the main firmware). Therefore, for the bootloader and main firmware we must allocate a separate place under the sun:
```
MEMORY
{
CCMRAM (xrw) : ORIGIN = 0x10000000, LENGTH = 64K
RAM (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
FLASH (rx) : ORIGIN = 0x8000000, LENGTH = 48K
BOOT_DATA (rx) : ORIGIN = 0x800C000, LENGTH = 16K
APP (rx) : ORIGIN = 0x8010000, LENGTH = 448K
}

_sapp = ORIGIN(APP);
_eapp = ORIGIN(APP) + LENGTH(APP);
_smem = ORIGIN(BOOT_DATA);
```

- The FLASH area stores the Bootloader;
- The APP area stores the main program (we marked it here to use data about its location in the bootloader and not define some defines with addresses);
- The BOOT_DATA area stores data about the firmware. This memory is especially important to determine whether the firmware exists at all;
- Variable `_sapp` is needed to determine the starting address of the firmware;
- Variable `_eapp` is needed to determine the ending address of the firmware;
- Variable `_smem` is needed to determine the starting address of bootloader data. Here we will store data about the firmware. They won't be erased because they are stored in flash memory (as if they are part of the program). This can be: version, checksum of the firmware file, etc. When erasing the firmware, this area must also be erased to understand that there is no firmware.

There is a subtle point here. You can't distribute memory as you please. We are still engineers, and we are guided only by manuals. Therefore, for this chip, I distributed memory by sectors, as indicated in the manual. Because when we erase the firmware or the section for bootloader data, we will have to erase an entire memory sector. For this chip, they are distributed according to the manual:

| Sector | Block base address | Size |
| ---- | ---- | ---- |
| Sector 0 | 0x0800 0000 - 0x0800 3FFF | 16 Kbytes |
| Sector 1 | 0x0800 0000 - 0x0800 3FFF | 16 Kbytes |
| Sector 2 | 0x0800 8000 - 0x0800 BFFF | 16 Kbytes |
| Sector 3 | 0x0800 C000 - 0x0800 FFFF | 16 Kbytes |
| Sector 4 | 0x0801 0000 - 0x0801 FFFF | 64 Kbytes |
| Sector 5 | 0x0802 0000 - 0x0803 FFFF | 128 Kbytes |
| Sector 6 | 0x0804 0000 - 0x0805 FFFF | 128 Kbytes |
| ... | ... | ... |
| Sector 11 | 0x080E 0000 - 0x080F FFFF | 128 Kbytes |
In our linker script:
Bootloader is located starting from sector 0;
Data for bootloader is stored starting from sector 3;
Main firmware is stored starting from sector 4;
Seems everything is correct...

#### Using What We Marked in the Code

Now the definitions `_sapp, _eapp, _smem` can be used in the code (just an example to look at them):
```c
extern uint8_t _sapp;
extern uint8_t _eapp;
extern uint8_t _smem;
printf("start address APP %d\r\n", (uint32_t*)&_sapp);
printf("end address APP %d\r\n", (uint32_t*)&_eapp);
printf("start address SHARED_MEMORY %d\r\n", (uint32_t*)&_smem);
```

We start writing the bootloader code. I set myself the task of making it universal, and the previous manipulations will help me with this.
Let's define a couple of defines for simple access to the main firmware memory space:


Defines:
```c
extern uint8_t _sapp; // Variable located at the starting address of the firmware
extern uint8_t _eapp; // Variable located at the ending address of the firmware
extern uint8_t _smem; // Variable located at the starting address of the shared memory area

// Defines for them to extract the address itself
#define FLASH_APP_START_ADDESS (uint32_t) & _sapp
#define FLASH_APP_END_ADDRESS (uint32_t) & _eapp
#define FLASH_MEM_ADDRESS (uint32_t) & _smem
```

Function to check that the main firmware is valid:
```c

int fw_check(void)
{
	extern void* _estack; // This is from the linker, generated automatically and points to the end of RAM (or stack)
	if (((*(uint32_t*) FLASH_APP_START_ADDESS) & 0x2FFF8000) != &_estack) // Check the first address of the firmware, the value in it should be the size of RAM (SP register)
		return -1;

	return 0;
}
```

Here it should be remembered that in the first address of any firmware a pointer to the stack is stored (stack pointer register - SP). If it is correct, then we consider that the firmware exists and is located at the correct address. But this is actually weak evidence of that. Here you can write checksum verification, identifiers that are written after the full firmware is loaded and cleared if a command comes to erase the firmware, etc. But for now, this check is enough not to overload this article.

The next action is to launch the main program:
```c
void fw_go2APP(void)
{
	uint32_t app_jump_address; // variable for firmware address

	typedef void (*pFunction)(void); // declare a custom type for the function that will launch the main program
	pFunction Jump_To_Application; // and create a variable/function of this type

	HAL_Delay(100);
	__disable_irq(); // disable interrupts

	app_jump_address = *(uint32_t*) (FLASH_APP_START_ADDESS + 4);
	Jump_To_Application = (pFunction) app_jump_address; // cast it to custom type
	__set_MSP(*(uint32_t*) FLASH_APP_START_ADDESS); // set application SP (it will most likely not change)
	Jump_To_Application(); // launch the application
}
```
The point is to jump to the reset vector.

Before launching the firmware, it is necessary not only to disable interrupts in general sense, but also to deinitialize them (if they were initialized), otherwise they may be called in the firmware (this can also be done in this function).

About the process of writing the main program firmware in the next article.


## General Provisions for Main Firmware

### Linker Script Again...
Since this is the second part of the firmware, we need to specify where it will be located. In the linker script we edit:

```
MEMORY
{
CCMRAM (xrw) : ORIGIN = 0x10000000, LENGTH = 64K
RAM (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
FLASH (rx) : ORIGIN = 0x8010000, LENGTH = 448K
}
```

Here in the FLASH area we change the starting address and size. The name remains, otherwise we will have to dig through the entire linker script, because everything is defined there specifically for FLASH. Recall that for the bootloader we defined this area as APP so that there would be universal variables for the bootloader program. Later this will become a separate module that won't need to configure addresses separately, and the linker script always needs to be edited for such tasks. But this can also be done automatically, for example, with cmake, but about that some other time.
### Interrupt Vector Table

This is the most complex and confusing point due to different architectures.
It is required to define the interrupt vector table. What is this even? We've seemingly defined everything... The thing is that when any interrupt fires, the controller doesn't know where to go essentially, this is not the main program code, but a hardware trigger by which the controller starts executing code of some interrupt handler functions. Pointers to these functions are stored in the interrupt vector and it is always hardware-based. Normally all these functions are located at the beginning of the firmware as well as reset, which we manually call in the bootloader to launch the main program. But the hardware part of the MCU doesn't know that they are now not at the beginning of all flash memory, but with some offset by which the main program is shifted. Therefore, calling interrupts will lead to the program executing the interrupt handler that we defined in the bootloader, if we defined it. And then it will return to executing the main firmware program and only the Universe knows what will happen next.

Therefore, our task is to let the MCU understand where to go if any interrupt fires.

#### Cortex-M3 and Cortex-M4
Here it is required to set the offset for the interrupt vector in the file system_stm32f4xx.c (for f4 series):
```
#define VECT_TAB_OFFSET 0x10000U /*!< Vector Table base offset field.
```
The address must correspond to the starting address of the firmware. In general, I'm somewhat against this approach, this file needs to be found, the define in it needs to be uncommented, then write this value. Using the same cmake or linker script, this value can be written into the code during build. Therefore, at the beginning of the main function we write:

```c
int main(void)
{
  SCB->VTOR = 0x80000000 | 0x10000; // set the offset
__enable_irq(); // and at the same time enable interrupts that were disabled in the bootloader

// rest of the code...
}
```
  
  
#### Cortex-M0
In hardware, this group of ARM processors does not support interrupt vector offset in flash. You can only redefine the vector table to RAM memory. And hence all the headache with Cortex-M0.

So you need to rewrite the entire table to RAM and tell the MCU that now it looks at this table there (and not in Flash at address 0x08000004 by standard).
  
In the linker script, after the definition:

```
.fini_array :
{
. = ALIGN(4);
PROVIDE_HIDDEN (__fini_array_start = .);
KEEP (*(SORT(.fini_array.*)))
KEEP (*(.fini_array*))
PROVIDE_HIDDEN (__fini_array_end = .);
. = ALIGN(4);
} >FLASH
```

we write:

```
.ram_vector :
{
*(.ram_vector)
} >RAM
```

This allows us to reserve the __beginning__ of RAM to place the vector table there and nothing else.  
  
Filling the table should be at the beginning of main():
```c
#define VECTOR_TABLE_SIZE (31 + 1 + 7 + 9)//31 positive vectors, 0 vector, and 7 negative vectors (and extra 9 i dont know why)
#define SYSCFG_CFGR1_MEM_MODE__MAIN_FLASH 0 // x0: Main Flash memory mapped at 0x0000 0000
#define SYSCFG_CFGR1_MEM_MODE__SYSTEM_FLASH 1 // 01: System Flash memory mapped at 0x0000 0000
#define SYSCFG_CFGR1_MEM_MODE__SRAM 3 // 11: Embedded SRAM mapped at 0x0000 0000
volatile uint32_t __attribute__((section(".ram_vector,\"aw\",%nobits @"))) ram_vector[VECTOR_TABLE_SIZE];
extern volatile uint32_t g_pfnVectors[VECTOR_TABLE_SIZE];

int main(void)
{
	RCC->APB2ENR |= RCC_APB2ENR_SYSCFGEN; // early enable to ensure clock is up and running when it comes to usage
	for (uint32_t i = 0; i < VECTOR_TABLE_SIZE; i++) {//copy vector table
	ram_vector[i] = g_pfnVectors[i];
	}
	SYSCFG->CFGR1 = (SYSCFG->CFGR1 & ~SYSCFG_CFGR1_MEM_MODE) | (SYSCFG_CFGR1_MEM_MODE__SRAM * SYSCFG_CFGR1_MEM_MODE_0); // remap 0x0000000 to RAM

	__enable_irq();



// user code...
}
```

Here everything is "simple":
- ram_vector - this is an array located at the beginning of RAM to place the vector table there;
- g_pfnVectors - these are vectors that lie at the beginning of the firmware and need to be moved to ram_vector;
- After all vectors are copied, you need to tell the MCU to look for these vectors in RAM memory;
- And enable interrupts.

## Afterword

So we've implemented simple settings for two firmwares: bootloader and main program. Next time we'll talk about the actual loading of the main program firmware from the bootloader.
