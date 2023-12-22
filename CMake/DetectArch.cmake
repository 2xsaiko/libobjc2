include(CheckCXXSourceCompiles)

set(_detect_arch_dir ${CMAKE_CURRENT_LIST_DIR})

function(detect_arch var)
    # Get Architecture without relying on CMake
    try_compile(
            COMPILE_SUCCESS
            ${CMAKE_BINARY_DIR}
            ${_detect_arch_dir}/detect_arch.c
            OUTPUT_VARIABLE COMPILE_OUTPUT
    )

    if (COMPILE_SUCCESS)
        message(FATAL_ERROR "Didn't expect this to compile.")
    endif ()

    string(REGEX MATCH "(aarch64|arm|i386|x86_64|unknown)" arch ${COMPILE_OUTPUT})
    set(${var} ${arch} PARENT_SCOPE)
endfunction()
