cmake_minimum_required(VERSION 3.15)
# We define the project without any languages, as we will handle compilation
# with a custom command, bypassing CMake's tricky built-in language support.
project(whykk)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Release" "RelWithDebInfo")
endif()

# Find the vasm assembler executable.
# The 'REQUIRED' keyword makes CMake fail with a clear error if it's not found.
find_program(VASM_EXECUTABLE vasmm68k_mot REQUIRED
    HINTS "$ENV{HOME}/vasm" # Search in ~/vasm
)

# Print the assembler we found for confirmation
message(STATUS "Using vasm assembler: ${VASM_EXECUTABLE}")

# Common include file for all targets
set(INCLUDE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/tos.i)

macro(add_asm_target target_name)
    set(SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/src/${target_name}.asm)
    string(TOUPPER ${target_name} upper_target_name)
    set(OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/${upper_target_name}.PRG)

    add_custom_command(
        OUTPUT ${OUTPUT_FILE}
        COMMAND ${VASM_EXECUTABLE}
        ARGS
            $<$<OR:$<CONFIG:Release>,$<CONFIG:MinSizeRel>>:-nosym>
            -Ftos
            -m68000
            -o
            ${OUTPUT_FILE}
            ${SOURCE_FILE}
        DEPENDS ${SOURCE_FILE} ${INCLUDE_FILE}
        COMMENT "Assembling ${SOURCE_FILE} -> ${OUTPUT_FILE}"
        VERBATIM
    )

    add_custom_target(${target_name} ALL
        DEPENDS ${OUTPUT_FILE}
    )
endmacro()

add_asm_target(whykk)
