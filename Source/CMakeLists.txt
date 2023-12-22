add_library(objc)

target_sources(objc
        PRIVATE
        NSBlocks.m
        Protocol2.m
        alias_table.c
        arc.mm
        associate.m
        block_to_imp.c
        blocks_runtime.m
        caps.c
        category_loader.c
        class_table.c
        dtable.c
        encoding2.c
        gc_none.c
        hooks.c
        ivar.c
        loader.c
        mutation.m
        properties.m
        protocol.c
        runtime.c
        sarray2.c
        selector_table.cc
        sendmsg2.c
        PUBLIC FILE_SET HEADERS
        BASE_DIRS ../Headers)

target_link_libraries(objc PRIVATE Threads::Threads)
target_compile_definitions(objc PRIVATE GNUSTEP __OBJC_RUNTIME_INTERNAL__=1)
target_include_directories(objc
        PRIVATE
        ../third_party/robin-map/include)

# For release builds, we disable spamming the terminal with warnings about
# selector type mismatches
target_compile_definitions(objc PRIVATE
        $<$<CONFIG:Release>:NO_SELECTOR_MISMATCH_WARNINGS>
        $<$<BOOL:${TYPE_DEPENDENT_DISPATCH}>:TYPE_DEPENDENT_DISPATCH>
        $<$<BOOL:${ENABLE_TRACING}>:WITH_TRACING=1>
        $<$<BOOL:${DEBUG_ARC_COMPAT}>:DEBUG_ARC_COMPAT>)

target_compile_options(objc PRIVATE
        "$<$<OR:$<COMPILE_LANGUAGE:OBJC>,$<COMPILE_LANGUAGE:OBJCXX>>:-Wno-deprecated-objc-isa-usage;-Wno-objc-root-class;-fobjc-runtime=gnustep-2.0>$<$<COMPILE_LANGUAGE:C>:-Xclang;-fexceptions>"
        $<$<STREQUAL:${CMAKE_SYSTEM_PROCESSOR},i686>:-march=i586>)

target_compile_definitions(objc PRIVATE
        $<IF:$<BOOL:${CXA_ALLOCATE_EXCEPTION_NOEXCEPT_COMPILES}>,CXA_ALLOCATE_EXCEPTION_SPECIFIER=noexcept,CXA_ALLOCATE_EXCEPTION_SPECIFIER>)

set_target_properties(objc PROPERTIES
        LINKER_LANGUAGE C
        SOVERSION ${libobjc_VERSION}
        LINK_FLAGS "${objc_LINK_FLAGS}")

if (OLDABI_COMPAT)
    target_sources(objc
            PRIVATE
            legacy.c
            abi_version.c
            statics_loader.c)
    target_compile_definitions(objc PRIVATE OLDABI_COMPAT=1)
endif ()

if (LEGACY_COMPAT)
    target_sources(objc
            PRIVATE
            legacy_malloc.c)
    target_compile_definitions(objc PRIVATE GNU_LEGACY)
endif ()

if (NOT WIN32)
    target_sources(objc
            PRIVATE
            eh_personality.c)
else ()
    # Windows does not use DWARF EH
    target_sources(objc
            PRIVATE
            eh_win32_msvc.cc)
endif ()

if (NOT MSVC)
    target_sources(objc PRIVATE
            block_trampolines.S
            objc_msgSend.S)
else ()
    # CMake is completely broken when you try to build assembly files on Windows.
    message(STATUS "Using custom build commands to work around CMake bugs")

    if (CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ASM_TARGET -m64)
    else ()
        set(ASM_TARGET -m32)
    endif ()

    set(ASSEMBLER ${CMAKE_ASM_COMPILER} CACHE STRING "Assembler to use with Visual Studio (must be gcc / clang!)")
    message(STATUS "ASM compiler: ${ASSEMBLER}")

    add_custom_command(
            OUTPUT block_trampolines.obj
            COMMAND echo ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/block_trampolines.S" -o "${CMAKE_BINARY_DIR}/block_trampolines.obj"
            COMMAND ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/block_trampolines.S" -o "${CMAKE_BINARY_DIR}/block_trampolines.obj"
            MAIN_DEPENDENCY block_trampolines.S
    )
    add_custom_command(
            OUTPUT objc_msgSend.obj
            COMMAND echo ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/objc_msgSend.S" -o "${CMAKE_BINARY_DIR}/objc_msgSend.obj"
            COMMAND ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/objc_msgSend.S" -o "${CMAKE_BINARY_DIR}/objc_msgSend.obj"
            MAIN_DEPENDENCY objc_msgSend.S
            DEPENDS objc_msgSend.aarch64.S objc_msgSend.arm.S objc_msgSend.mips.S objc_msgSend.x86-32.S objc_msgSend.x86-64.S
    )
    set(libobjc_ASM_OBJS block_trampolines.obj objc_msgSend.obj)

    target_sources(objc PRIVATE
            block_trampolines.obj
            objc_msgSend.obj)

    set_source_files_properties(
            block_trampolines.obj
            objc_msgSend.obj
            PROPERTIES
            EXTERNAL_OBJECT YES)
endif ()

if (NOT WIN32)
    separate_arguments(EH_PERSONALITY_FLAGS NATIVE_COMMAND ${CMAKE_CXX_FLAGS})

    if (CMAKE_CXX_COMPILER_TARGET)
        list(APPEND EH_PERSONALITY_FLAGS "${CMAKE_CXX_COMPILE_OPTIONS_TARGET}${CMAKE_CXX_COMPILER_TARGET}")
    endif ()

    add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/eh_trampoline.S
            COMMAND ${CMAKE_CXX_COMPILER}
            ARGS
            ${EH_PERSONALITY_FLAGS} -S -fPIC -fexceptions -fno-inline
            -o -
            "${CMAKE_CURRENT_SOURCE_DIR}/eh_trampoline.cc"
            | sed "s/__gxx_personality_v0/test_eh_personality/g"
            > "${CMAKE_CURRENT_BINARY_DIR}/eh_trampoline.S"
            MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/eh_trampoline.cc)

    target_sources(objc PRIVATE
            ${CMAKE_CURRENT_BINARY_DIR}/eh_trampoline.S
            objcxx_eh.cc)
else ()
    message(STATUS "Using MSVC-compatible exception model")
endif ()

# Link against ntdll.dll for RtlRaiseException
if (WIN32)
    target_link_libraries(objc PRIVATE ntdll.dll)
endif ()

# Explicitly link libm, as an implicit dependency of the C++ runtime
if (M_LIBRARY)
    target_link_libraries(objc PRIVATE ${M_LIBRARY})
endif ()

# Make weak symbols work on OS X
if (APPLE)
    set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS
            "${CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS} -undefined dynamic_lookup")

    target_link_options(objc PRIVATE
            $<$<OR:$<COMPILE_LANGUAGE:C>,$<COMPILE_LANGUAGE:CXX>>:LINKER:-undefined,dynamic-lookup>)
endif ()