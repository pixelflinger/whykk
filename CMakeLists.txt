cmake_minimum_required(VERSION 3.15)
# We define the project without any languages, as we will handle compilation
# with a custom command, bypassing CMake's tricky built-in language support.
project(whykk)

# Find the vasm assembler executable.
# The 'REQUIRED' keyword makes CMake fail with a clear error if it's not found.
find_program(VASM_EXECUTABLE vasmm68k_mot REQUIRED
    HINTS "$ENV{HOME}/vasm" # Search in ~/vasm
)

# Print the assembler we found for confirmation
message(STATUS "Using vasm assembler: ${VASM_EXECUTABLE}")

# Common include file for all targets
set(INCLUDE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/tos.i)

# --- WHYKK Target ---
set(WHYKK_SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/whykk.asm)
set(WHYKK_OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/whykk.prg)

add_custom_command(
    OUTPUT ${WHYKK_OUTPUT_FILE}
    COMMAND ${VASM_EXECUTABLE} -nosym -Ftos -m68000 -o ${WHYKK_OUTPUT_FILE} ${WHYKK_SOURCE_FILE}
    DEPENDS ${WHYKK_SOURCE_FILE} ${INCLUDE_FILE}
    COMMENT "Assembling ${WHYKK_SOURCE_FILE} -> ${WHYKK_OUTPUT_FILE}"
    VERBATIM
)

add_custom_target(whykk ALL
    DEPENDS ${WHYKK_OUTPUT_FILE}
)

# --- TIMEKPR Target ---
set(TIMEKPR_SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/timekpr.asm)
set(TIMEKPR_OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/timekpr.prg)

add_custom_command(
    OUTPUT ${TIMEKPR_OUTPUT_FILE}
    COMMAND ${VASM_EXECUTABLE} -nosym -Ftos -m68000 -o ${TIMEKPR_OUTPUT_FILE} ${TIMEKPR_SOURCE_FILE}
    DEPENDS ${TIMEKPR_SOURCE_FILE} ${INCLUDE_FILE}
    COMMENT "Assembling ${TIMEKPR_SOURCE_FILE} -> ${TIMEKPR_OUTPUT_FILE}"
    VERBATIM
)

add_custom_target(timekpr ALL
    DEPENDS ${TIMEKPR_OUTPUT_FILE}
)
