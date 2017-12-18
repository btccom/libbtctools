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
  set(CompilerFlags CMAKE_CXX_FLAGS_RELEASE CMAKE_C_FLAGS_RELEASE
                    CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_C_FLAGS_MINSIZEREL
					CMAKE_CXX_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_RELWITHDEBINFO)
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
message("-- define NT version: -D_WIN32_WINNT=0x0501")
add_definitions(-D_WIN32_WINNT=0x0501)

###
# disable IOCP
###
add_definitions(-DBOOST_ASIO_DISABLE_IOCP)


###
# disable SAFESEH
###
message("-- disable SAFESEH")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
message("CMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}")


###################### library ######################

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

###################### demos ######################

# scanMinerDemo
add_executable(scanMinerDemo demo/scanMinerDemo.cpp)
target_link_libraries(scanMinerDemo ${TESTS_LIBRARIES})

# configMinerDemo
add_executable(configMinerDemo demo/configMinerDemo.cpp)
target_link_libraries(configMinerDemo ${TESTS_LIBRARIES})

# tcpClientDemo
add_executable(tcpClientDemo demo/tcpClientDemo.cpp)
target_link_libraries(tcpClientDemo ${TESTS_LIBRARIES})

# ipGeneratorDemo
add_executable(ipGeneratorDemo demo/ipGeneratorDemo.cpp)
target_link_libraries(ipGeneratorDemo ${TESTS_LIBRARIES})

# cryptoRSADemo
add_executable(cryptoRSADemo demo/cryptoRSADemo.cpp)
target_link_libraries(cryptoRSADemo ${TESTS_LIBRARIES})

###################### toolkits ######################

# make-rsa-keys
add_executable(make-rsa-keys toolkits/make-rsa-keys.cpp)
target_link_libraries(make-rsa-keys ${TESTS_LIBRARIES})

# rsatools
add_executable(rsatools toolkits/rsatools.cpp)
target_link_libraries(rsatools ${TESTS_LIBRARIES})
