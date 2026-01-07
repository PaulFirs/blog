---
title: "CI/CD for Bare-Metal Embedded Development"
description: "Practical guide to automating build, flashing, and testing of microcontrollers"
date: 2025-11-05
tags: ["Testing", "CI/CD", "Embedded"]
---

# CI/CD for Bare-Metal Embedded Development

> Practical guide to automating build, flashing, and testing of microcontrollers

## Why is this needed?

Many embedded developers are used to working without automated tests, relying on manual testing and debugging via a programmer. This seems like a simple and quick solution for small projects. However, as the codebase and team grow, this approach leads to critical problems: bugs return in new releases, system knowledge is stored only in developers' heads, and every change requires lengthy manual testing on a bench.

CI/CD automation for embedded systems solves these problems, although it requires initial effort to set up the infrastructure.

### The harsh truth about embedded development

**Typical excuses without tests:**
- "It's a complex problem" = "I don't know where the bug is"
- "Need to test on the bench" = "Hope it works"
- "It's a hardware problem" = "Don't want to dig into the code"
    
**Tests provide objectivity:**
- Either the test passes
- Or the test fails
- Or there are no tests

**A situation that repeats in 90% of companies:**
- Found a bug on the bench (at best, if there is a bench)
- Developer debugs for a week via J-Link
- Changes one line of code
- "Fixed it!"
- Commits only the fix without tests
- After 2 months the bug returns in a new release
- New developer spends another week searching

**What really happens:**
```c
// BAD: typical "fix" through debugging
// Was:
if (adc_value > threshold) {
    set_alarm();
}

// Became after 5 days of debugging:
if (adc_value > threshold && !is_calibrating) {
    set_alarm();
}
```

**Nobody will know:**
- Why exactly this logic?
- What edge cases were considered?
- How to reproduce the problem?
- What was checked?

**The right approach: Test-Driven Bug Fixing:**
```c
// 1. Write a test that fails
TEST(AlarmTest, ShouldNotTriggerDuringCalibration) {
    start_calibration();
    set_adc_value(threshold + 100); // Value above threshold
    
    process_alarm_logic();
    
    ASSERT_FALSE(alarm_triggered()); // Test fails!
}

// 2. Fix the code
if (adc_value > threshold && !is_calibrating) {
    set_alarm();
}

// 3. Test passes
// 4. Now we have a regression test FOREVER
```

### Benefits for management

**Developer report without tests:**
- "Fixed a bug with false alarm triggers"
- Time: 5 days
- Changes: 1 line of code
- Guarantees: "seems to work"

**System report with tests:**
- Added regression tests (including one reproducing the bug): 150 lines
- Fixed bug: 3 lines
- Code coverage: +15%
- Guarantees: automatic check on every commit

### Benefits for developers

**Without tests:**
- "Need to remember all my workarounds" — cognitive load
- "This bug returned again" — endless refactoring of the same places
- "It's not my bug, hardware is glitching" — constant disputes with hardware team
- "Need to flash 10 boards manually" — boring routine instead of development

**With tests:**
- "My 100 tests confirm the fix works" — confidence in code
- "CI failed — my code broke something" — instant feedback
- "Here's a test proving the hardware problem" — documented bug reports
- "Flashed 10 boards with one commit" — automated routine

### Benefits for the team

**Without tests:**
- "Who broke this?" — looking for culprits instead of solving problems
- "Only Vasya's works, let him fix it" — knowledge bottleneck
- "We can't hire a new developer — they won't understand anything" — bus factor = 1
- "This is legacy code, better not touch it" — fear of changes

**With tests:**
- "CI showed that Peter broke GPIO" — objective diagnosis
- "Anyone can modify code — tests will catch issues" — collective ownership
- "Newcomer wrote working feature in a week" — fast onboarding
- "Refactor confidently — 200 tests confirm functionality" — architecture evolution

### Benefits for the product

**Without tests:**
- "Release and pray" — Russian roulette with releases
- "Worked on the bench..." — gap between dev and prod
- "Client found a bug we didn't see for 2 years" — market embarrassment
- "Can't add features — everything will fall apart" — technical debt

**With tests:**
- "Release every Tuesday" — predictable process
- "CI tests on real hardware" — identical bench and production
- "Client bugs reproduced in 5 minutes" — fast response
- "Adding features without fear" — development speed

### Why might this not be needed?

If your goal is to become an "irreplaceable" developer, the only person who understands the code and can fix it, then automated testing really isn't for you. Tests make code transparent, understandable, and accessible to the entire team.

**Your career strategy without tests:**
- "This is a very complex system" = "Only I know how it works"
- "Better not touch it" = "My job security"
- "Need deep context" = "I'm irreplaceable"
- "This is legacy code" = "My personal family jewel"

## General pipeline

### What's required for minimal CI?

The bare minimum is to at least build the project and flash the microcontroller. Sounds simple, but in practice situations often arise where a project builds for one developer but not for another. This can be due to different compiler versions, missing dependencies, or code changes that broke the build for certain environments.

Finding the cause of such problems can take hours. CI solves this problem: each commit is automatically built in a clean environment, guaranteeing that the build isn't broken and the project can be reproduced on any machine.

Let's examine the necessary tools with a concrete example.

### Required components

1. **GitHub or GitLab** — version control system with CI/CD support. All examples in this article will be for GitHub. Simply create a new repository, we'll return to it later.

2. **Build and test server** — this can be a regular computer, Raspberry Pi, or even a virtual machine. GitHub provides free servers (runners), but with time execution limitations. For embedded development where access to real hardware is needed, typically a self-hosted runner is used.
   
   **Alternative: VCON** — third-party service for remote device access. Used, for example, by the Mongoose project. Works like this: ESP32 with VCON firmware connects to Wi-Fi and registers on their server, playing the role of over-the-air programmer. Target device connects to it, and through CI you can upload firmware, read logs, etc.
   
   **VCON Pros:**
   - Everything ready to use out of the box
   - No need to configure own server
   - Access to device from anywhere in the world
   
   **VCON Cons:**
   - Device limitations
   - Dependency on external service
   - Non-standard programmer (not suitable for field use)

3. **Programmer** — I'll consider J-Link, as it provides convenient tools for working with RTT (Real-Time Transfer). Technically you can use any programmer (ST-Link, CMSIS-DAP, etc.), but J-Link gives more automation capabilities.

4. **Target device or development bench** — microcontroller or board on which tests will run.

### CI Architecture for embedded systems

```
┌─────────────┐         ┌──────────────────┐         ┌────────────────┐
│   GitHub    │────────>│  Self-hosted     │────────>│   J-Link       │
│ Repository  │         │    Runner        │         │  Programmer    │
│             │         │  (Linux/Mac/Win) │         │                │
└─────────────┘         └──────────────────┘         └────────┬───────┘
                                                               │
                                                               │ SWD/JTAG
                                                               │
                                                               v
                                                        ┌──────────────┐
                                                        │  Target MCU  │
                                                        │ (STM32F103)  │
                                                        └──────────────┘
```

For regular software, cloud CI servers from GitHub/GitLab are sufficient — you can test on different operating systems without additional equipment. But in embedded development, access to real hardware is needed, so a self-hosted server with connected programmer and target device is required.

If you only need to verify that firmware builds, standard GitHub Actions without hardware are sufficient. But for full functional testing, a self-hosted runner is needed.

### Software on the server

1. **GitHub Actions Runner** — agent that executes CI tasks. Downloaded and registered in your repository through GitHub settings (Settings → Actions → Runners → New self-hosted runner). After registration, runs as a background service and waits for commands from GitHub. You can run multiple runners for different devices, marking them with tags.

2. **J-Link Software** — utilities for working with J-Link programmer. Includes command-line tools for flashing and reading RTT. I recommend J-Link specifically thanks to SEGGER RTT — fast debug output technology without delays.

3. **CMake** (or other build system) — the example uses CMake as a cross-platform meta-build system. You can use Make, Meson, or other tools of your choice.

4. **Python** — for automating flashing and analyzing test results. The `pylink` library allows programmatic J-Link control.

5. **ARM GCC Toolchain** — compiler for ARM microcontrollers (`arm-none-eabi-gcc`).

**Installing necessary packages on Ubuntu/Debian:**
```bash
# ARM toolchain
sudo apt-get install gcc-arm-none-eabi

# CMake
sudo apt-get install cmake

# Python and dependencies
sudo apt-get install python3 python3-pip
pip3 install pylink-square
```

## Project example with CI

### runit project structure

Let's examine a real example from the `runit` library — a framework for unit testing on bare-metal systems:

```
runit/
├── .github/
│   ├── workflows/
│   │   └── build.yml           # CI configuration
│   └── scripts/
│       ├── flashing.py         # Flashing script
│       └── units.py            # Test running script
├── src/
│   ├── runit.h                 # Library header
│   └── runit.c                 # Implementation
├── examples/
│   └── f103re-cmake-baremetal-builtin/
│       ├── CMakeLists.txt      # Build configuration
│       ├── main.c              # MCU tests
│       ├── startup_stm32f103xe.s
│       └── STM32F103RETX_FLASH.ld
└── tst/
    └── selftest.c              # Linux tests
```

### GitHub Actions Workflow

Create CI with five stages:
1. Clone repository to server
2. Configure CMake
3. Build project
4. Flash microcontroller
5. Run tests on device

**File `.github/workflows/build.yml`:**

```yaml
name: Build Runit Selftest

on: [pull_request]

jobs:
  # Job 1: Linux testing (without hardware)
  linux_build:
    runs-on: self-hosted

    steps:
      - uses: actions/checkout@v4

      - name: Configure and Build project
        run: |
          cmake -S . -B build
          cmake --build build

      - name: Run selftest
        run: ./build/runit-selftest

  # Job 2: STM32F103 testing (with real hardware)
  stm32f103re_build:
    runs-on: self-hosted

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 1

      - name: Configure and Build project
        run: |
          cmake -S examples/f103re-cmake-baremetal-builtin -B examples/f103re-cmake-baremetal-builtin/build
          cmake --build examples/f103re-cmake-baremetal-builtin/build

      - name: Flash firmware
        run: |
          python3 .github/scripts/flashing.py ${{ secrets.JLINK_SERIAL_CI_STM32F103RE }} STM32F103RE examples/f103re-cmake-baremetal-builtin/build/example_f103re.bin

      - name: Unit tests
        run: |
          python3 .github/scripts/units.py ${{ secrets.JLINK_SERIAL_CI_STM32F103RE }} STM32F103RE
```

**Important points:**

- `runs-on: self-hosted` — specifies using own runner, not GitHub cloud server
- `secrets.JLINK_SERIAL_CI_STM32F103RE` — secret variable with J-Link programmer serial number. Configured in Settings → Secrets → Actions of your repository. This protects your device from unauthorized access.
- Two independent jobs run in parallel: one for Linux version of library, another for microcontroller.

### Detailed stage breakdown

#### Stage 1: Linux build (cross-platform verification)

The `runit` library is cross-platform — works both on microcontrollers and regular OSes. So the first job simply builds and runs tests on Linux:

```bash
cmake -S . -B build
cmake --build build
./build/runit-selftest
```

If executable returns exit code not equal to 0, CI is considered failed. This is the standard approach for unit tests in Unix systems.

#### Stages 2-5: Build, flash, and test on STM32

Now let's move to the most interesting part — automated flashing and testing on real microcontroller:

**1. Project build**

```bash
cmake -S examples/f103re-cmake-baremetal-builtin -B examples/f103re-cmake-baremetal-builtin/build
cmake --build examples/f103re-cmake-baremetal-builtin/build
```

At this stage we guarantee the project builds without errors. If build fails — the problem is localized, and we know that changes broke compilation.

**Bonus:** Binary file can be saved in GitHub Actions artifacts and used for flashing a batch of devices or provided to team for testing without needing to build locally.

**2. Microcontroller flashing**

Python script `.github/scripts/flashing.py` is used:

```python
import sys, os
import pylink
from pylink import JLink

def flash_device_by_usb(jlink_serial: int, fw_file: str, mcu: str) -> None:
    jlink = pylink.JLink()
    jlink.open(serial_no=jlink_serial)

    if jlink.opened():
        jlink.set_tif(pylink.enums.JLinkInterfaces.SWD)
        jlink.connect(mcu)
        print(jlink.flash_file(fw_file, 0x08000000))
        jlink.reset(halt=False)

    jlink.close()

def main():
    try:
        jlink_serial = int(sys.argv[1].strip())
        mcu = sys.argv[2].strip()
        fw_file = os.path.abspath(sys.argv[3].strip())
        flash_device_by_usb(jlink_serial, fw_file, mcu)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

Script accepts three parameters:
- J-Link programmer serial number
- MCU name (e.g., `STM32F103RE`)
- Path to firmware binary file

If flashing fails, script returns error code 1, and CI stops.

**3. Run tests and read results via RTT**

The most interesting part — how to get test results from microcontroller?

#### SEGGER RTT — fast data transfer technology

**SEGGER RTT (Real-Time Transfer)** — bidirectional data transfer technology between target device and host via debug interface (SWD/JTAG). Developed by SEGGER.

**RTT advantages:**
- **High speed** — up to 2 MB/sec
- **No delays** — doesn't block program execution
- **No additional pins required (like UART or SWO)** — uses existing debug interface. So even without SWO this solution works
- **Bidirectional communication** — can not only read data but send commands

**How it works:**
1. Small buffer allocated in MCU RAM (usually 1-16 KB)
2. MCU code writes data to this buffer (`SEGGER_RTT_printf()`)
3. Programmer reads data from buffer via SWD/JTAG
4. Python script on host receives and analyzes this data

**RTT disadvantage:** Limited buffer size. If there are too many logs and they don't get read in time, overwriting occurs and some data is lost. Solution — increase buffer size or optimize log output.

#### Python script for running tests

File `.github/scripts/units.py`:

```python
import sys, re, time
import pylink
from pylink import JLink

def remove_ansi_colors(text: str) -> str:
    """Remove ANSI color codes from text"""
    return re.sub(r"\x1b\[[0-9;]*m", "", text)

def run_tests_by_rtt(jlink: JLink, duration: float = 10.0) -> bool:
    has_error = False
    try:
        jlink.rtt_start()
        start_time = time.time()
        
        while True:
            elapsed = time.time() - start_time
            if elapsed >= duration:
                break
                
            response = jlink.rtt_read(0, 1024)
            if response:
                text = remove_ansi_colors(bytes(response).decode("utf-8", errors="ignore"))
                
                # Parse test results
                for line in text.splitlines():
                    # Look for report lines: "REPORT | File: ... | Passes: X | Failures: Y"
                    match = re.search(
                        r'REPORT\s*\|\s*File:\s*(.*?)\s*\|\s*Test case:\s*(.*?)\s*\|\s*Passes:\s*(\d+)\s*\|\s*Failures:\s*(\d+)',
                        line
                    )
                    if match:
                        passed = match.group(3)
                        failed = match.group(4)
                        print(f"Test result: {passed} passed, {failed} failed")
                        if failed != '0':
                            has_error = True
                    elif "All tests passed successfully!" in line:
                        has_error = False
                        print("All tests passed successfully!")
                    elif line.strip():
                        print(line)
                        
    finally:
        jlink.rtt_stop()
    
    return has_error

def main():
    jlink_serial = int(sys.argv[1].strip())
    mcu = sys.argv[2].strip()
    
    jlink = pylink.JLink()
    jlink.open(serial_no=jlink_serial)
    jlink.set_tif(pylink.enums.JLinkInterfaces.SWD)
    jlink.connect(mcu)
    
    has_error = run_tests_by_rtt(jlink, 10.0)
    
    jlink.close()
    
    if has_error:
        sys.exit(1)

if __name__ == "__main__":
    main()
```

**How it works:**
1. Script connects to J-Link programmer
2. Starts RTT connection
3. Microcontroller after reset starts executing tests and outputs results via `SEGGER_RTT_printf()`
4. Script reads output in real-time (10 seconds)
5. Parses results by pattern and determines if tests passed
6. Returns error code if there are failed tests

#### Example code with tests on MCU

File `examples/f103re-cmake-baremetal-builtin/main.c` contains runit library self-testing:

```c
#include <stm32f103xe.h>
#include "runit.h"

static size_t expected_failures_counter = 0;

#define SHOULD_FAIL(failing)      \
    printf("Expected failure: "); \
    expected_failures_counter++;  \
    failing

static void test_eq(void)
{
    runit_eq(12, 12);
    runit_eq(12.0f, 12U);
    SHOULD_FAIL(runit_eq(100, 1));  // This test should fail
}

static void test_gt(void)
{
    runit_gt(100, 1);
    SHOULD_FAIL(runit_gt(1, 100));  // This test should fail
}

static void test_fapprox(void)
{
    runit_fapprox(1.0f, 1.0f);
    runit_fapprox(1.0f, 1.000001f);
    SHOULD_FAIL(runit_fapprox(1.0f, 1.1f));  // This test should fail
}

int main(void)
{
    test_eq();
    test_gt();
    test_fapprox();
    runit_report();  // Outputs final report
    
    if (expected_failures_counter != runit_counter_assert_failures)
        printf("Expected %u failures, but got %u\n", 
               expected_failures_counter, runit_counter_assert_failures);
    else
        printf("All tests passed successfully!\n");

    for (;;) {}  // Infinite loop
    return 0;
}
```

**Important:** For RTT output, the `_write` function is redefined to use `SEGGER_RTT_PutChar()`. This allows using standard `printf()` in test code, and all output automatically goes to RTT buffer.

Example of `_write` redefinition in `syscalls.c` file:

```c
#include "SEGGER_RTT.h"

__attribute__((weak)) int _write(int file, char* ptr, int len)
{
    for (int i = 0; i < len; i++)
    {
        SEGGER_RTT_PutChar(0, ptr[i]);
    }
    return len;
}
```

The `weak` attribute allows redefining this function elsewhere in the project if needed.

The `runit_report()` function outputs one line with cumulative statistics of executed tests. You can call `runit_report()` multiple times in different places of the program — each call will output a separate report with accumulated statistics. To reset counters between test groups, you need to zero internal library variables.

RTT output looks like this:
```
REPORT | File: main.c:42 | Test case: main | Passes: 5 | Failures: 3
All tests passed successfully!
```

Python script parses this output and determines the result.

### Extended testing capabilities

#### Test organization strategies

Your project may have multiple build targets:

1. **Production build** — final production firmware without debug code
2. **Test build** — special version with unit tests for libraries and modules
3. **Debug build** — working firmware with `DEBUG` flag, where self-test module is enabled by conditional compilation

Choice of approach depends on your needs and capabilities:

**Option 1: Separate test project**
```cmake
# CMakeLists.txt for tests
add_executable(firmware_tests
    tests/test_main.c
    tests/test_uart.c
    tests/test_modbus.c
    src/uart.c
    src/modbus.c
)
```

**Option 2: Conditional test compilation**
```c
#ifdef DEBUG_TESTS
static void run_all_tests(void) {
    test_uart();
    test_modbus();
    test_eeprom();
    runit_report();
}
#endif

int main(void) {
    system_init();
    
    #ifdef DEBUG_TESTS
    // Tests run on command via RTT
    if (check_rtt_command("run_tests")) {
        run_all_tests();
    }
    #endif
    
    // Main firmware code
    while(1) {
        main_loop();
    }
}
```

Personally, I use the build flag approach and added the ability to invoke tests via RTT commands. This allows:
- Not rebuilding firmware to run tests
- Running tests at any time on running device
- Testing specific modules on demand

#### Protocol and interface testing

Python script can interact not only with microcontroller via RTT but also test production firmware via real interfaces:

**Example: Modbus RTU testing**

Device should communicate via Modbus RTU. Connect it to CI server via corresponding interface and run Python tests:

```python
import serial
from pymodbus.client import ModbusSerialClient

def test_modbus_valid_requests():
    """Check valid requests"""
    client = ModbusSerialClient(port='/dev/ttyUSB0', baudrate=9600)
    
    # Read registers
    result = client.read_holding_registers(address=0, count=10, slave=1)
    assert not result.isError(), "Registers should read correctly"
    assert len(result.registers) == 10
    
    # Write register
    result = client.write_register(address=0, value=100, slave=1)
    assert not result.isError(), "Should be able to write"
    
    # Check write
    result = client.read_holding_registers(address=0, count=1, slave=1)
    assert result.registers[0] == 100, "Value should persist"

def test_modbus_invalid_requests():
    """Check invalid request handling"""
    client = ModbusSerialClient(port='/dev/ttyUSB0', baudrate=9600)
    
    # Non-existent address
    result = client.read_holding_registers(address=9999, count=1, slave=1)
    assert result.isError(), "Should return error for non-existent address"
    
    # Corrupted data (wrong CRC)
    # Device should ignore such packets
    with serial.Serial('/dev/ttyUSB0', 9600) as ser:
        ser.write(b'\x01\x03\x00\x00\x00\x0A\xFF\xFF')  # Wrong CRC
        time.sleep(0.5)
        response = ser.read_all()
        assert len(response) == 0, "Corrupted packets should be ignored"

if __name__ == "__main__":
    test_modbus_valid_requests()
    test_modbus_invalid_requests()
    print("All Modbus tests passed!")
```

Such tests verify:
- Correct handling of valid data
- Proper input data validation
- Predictable behavior with incorrect requests
- Protocol specification compliance

Similarly you can test:
- **CAN interface** — sending/receiving messages, bus error handling
- **Ethernet/TCP** — connection establishment, link break handling
- **I2C/SPI** — peripheral interaction
- **GPIO** — signal level checking, timing
- **Performance measurement** — response time, throughput

#### Main argument for implementing CI

**For those who care but are lazy:**

No more need to:
- Convince yourself to retest everything after each change
- Worry something broke if you didn't retest
- Remember which modules depend on changed code
- Spend time manually testing same scenarios

**CI does this for you:**
- Retests all scenarios automatically
- Points exactly where the problem is
- Runs on every Pull Request
- Added a new test? It runs forever

**Real time savings:**
Made changes to UART library? CI automatically runs:
- Unit tests of library itself
- Integration tests with Modbus (which uses UART)
- Communication protocol tests
- Memory leak checks
- Timing validation

All this — without your involvement, in minutes, with exact indication of problem location.

**Example from real project:**
In the [BMPLC](https://github.com/RoboticsHardwareSolutions/BMPLC_Quick_Project) device, EEPROM library work is automatically tested (in local development, tests can also be run manually via RTT interface commands). Test suite checks critical memory operation scenarios:

```c
void run_eeprom_tests(void) {
    eeprom_partial_page_write_test();     // Partial page write correctness
    eeprom_size_limit_test();             // Protection from memory bounds overflow
    eeprom_multi_page_write_test();       // Multi-page write (several pages at once)
    eeprom_random_access_test();          // Random access to different addresses
    runit_report();
}
```

These tests reveal typical problems:
- Address space bounds overflow (32 KB for AT24C256)
- Errors when writing data larger than page size
- Basic write and read correctness checks

**Important point:** From constant CI runs, test device can exhaust EEPROM resource (usually 100,000 - 1,000,000 write cycles). Similarly, MCU Flash memory degrades from frequent flashing. But this is a small price for code quality confidence — replacing one test device costs incomparably less than an error in production.

If tests suddenly start failing:
- Run old, verified firmware version → tests pass → memory works, problem in new code
- Run old version → tests fail → test device exhausted resource, replace it

Without automatic tests, such library error could get into production and lead to data corruption on all devices requiring mass reflashing.

## Step-by-step implementation guide

### Step 1: Repository preparation

1. Create repository on GitHub
2. Add `.github/workflows/build.yml` with CI configuration
3. Create `.github/scripts/` folder for Python scripts

### Step 2: Server setup

1. Install necessary dependencies:
   ```bash
   sudo apt-get install gcc-arm-none-eabi cmake python3 python3-pip
   pip3 install pylink-square
   ```

2. Download J-Link Software from SEGGER website

3. Register GitHub Actions Runner:
   - Open Settings → Actions → Runners → New self-hosted runner
   - Follow instructions for your OS
   - Run runner as service

### Step 3: Equipment connection

1. Connect J-Link to server via USB
2. Connect target device to J-Link via SWD/JTAG
3. Check connection: `JLinkExe` → `connect` → specify MCU
4. Find serial number: `$ lsusb -v` or via `JLinkExe` utility

### Step 4: Secrets configuration

1. In repository: Settings → Secrets and variables → Actions → New repository secret
2. Add `JLINK_SERIAL_CI` with programmer serial number

### Step 5: Adding tests

1. Integrate `runit` (or other test framework) into your project:
   ```bash
   git submodule add https://github.com/RoboticsHardwareSolutions/runit.git libs/runit
   ```

2. Add [SEGGER RTT](https://github.com/SEGGERMicro/RTT.git) to project (via CMake FetchContent or manually)

3. Write tests in `runit` style:
   ```c
   void test_my_function(void) {
       runit_eq(my_function(5), 25);
       runit_gt(my_function(10), 90);
   }
   ```

4. In `main()` call tests and `runit_report()`

### Step 6: First run

1. Create Pull Request
2. GitHub Actions automatically starts CI
3. Check execution logs
4. If needed, debug by running tests locally with same scripts

## Conclusion

CI/CD automation for embedded systems requires initial effort but pays off many times over:

- Accelerated development through fast feedback
- Protection from regressions and repeat bugs
- Objective code quality metrics
- Simplified teamwork and onboarding
- Confidence in every release

The `runit` library and described approach are just a starting point. You can extend the testing system for your needs: add coverage analysis, integration with test benches, automatic release creation, and much more.

Start small — automate build and basic tests. Gradually add new checks. And remember: every automatic test is an investment in stability and speed of your development.

## Useful links

- [runit on GitHub](https://github.com/RoboticsHardwareSolutions/runit.git) — unit testing framework
- [SEGGER RTT](https://github.com/SEGGERMicro/RTT.git) — RTT documentation
- [pylink-square](https://github.com/Square/pylink) — Python library for J-Link
- [GitHub Actions](https://docs.github.com/en/actions) — CI/CD documentation
