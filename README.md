# Y2KXXX - A Y2K Fix for Atari ST

This project provides a patch for Atari ST computers to address the Year 2000 (
Y2K) bug. It's a small, memory-resident program that intercepts system calls to
ensure that dates are handled correctly beyond the year 1999.

## How it Works

The program, `y2k.asm`, is a Terminate and Stay Resident (TSR) application. When
executed, it installs a new handler into the XBIOS vector chain.

## Building the Project

To build this project, you will need:

* [CMake](https://cmake.org/)
* [vasm m68k assembler](http://sun.hasenbraten.de/vasm/)

The build process is configured in `CMakeLists.txt`. To compile the program, run
the following commands:

```bash

mkdir build
cd build
cmake ..
make
```

This will generate the `y2k40.prg` file in the `build` directory.

## Usage

To use the patch, copy the generated `y2k40.prg` file to the `AUTO` folder on
your Atari ST's boot disk. The program will then be automatically executed at
startup, patching the system.

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own
risk.
