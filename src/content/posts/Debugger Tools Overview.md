---
title: "Debugger Tools Overview"
description: "An overview of popular debugging tools and approaches for embedded development, including programmers, GDB clients, and GDB servers."
date: 2026-03-10
tags: ["Debugger"]
---

# General Overview of Debugging
## Programmers
The most popular solutions today:
- JLink - A powerful commercial product with a suite of software that allows you to explore embedded firmware
- STLink - A popular and purpose-built programmer
- CMSIS-DAP - An open specification for a debug interface from ARM; firmware implementing it (e.g., DAPLink, PicoProbe) can be loaded onto a chip to turn it into a programmer
- blackmagic - An open-source project that can be loaded onto a chip to turn it into both a programmer and a GDB server

## GDB Client
Every ARM developer downloads arm-none-eabi-gdb to start debugging from their IDE or terminal. For other architectures, you need the corresponding GDB — for example, riscv-none-eabi-gdb for RISC-V. But GDB doesn't communicate with the programmer directly. Moreover, GDB knows nothing about your programmer at all.

## GDB Server
To connect to the programmer via GDB, you need a software layer that knows what commands to send to the programmer over USB so it can start debugging on the required interface. Thus, we need OpenOCD in the general case. We'll cover specifics later.

<div class="question-box">
  <img src="/think.png" alt="Question" />
  <strong>Why is OpenOCD so popular?</strong>
</div>

But first, what is it essentially?
As I mentioned, it's a layer between GDB and the programmer, specifically OpenOCD is a GDB server to which your arm-none-eabi-gdb client connects. In other words, I would simply call OpenOCD a GDB server for simplicity. It knows how to work with most programmers and is controlled by GDB client commands in the same way. It just interprets them for each type of programmer as required.
From this paragraph alone, it should already be clear why OpenOCD is so popular. It simply supports all programmers and the GDB client communicates with them uniformly.

## Brief Connection Summary:
You plug your programmer into USB.
You start OpenOCD which communicates with the physical programmer and provides "handles" for the arm-none-eabi-gdb client.
You start the arm-none-eabi-gdb client which communicates with OpenOCD and everything works.
Most popular IDEs start the server and client themselves.

# Getting into Specifics
## Programmers
**STLink**
Developed by STMicroelectronics and comes embedded in most of their debug boards (Nucleo, Discovery). More specialized than JLink — focused on STM32 and STM8 microcontrollers, though unofficial firmware exists that extends its compatibility. To work with it via GDB, you use OpenOCD or the STM32CubeProgrammer utility for flashing. STMicroelectronics also offers its own STM32CubeIDE environment, which runs OpenOCD under the hood. Drivers for macOS/Linux are not needed — it works via libusb; on Windows, the situation is worse.

**JLink**
You can debug through their JLinkGDBServer. This is a replacement for OpenOCD that works only with JLink. You can select it in the same CubeIDE. This utility, like many others, comes with JLink drivers. Thus, for debugging via GDB, you use either JLinkGDBServer or OpenOCD, to which you can connect with standard arm-none-eabi-gdb.
They also have their own JLinkRemoteServer. It's positioned as a network server providing access to a physical JLink over the network — hence the name. If you want to do without standard GDB, SEGGER offers its own OZONE debugger — it works directly with JLink through their proprietary protocol and has a rich UI.
There's a lot that SEGGER has developed, but that's not what we're talking about now. It's a very good and stable solution. However, it's expensive and requires additional software.

**CMSIS-DAP**
This is an open specification for a debug interface developed by ARM. Any programmer can implement this protocol — for example, DAPLink (from ARM itself) or PicoProbe (for RP2040). Keil MDK with its own compiler (ARMCC/AC6) supports it natively through the built-in µVision debugger — without OpenOCD and arm-none-eabi-gdb. However, if you use the GNU toolchain and third-party GDB servers in Keil, arm-none-eabi-gdb will still be required. In other environments, CMSIS-DAP programmers work perfectly via OpenOCD or pyOCD (this is a similar approach to OpenOCD, but it's initially focused on CMSIS-DAP/DAPLink devices and doesn't support the full range of programmers that OpenOCD can handle), so the choice of tools remains with the developer.

**BlackMagic**
It has a built-in GDB server. Thus, OpenOCD is not needed. You connect directly from arm-none-eabi-gdb and work.
*My subjective opinion - this is how a programmer should look.*

The standard BlackMagic Probe connects via USB and presents itself to the system as two CDC devices (on Linux — `ttyACM0`/`ttyACM1`, on macOS — `/dev/cu.usbmodemXXXX`/`/dev/cu.usbmodemXXXX1`): the first port is the GDB server, the second is UART passthrough. No drivers needed. Debugging starts with a single command:
```
# Linux
target extended-remote /dev/ttyACM0
# macOS
target extended-remote /dev/cu.usbmodem<serial>1
```

## GDB Clients

<div class="question-box">
  <img src="/think.png" alt="Question" />
  <strong>Why is arm-none-eabi-gdb always needed?</strong>
</div>
Actually, for the architecture. If you want to debug RISC-V or older ESP chips (Xtensa core), you'll need a GDB that supports that architecture.

<div class="question-box">
  <img src="/think.png" alt="Question" />
  <strong>What's the difference between them?</strong>
</div>
So the GDB client has started. And you want to begin debugging your .elf file. When you stop at a breakpoint, the GDB client receives the values of all registers from your target. And depending on the architecture, these registers are different — their number, purpose, and bit width differ from platform to platform. Plus, each architecture has its own set of assembly instructions.


<div class="question-box">
  <img src="/think.png" alt="Question" />
  <strong>What is an assembly instruction?</strong>
</div>
A binary file contains machine code — a sequence of bytes/words in hex format. An assembly instruction is a human-readable representation of one such machine command: for example, `0x2001` in Thumb2 is `MOVS R0, #1`. When you write an if statement somewhere, the compiler turns it into several machine instructions: a comparison and a conditional branch. To understand what these instructions are, they need to be translated back from machine code to assembly mnemonics. This is called disassembly.
Architectures encode instructions differently — a conditional branch in ARM Cortex-M is one set of bytes, in RISC-V it's another. This is what the GDB client does. And that's why they're different.
If you're writing for Linux x86, you'll have one hex read during a breakpoint on if(), in ARM Cortex-M another, in RISC-V a third. Even though you wrote the same thing in C. But you compiled for different architectures, so there will be different hex instructions.
I hope I've explained it clearly.
So it turns out that to interpret code, for example at a breakpoint, you need different GDB clients that understand how to interpret the instructions sent by our target.

<div class="question-box">
  <img src="/think.png" alt="Question" />
  <strong>Why not make one unified GDB then?</strong>
</div>
The instruction set is huge. And putting them all in one GDB is quite costly. That's probably a sufficient argument. But to be honest, it's not convincing to me. By the way, `gdb-multiarch` exists and supports multiple architectures at once — but it's less common in toolchains for specific platforms.

# A Bit About ELF Files
ELF (Executable and Linkable Format) is the standard executable file format in Unix-like systems and embedded platforms. Debug ELF files are built with DWARF sections, which store human-readable information: at what address in memory various functions are located, variable types, references to source files and line numbers. Thanks to this, the IDE can show the current line at a breakpoint and expand variable values.
If you look at the ELF file we use for debugging, it contains architecture information.

# Subjective Summary
All of this, in my opinion, is very poor. It feels like the community couldn't agree on some unified system and everyone is pulling in their own direction. After years of development, I've come to the conclusion that there's no good solution. But I settled on BlackMagic.
I have quite specific requirements for a debugger:
- I want to debug devices remotely
- Starting GDB servers annoys me
- Their configuration and all these config files annoy me
- I don't want to install drivers either
- I want to use a cross-platform lightweight IDE
- My programmer should be able to debug a wide range of targets: ARM Cortex-M/A/R, RISC-V

The BlackMagic probe gives me all of this. It has its drawbacks, but they're not in the list above. For example, support for displaying FreeRTOS threads in the IDE is partially implemented in BlackMagic and doesn't work as conveniently in all configurations as in JLink with Ozone or in OpenOCD with plugins. But frankly, this isn't such a serious drawback, because mechanisms remain that allow me to read the stack of each task at any time via GDB directly. It just won't be automatically displayed in the IDE tabs.

## blackmagic-esp32-c5

ESP32-C5 is a RISC-V microcontroller with built-in Wi-Fi and Bluetooth. An ideal candidate for a wireless network BMP: one chip, Wi-Fi out of the box, USB-C for power and flashing — no drivers needed.

The [blackmagic-esp32-c5](https://github.com/BareMetalTestLab/blackmagic-esp32-c5) project implements this idea fully:
- **Network GDB server** on port 2345 — connect with the command: `target extended-remote <ip>:2345` if using GDB directly, or configure in the IDE for a remote debugger
- **RTT via telnet** on port 2346 — target device log over the network without USB
- **Web interface** — drag & drop .bin file upload from browser
- **Settings storage** in NVS — configuration persists between reboots

The cost of the solution is the price of an ESP32-C5 chip. The project is open source. No additional hardware needed.