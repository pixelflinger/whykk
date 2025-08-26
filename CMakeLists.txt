cmake_minimum_required(VERSION 3.15)
# We define the project without any languages, as we will handle compilation
# with a custom command, bypassing CMake's tricky built-in language support.
project(y2kxxx)

# Find the vasm assembler executable.
# The 'REQUIRED' keyword makes CMake fail with a clear error if it's not found.
find_program(VASM_EXECUTABLE vasmm68k_mot REQUIRED
    HINTS "$ENV{HOME}/vasm" # Search in ~/vasm
)

# Print the assembler we found for confirmation
message(STATUS "Using vasm assembler: ${VASM_EXECUTABLE}")

# Define source and output file paths for clarity
set(SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/y2k.asm)
set(INCLUDE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/tos.i)
set(OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/y2k40.prg)

# This command defines exactly how to build the final executable from the source.
add_custom_command(
    OUTPUT ${OUTPUT_FILE}
    COMMAND ${VASM_EXECUTABLE} -Ftos -m68000 -o ${OUTPUT_FILE} ${SOURCE_FILE}
    DEPENDS ${SOURCE_FILE} ${INCLUDE_FILE}
    COMMENT "Assembling ${SOURCE_FILE} -> ${OUTPUT_FILE}"
    VERBATIM
)

# This creates a build target named 'y2kxxx'.
# Adding it to 'ALL' means it will be built by default with 'make' or 'ninja'.
add_custom_target(y2kxxx ALL
    DEPENDS ${OUTPUT_FILE}
)
