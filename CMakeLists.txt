cmake_minimum_required (VERSION 2.6)

project (libbtctools)

###
# cmake -DCMAKE_BUILD_TYPE=Debug ..
# cmake -DCMAKE_BUILD_TYPE=Release ..
###
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release
        CACHE STRING "Set build type to Debug o Release (default Release)" FORCE)
endif()

IF(CMAKE_BUILD_TYPE MATCHES Debug)
  message("Debug build.")
ELSE()
  message("Release build.")
ENDIF()

###
# static linking VC++ runtime library
###
option(BTCTOOLS__STATIC_LINKING_VC_LIB
  "Static linking VC++ runtime library (/MT)" OFF)

if(BTCTOOLS__STATIC_LINKING_VC_LIB)
  message("-- Static linking VC++ runtime library (/MT).")
  
  # debug mode
  set(CompilerFlags CMAKE_CXX_FLAGS_DEBUG CMAKE_C_FLAGS_DEBUG)
  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MDd" "" ${CompilerFlag} "${${CompilerFlag}}")
    string(REPLACE "/MD" "" ${CompilerFlag} "${${CompilerFlag}}")
    set(${CompilerFlag} "${${CompilerFlag}} /MTd")
    message("${CompilerFlag}=${${CompilerFlag}}")
  endforeach()
  
  # release mode
  set(CompilerFlags CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE)
  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MDd" "" ${CompilerFlag} "${${CompilerFlag}}")
    string(REPLACE "/MD" "" ${CompilerFlag} "${${CompilerFlag}}")
    set(${CompilerFlag} "${${CompilerFlag}} /MT")
    message("${CompilerFlag}=${${CompilerFlag}}")
  endforeach()
else()
  message("-- Dynamic linking VC++ runtime library (/MD).")
  message("(-DBTCTOOLS__STATIC_LINKING_VC_LIB=ON switching to static linking.)")
endif()

###
# define NT version
###
message("-- define NT version")
set(CompilerFlags CMAKE_CXX_FLAGS_DEBUG CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE)
foreach(CompilerFlag ${CompilerFlags})
  set(${CompilerFlag} "${${CompilerFlag}} -D_WIN32_WINNT=0x0501")
  message("${CompilerFlag}=${${CompilerFlag}}")
endforeach()

###
# disable SAFESEH
###
message("-- disable SAFESEH")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
message("CMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}")

###
# build: libbtctools
###
file(GLOB_RECURSE LIB_SOURCES src/*.cpp)
add_library(libbtctools STATIC ${LIB_SOURCES})

###
# librarys for tests
###
set(TESTS_LIBRARIES libbtctools lua51 cryptlib ws2_32)

###
# build: tests
###
include_directories(src)

# testscan
add_executable(testscan test/testscan.cpp)
target_link_libraries(testscan ${TESTS_LIBRARIES})

# testconf
add_executable(testconf test/testconf.cpp)
target_link_libraries(testconf ${TESTS_LIBRARIES})

# testmain
add_executable(testmain test/testmain.cpp)
target_link_libraries(testmain ${TESTS_LIBRARIES})

# testutils
add_executable(testutils test/testutils.cpp)
target_link_libraries(testutils ${TESTS_LIBRARIES})

# testrsa
add_executable(testrsa test/testrsa.cpp)
target_link_libraries(testrsa ${TESTS_LIBRARIES})
