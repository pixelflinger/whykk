# WHYKK - A Y2K Fix for Atari ST

`WHYKK` is a small patch for Atari ST computers that fixes the infamous
Y2K bug. It works as a memory-resident program, intercepting system calls to
make sure the ST can handle dates beyond 1999.

## Usage

To use the patch, copy the `WHYKK.PRG` file to the `AUTO` folder on
your Atari ST's boot disk. The program will then be automatically executed at
startup, patching the system.

### When not to use this patch

This patch is unnecessary on machines that have an integrated battery-backed
RTC, such as the MegaSTE, TT or Falcon030. However, external solutions like
ACSI2STM or UltraSATAN may need it depending on how they intercept the
system calls.

## Building

To build `WHYKK.PRG`, you will need:

* [CMake](https://cmake.org/)
* [vasm m68k assembler](http://sun.hasenbraten.de/vasm/)

The build process is configured in `CMakeLists.txt`. To compile the utility, run
the following commands:

```bash

mkdir build
cd build
cmake ..
make
```

This will generate the `WHYKK.PRG` file in the `build` directory.


## The Y2K bug on Atari ST

The Y2K (Year 2000) bug on the Atari ST is due to a conflict between 
two operating system layers: GEMDOS (the disk operating system) and XBIOS 
(the extended BIOS).

### GEMDOS vs. XBIOS

On an Atari ST, both GEMDOS and XBIOS are involved in managing the system date
and time.

*   **GEMDOS:** Provides the primary date/time API for applications (`Tsetdate`,
    `Tgetdate`, etc.). It maintains the current date and time in system memory.

*   **XBIOS:** Provides a lower-level interface to the hardware responsible for
    keeping time, which is either a Real-Time Clock (RTC) chip or the
    Intelligent Keyboard (IKBD) processor.

The two layers synchronize with each other at specific moments:

1.  When an application sets the date using the GEMDOS `Tsetdate` function,
    GEMDOS validates the parameters and calls the corresponding XBIOS function 
    to update the underlying hardware.

2.  When a program terminates, GEMDOS re-synchronizes its internal clock from
    XBIOS. This ensures the time is correct even if the terminating program had
    taken over system timers for its own use, which was rather common.

3. On TOS 1.06 and above, GEMDOS is re-synchronized during the boot sequence 
   from either the IKBD or the Real-Time Clock if present. Unfortunately, 
   this is done by accessing the hardware directly, bypassing the XBIOS.

4. And finally, TOS 2.06 and above also systematically synchronizes the GEMDOS 
   from the XBIOS `settime` function!

### The Source of the Bug: XBIOS and the IKBD

The Y2K problem does **not** originate in GEMDOS. The GEMDOS date format is
identical to FAT16: the year is stored as a 7-bit offset from 1980. This
allows for years up to 2107 (1980 + 127), although GEMDOS itself
limits it to 2099, likely to avoid to correct for 2100 which is not a leap
year.

The real problem lies with machines that lack a battery-backed Real-Time Clock
(RTC), such as the Atari ST and STE models. On these systems, the XBIOS relies
on the **IKBD (Intelligent Keyboard)** to maintain the date and time between
program launches and warm reboots (on TOS versions 1.06 and later).

The IKBD's firmware was designed to handle only years between 1900 and 1999.
However, the GEMDOS/XBIOS API uses 1980 as its starting point (year 0). This
mismatch is the root of the problem:

*   The API expects a year value relative to 1980.
*   The IKBD can only store years up to 1999.

The result is an effective date range of only **1980 to 1999**. Any attempt to
set a date outside of this range through the standard system calls will
fail.

### Other Y2K-Related Issues

It is worth noting that other Y2K-related issues exist at the application
level, separate from the XBIOS bug this patch addresses.

*   **Display glitches:** Some applications may not display years past 1999
    correctly, even if the underlying system date is accurate. This is
    typically a cosmetic issue.
*   **Control Panel limitation:** The standard Atari Control Panel accessory
    (`CONTROL.ACC` or `XCONTROL.ACC`) uses a two-digit year input. 
    This limits its effective range to **1980-2079**. After the year 2079, an 
    alternative utility will be required to set the system date.

### The Solution: An XBIOS Intercept

Since the problem is confined to the XBIOS interaction with the IKBD, we can
fix it by "lying" to the XBIOS and consequently the IKBD.

1.  **When setting the time:** The patch intercepts the year value. If the year
    is 2000 or later, it subtracts an offset (e.g., 32 years) before
    passing it to the original XBIOS routine. For example, the year 2024
    becomes 1992, which the IKBD can handle.
2.  **When reading the time:** The patch intercepts the year value coming from
    the IKBD and adds the same offset back. The year 1992 becomes 2024 again,
    and this corrected value is returned to the caller.

The offset is automatically calculated based on the target year and must be a 
multiple of 4 to ensure leap years are handled correctly.
Because the IKBD's effective range is only 20 years (1980-1999), this patch
cannot use a fixed offset as the later needs to be updated every 20 years. This
problem happened in 2021 with previous patches, such as `Y2KFIX`.

#### Complications

This interception method, while effective, introduces two main complications:

1.  **TOS 2.06+ `settime` anomaly:** On TOS versions 2.06 and later, a call to
    the XBIOS `settime` function has the curious side effect of also
    updating the GEMDOS system clock. This behavior, which appears to be
    redundant, directly conflicts with our patch. When `WHYKK` passes an
    adjusted year (e.g., 1992 for 2024) to `settime`, this incorrect year is
    immediately propagated back to GEMDOS, defeating the purpose of the patch. 
    This issue is resolved by bypassing the code that updates GEMDOS.

2.  **State loss on warm reset:** After a warm reset (e.g., pressing the reset
    button), `WHYKK.PRG` loses its internal state, including the calculated
    year offset. When GEMDOS later resynchronizes its clock from the IKBD,
    `WHYKK` intercepts the call but doesn't know the correct offset to add back
    to the year. To work around this, the patch assumes a fixed offset of 32
    years upon the first clock read after a reset. This hardcoded value works
    correctly for years in the range of 2012-2031. Outside of this range, the
    date will be incorrect after a warm reset until it is set again manually.


### Technical details

The root of the problem with TOS 2.06+ `settime` function is that it updates 
the GEMDOS's date and time too. This is done by the first two instructions of
`settime`:

```ASM
settime:
    MOVE.W 4(sp), gemdos_time
    MOVE.W 6(sp), gemdos_date
    ...
```

This is addressed by finding the XBIOS jumptable to extract the location of
`settime` and, if necessary, modifying it to skip the two offending 
instructions. The resulting address is used to call `settime` directly from
our XBIOS hook.

> This mechanism relies on undocumented behavior, but should be reliable in
> practice.

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own
risk.
