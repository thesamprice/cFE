# This example toolchain file describes the cross compiler to use for
# the target architecture indicated in the configuration file.

# Basic cross system configuration
SET(CMAKE_SYSTEM_NAME           Qt)
SET(CMAKE_SYSTEM_VERSION        1)
SET(CMAKE_SYSTEM_PROCESSOR      i686)

# Specify the cross compiler executables
# Typically these would be installed in a home directory or somewhere
# in /opt.  However in this example the system compiler is used.
# SET(CMAKE_C_COMPILER            "/usr/bin/gcc")
# SET(CMAKE_CXX_COMPILER          "/usr/bin/g++")

# Configure the find commands
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM   NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY   NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE   NEVER)
SET(C_FLAGS "-Wno-nonportable-include-path")
# These variable settings are specific to cFE/OSAL and determines which 
# abstraction layers are built when using this toolchain
SET(CFE_SYSTEM_PSPNAME      "pc-qt")
set(CFE_SYSTEM_PSPNAME "pc-qt")
#SET(OSAL_SYSTEM_BSPNAME     "pc-qt")
SET(OSAL_SYSTEM_OSTYPE      "qt")
set(OSAL_SYSTEM_BSPTYPE     "generic-qt")

