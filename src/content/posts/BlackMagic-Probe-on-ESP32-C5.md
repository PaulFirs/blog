---
title: "Black Magic Probe on ESP32-C5: A Wireless Debugger Without OpenOCD"
description: "How to turn an ESP32-C5 into a wireless Black Magic Probe: GDB over Wi-Fi or USB, RTT, a UART bridge, and a web interface — no OpenOCD, no drivers, no config files"
date: 2026-09-23
tags: ["Testing", "CICD", "Embedded"]
---

[In my previous article](https://habr.com/ru/articles/1006064/), I gave an overview of popular ways to debug embedded systems: GDB client -> GDB server (OpenOCD) -> debug probe -> target MCU. Back then I also formulated my [subjective requirements](https://habr.com/ru/articles/1006064/#:~:text=%D0%A1%D1%83%D0%B1%D1%8A%D0%B5%D0%BA%D1%82%D0%B8%D0%B2%D0%BD%D0%BE%D0%B5-,%D1%80%D0%B5%D0%B7%D1%8E%D0%BC%D0%B5,-%D0%92%D1%81%D0%B5%20%D1%8D%D1%82%D0%BE%20%D0%BD%D0%B0) for an "ideal" probe. And at that point I already had a minimally working prototype of one. So here is what my research in this direction has led to.

## A bit of context

In the previous article, I ended with a list of what I want from a debugging tool:

- Debug devices **remotely**
- **Don't start** GDB servers by hand
- **Don't configure** them or write configuration files
- **Don't install** drivers
- Use a **cross-platform, lightweight IDE**
- Support for a **wide range of targets**: ARM Cortex-M/A/R, RISC-V

Black Magic Probe ticks almost every box: the GDB server lives inside the probe firmware, OpenOCD is not needed, and there are no drivers to install. Yes, in the comments to the previous article people told me the target list has to be baked into the firmware and might not fit. It won't fit into an ESP32? Well, it did ;)
As for the IDE, you can use any. These interfaces are too simple for anything to be complicated. The wireless connection is established over TCP, which GDB supports, and the wired one is a plain VCP, which GDB also supports (more on that later).

During development, the wishlist only kept growing. 
- There's the ability to debug over a wire (why not)
- And support for RTT logging over the same `TCP` (via `telnet` or `nc`) or `VCP`
- I also want serial, so I can hook up to the target's UART and read it via `telnet` or `nc`. Also over `TCP` or `VCP`
- If I can't drop a firmware image into the web interface with drag & drop so that I don't even have to press any buttons, then why do any of this at all? **[Sarcasm]** The chip is detected automatically, and a default address is set — which you can change to whatever you need.
- Erasing should also be a single click
- Remember Wi-Fi access points, so it's convenient to use anywhere
- And if none of the known networks are around, spin up its own AP with default credentials. You can stay on it — but there will be no internet — or add the network you need and reboot.
- If I had built all of this and then had to look up the device's IP address every time, the project might as well be deleted, because none of it would make sense. So I added mDNS. As soon as the device connects to a network, you can open its page in that network by the name `blackmagic.local`. The same name is used in `telnet`.

## What's inside: network services

The firmware brings up four network services on the ESP32-C5:

| Port | Service                     | Purpose                                       |
| ---- | -------------------------- | --------------------------------------------- |
| 80   | HTTP                       | Web interface: OTA, Wi-Fi, pin configuration  |
| 2345 | GDB remote serial protocol | GDB server — the main service                 |
| 2346 | RTT console                | Segger RTT console of the target (telnet/nc)  |
| 2347 | Target serial              | UART bridge to the target board (telnet/nc)   |

Below I'll describe how to do things through the GDB terminal; this may be redundant — after all, I was trying to make my life *easier*. So if you're using an IDE, it will do all of this for you.

### GDB server (port 2345)

The heart of the project. Connecting from GDB looks like this:

```
(gdb) target extended-remote blackmagic.local:2345
(gdb) monitor swdp_scan
(gdb) attach 1
```

That is, **exactly the same `monitor swdp_scan` / `attach 1` commands as with a classic BMP**, only instead of `/dev/ttyACM0` it's `host:port`. No OpenOCD, no config files.

The `blackmagic.local` name can be used here too, as well as when connecting to RTT, etc.

`swdp_scan` means SWD. JTAG is supported as well: the ESP32-C5 has both SWD and JTAG modes; all lines (TMS/SWDIO, TCK/SWCLK, TDI, TDO/TRACESWO, TRST) are routed to GPIOs and **remapped on the fly** via the web interface.

### RTT (port 2346)

Segger's RTT (Real-Time Transfer) is a way to stream logs out of the target in real time over the debug interface, with almost no CPU overhead.

```
$ nc blackmagic.local 2346
```

or via telnet. Inside GDB, the control commands look like this:

```
(gdb) monitor rtt enable
(gdb) monitor rtt status
```

### Target serial (port 2347)

A UART bridge: whatever the target board writes to its UART is available over TCP on port 2347. Handy when the target logs to UART and you're not physically standing next to it.

**An honest confession:** the port currently conflicts with the ESP32's own logs (which also pour into UART0), so the service is in a "works, but with caveats" state. I believe a release build doesn't need the logs.

### Web interface (port 80)

There are three pages here:

**1. OTA firmware update.** You just drag a `.bin` file into the browser — and the board re-flashes itself. Drag & drop, nothing but a browser required. If you have the binary on your phone, you can flash from the phone too.

**2. Wi-Fi settings.** A list of SSIDs and passwords for the access points the board should connect to. Stored in NVS, survives a reboot.

**3. Pin configuration.** Which of the board's GPIOs are responsible for SWDIO/SWCLK/TDI/TDO/TRST. Also in NVS, also survives a reboot. You change them on the fly, no re-flashing needed. I added this just in case the board layout ever changes.

## First launch

Building is standard ESP-IDF:

```
idf.py set-target esp32c5
idf.py build
idf.py flash monitor
```

The frontend is built automatically via `npm install && npm run build` — CMake takes care of it, you don't have to run anything by hand.

After the first flash:

1. The board tries to connect to a saved Wi-Fi network
2. If that fails, it **brings up its own access point** with SSID `blackmagic` and password `blackmagic`
3. You connect to that AP, open `blackmagic.local` or `http://192.168.4.1`, and enter your own network's SSID/password
4. The board reboots and connects to your Wi-Fi
5. From then on, it is available as `blackmagic.local`

## GDB over USB

Wi-Fi is the main feature, but the wire is supported too. The firmware can work through **USB-Serial-JTAG** — a peripheral block built into ESP32-Cx chips that shows up in your system as a CDC device:

```
(gdb) target extended-remote /dev/ttyACM0    # Linux
(gdb) target extended-remote /dev/cu.usbmodem11101  # macOS
```

Meanwhile, logs/console stay on **UART0** (separate pins), so the USB peripheral is entirely dedicated to GDB and not shared with the console. All the features (`monitor swdp_scan`, `attach`, RTT) work over USB as well — essentially the BMP core code is the same, only the transport differs.

You can also build without USB GDB: there are flags in `CMakeLists.txt`:
- `ENABLE_USB_GDB` — enables USB debugging in the build
- `ENABLE_UART_SERIAL` — for now I kept serial as a separate switch, since I need the ESP's own log
- `ENABLE_RTT` — this flag is provided by BMP itself to enable RTT

## SDK config: pitfalls I ran into

This is the most "technical" part of the article — the nuances that aren't described in the documentation and had to be figured out experimentally.

**1. The `PARTITION_TABLE_SINGLE_APP_LARGE` partition table.** A firmware combining the BMP core + Wi-Fi + HTTP server + frontend **doesn't fit** into the default 1 MB app partition. I had to use the "large" 3 MB partition.

**2. `WHOLE_ARCHIVE` for the `esp32-platform` component.** The project contains `target_probe.c` with weak stubs of the probe functions, while the real implementations live in separate files. By default, the linker discards "unused" object files, and the strong symbols from those separate files **don't override** the weak stubs — the probe functions simply never get called, and the debugger sees no target. `WHOLE_ARCHIVE` forces the linker to take the whole archive, and the strong symbols win. I don't entirely understand why it works this way, but it does.

**3. Disabled watchdogs.** Target flashing and debugging operations (flash erase, JTAG transactions, long sequences) can exceed the `ESP_INT_WDT` and `ESP_TASK_WDT` timeouts — the system reboots in the middle of flashing the target. That's why both watchdogs are disabled in `sdkconfig.defaults`:

```
CONFIG_ESP_INT_WDT=n
CONFIG_ESP_TASK_WDT_EN=n
```

**4. Console on UART0:**

```
CONFIG_ESP_CONSOLE_UART_DEFAULT=y
CONFIG_ESP_CONSOLE_SECONDARY_NONE=y
```
so that USB-Serial-JTAG doesn't grab the console and stays entirely dedicated to GDB.

All of this is already in `sdkconfig.defaults` in the repository — you don't have to configure anything by hand.

## What about targets?

The firmware core is the original Black Magic Probe (thanks to the [blackmagic](https://github.com/blacksphere/blackmagic) community), so it supports **the entire range of targets BMP supports**: ARM Cortex-M, Cortex-A, Cortex-R, and RISC-V, over both SWD and JTAG.

Default pinout (for the ESP32-C5):

| Signal | GPIO |
|--------|------|
| TMS / SWDIO | 26 |
| TCK / SWCLK | 25 |
| TDI | 23 |
| TDO / TRACESWO | 24 |
| TRST | 27 |

As I mentioned, the pins can be remapped via the web interface and are stored in NVS.

## VS Code without configs

You can't do without some IDE setup in any case. I use VS Code, and there are no difficulties here because the `cortex-debug` extension supports BMP, so writing the config is quite simple. I made a configuration template: [bm-vscode-configs](https://github.com/BareMetalTestLab/bm-vscode-configs) — a repository with a ready-made `launch.json` for Cortex-Debug, including RTT. You copy it into your project; inside there's a `settings.json` template where you need to specify the path to the `.elf`, the path to the `.svd` if needed, and the target itself. Without that minimum there's no way around it. Then you can start debugging.

## Summary

The cost of this solution is the price of an ESP32-C5 chip. The project is open source: [blackmagic-esp32-c5](https://github.com/BareMetalTestLab/blackmagic-esp32-c5). No extra hardware. All my wishes are covered.

I certainly had no doubts myself, but many people doubted the quality of the wireless connection — everything will keep dropping, and so on. Maybe I got lucky, maybe I've simply never encountered a bad network in 2026, but a debugging session has never dropped on me for no reason.

## The board: everything in one USB

The firmware runs on a bare ESP32-C5 module, but to make full use of all the wired-debugging advantages described above, I designed a board that packs everything needed for debugging and brings it all into **a single USB port** — with a hub on board.

What's on the board:

| Device                    | What it gives                   | How it shows up in the system        |
| -------------------------- | ------------------------------- | ------------------------------------- |
| ESP32-C5 (USB-Serial-JTAG) | Flashing the ESP and GDB server | JTAG and CDC device, `/dev/ttyACM0` |
| USB-UART #1                | Target UART                     | second CDC                           |
| USB-UART #2                | Target RTT                      | third CDC                            |

![pcb](https://github.com/BareMetalTestLab/blackmagic-esp32-c5-hardware/blob/main/doc/photo/top.png?raw=true)

So no three separate cables and three separate adapters. Plug in one wire — and you get a wireless BMP, a wired GDB, and both of the target's UARTs. The order of `/dev/ttyACM*` stays stable, because the devices sit on the same hub and don't reconnect.

### Why this, if Wi-Fi already exists

Wi-Fi is the main feature, but the wire is still needed:
- for the first launch, to flash the ESP32;
- trivially, for power, if the target doesn't have its own;
- if for some reason the Wi-Fi bands are congested and the connection is unstable (hasn't happened to me yet);
- any other reason you might need a wired connection.