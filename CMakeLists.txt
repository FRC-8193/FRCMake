cmake_minimum_required(VERSION 3.15)

project(FRCMake)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

set(FRC_TEAM_NUMBER "8193" CACHE STRING "FRC Team number to use for deployment")
include(FRCMake)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Debug)
endif()

use_wpilib_toolchain()
get_and_build_wpilib()

add_executable(test_project test_project/Robot.cpp)
target_link_libraries(test_project wpilibc)
generate_deploy_target(test_project ${FRC_TEAM_NUMBER})
