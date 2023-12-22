cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0118 NEW)

set(CMAKE_CXX_STANDARD 17)

project(libobjc VERSION 4.6 LANGUAGES C ASM CXX)

if (NOT "${CMAKE_C_COMPILER_ID}" MATCHES Clang*)
	message(WARNING "WARNING: It is strongly recommended that you compile with clang")
elseif (WIN32 AND "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
	message(WARNING "WARNING: It is strongly recommended that you compile with clang (clang-cl is not supported)")
endif()

# fix up CMake Objective-C compiler detection on Windows before enabling languages below
if (WIN32)
	foreach(lang IN ITEMS C CXX)
		set(CMAKE_OBJ${lang}_COMPILER_FORCED ON)
		foreach(runtimeLibrary IN ITEMS MultiThreaded MultiThreadedDLL MultiThreadedDebug MultiThreadedDebugDLL)
			set(CMAKE_OBJ${lang}_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_${runtimeLibrary} ${CMAKE_${lang}_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_${runtimeLibrary}})
		endforeach()
	endforeach()
endif()

enable_language(OBJC OBJCXX)

list(APPEND CMAKE_MODULE_PATH
		${CMAKE_SOURCE_DIR}/CMake)

include(CMakePackageConfigHelpers)
include(DetectArch)
include(FindThreads)
include(GNUInstallDirs)

if (NOT EXISTS "${CMAKE_SOURCE_DIR}/third_party/robin-map/include/tsl/robin_map.h")
	message(FATAL_ERROR "Git submodules not present, please run:\n\n"
			" $ git submodule init && git submodule update\n\n"
			"If you did not checkout via git, you will need to"
			"fetch the submodule's contents from"
			"https://github.com/Tessil/robin-map/")
endif ()

if (MSVC)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /EHas")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /EHas")
	set(CMAKE_C_FLAGS_DEBUG "/Z7 ${CMAKE_C_FLAGS_DEBUG}")
	set(CMAKE_SHARED_LINKER_FLAGS "/DEBUG /INCREMENTAL:NO ${CMAKE_SHARED_LINKER_FLAGS}")
	set(CMAKE_EXE_LINKER_FLAGS "/DEBUG /INCREMENTAL:NO ${CMAKE_EXE_LINKER_FLAGS}")
	set(objc_LINK_FLAGS "/DEBUG /INCREMENTAL:NO ${objc_LINK_FLAGS}")
endif()

if (WIN32)
	set(OLD_ABI_COMPAT_DEFAULT false)
else()
	set(OLD_ABI_COMPAT_DEFAULT true)
endif()

option(TYPE_DEPENDENT_DISPATCH "Enable type-dependent dispatch" ON)
option(ENABLE_TRACING
		"Enable tracing support (slower, not recommended for deployment)" OFF)
option(OLDABI_COMPAT
		"Enable compatibility with GCC and old GNUstep ABIs"
		${OLD_ABI_COMPAT_DEFAULT})
option(LEGACY_COMPAT "Enable legacy compatibility features" OFF)
option(DEBUG_ARC_COMPAT
		"Log warnings for classes that don't hit ARC fast paths" OFF)
option(ENABLE_OBJCXX "Enable support for Objective-C++" ON)
option(TESTS "Enable building the tests")

detect_arch(ARCHITECTURE)
set(ARCHITECTURE ${ARCHITECTURE} CACHE STRING "Architecture Type")
message(STATUS "Architecture: ${ARCHITECTURE}")

# Build configuration

find_library(M_LIBRARY m)
find_program(GNUSTEP_CONFIG gnustep-config)

check_cxx_source_compiles("
	#include <stdlib.h>
	extern \"C\" {
	__attribute__((weak))
	void *__cxa_allocate_exception(size_t thrown_size) noexcept;
	}
	#include <exception>
	int main() { return 0; }" CXA_ALLOCATE_EXCEPTION_NOEXCEPT_COMPILES)

add_subdirectory(Source)
add_subdirectory(Headers)

#
# Installation
#

if (GNUSTEP_CONFIG)
	# If we have GNUstep environment variables, then default to installing in the
	# GNUstep local environment.
	execute_process(
			COMMAND ${GNUSTEP_CONFIG} --installation-domain-for=libobjc2
			OUTPUT_VARIABLE DEFAULT_INSTALL_TYPE)
else()
	set(DEFAULT_INSTALL_TYPE NONE)
endif ()

set(GNUSTEP_INSTALL_TYPE ${DEFAULT_INSTALL_TYPE} CACHE STRING
	"GNUstep installation type.  Options are NONE, SYSTEM, NETWORK or LOCAL.")
if (NOT ${GNUSTEP_INSTALL_TYPE} STREQUAL "NONE")
	set(CMAKE_INSTALL_PREFIX "/")
	execute_process(
			COMMAND ${GNUSTEP_CONFIG} "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES"
			OUTPUT_VARIABLE CMAKE_INSTALL_LIBDIR
			COMMAND_ERROR_IS_FATAL ANY)
	execute_process(
			COMMAND ${GNUSTEP_CONFIG} "--variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_HEADERS"
			OUTPUT_VARIABLE CMAKE_INSTALL_INCLUDEDIR
			COMMAND_ERROR_IS_FATAL ANY)
	GNUInstallDirs_get_absolute_install_dir(CMAKE_INSTALL_FULL_LIBDIR CMAKE_INSTALL_LIBDIR LIBDIR)
	GNUInstallDirs_get_absolute_install_dir(CMAKE_INSTALL_FULL_INCLUDEDIR CMAKE_INSTALL_INCLUDEDIR INCLUDEDIR)
endif ()
message(STATUS "GNUstep install type set to ${GNUSTEP_INSTALL_TYPE}")

install(TARGETS objc
	RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	FILE_SET HEADERS DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

set(CPACK_GENERATOR TGZ CACHE STRING
	"Installer types to generate.  Sensible options include TGZ, RPM and DEB")

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "GNUstep Objective-C Runtime")
set(CPACK_PACKAGE_VENDOR "The GNUstep Project")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/COPYING")
set(CPACK_PACKAGE_CONTACT "GNUstep Developer <gnustep-dev@gnu.org>")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "CMake ${CMake_VERSION_MAJOR}.${CMake_VERSION_MINOR}")
if (UNIX)
	set(CPACK_STRIP_FILES true CACHE BOOL "Strip libraries when packaging")
endif ()
include (CPack)

# pkg-config descriptor

set(PC_LIBS_PRIVATE ${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES})
if (M_LIBRARY)
	list(APPEND PC_LIBS_PRIVATE ${M_LIBRARY})
endif ()
list(REMOVE_DUPLICATES PC_LIBS_PRIVATE)
string(REPLACE  ";" " -l" PC_LIBS_PRIVATE "${PC_LIBS_PRIVATE}")
set(PC_LIBS_PRIVATE "-l${PC_LIBS_PRIVATE}")

configure_file("libobjc.pc.in" "libobjc.pc" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libobjc.pc"
	DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig"
)

# Install CMake package

configure_package_config_file(
        objc-config.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/objc-config.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/nucom)

write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/objc-config-version.cmake
        COMPATIBILITY SameMinorVersion)

install(
		FILES
		${CMAKE_CURRENT_BINARY_DIR}/objc-config.cmake
		${CMAKE_CURRENT_BINARY_DIR}/objc-config-version.cmake
		DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/objc)

# uninstall target
configure_file(
	"${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
	"${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
	IMMEDIATE @ONLY)

add_custom_target(uninstall
	COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

if (TESTS)
	enable_testing()
	add_subdirectory(Test)
endif (TESTS)