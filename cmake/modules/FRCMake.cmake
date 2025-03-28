set(CUSTOM_WPILIB_PATH "" CACHE STRING "Location of the wpilibsuite/alwpilib GitHub repository locally")
set(FRC_SEASON "2025" CACHE STRING "Current season (year) of FRC")

set(WPILIB_SEARCH_PATH ${CMAKE_CURRENT_BINARY_DIR}/allwpilib /wpilib /allwpilib ~/wpilib ~/allwpilib ${CUSTOM_WPILIB_PATH})

function(frcmake_get_all_shared_dependency_filenames target collected_deps)
    	# Retrieve the direct link libraries of the target
    	get_target_property(direct_deps ${target} LINK_LIBRARIES)
    	if(direct_deps)
        	foreach(dep IN LISTS direct_deps)
            		if(TARGET ${dep})
                		# Get the type of the target
                		get_target_property(dep_type ${dep} TYPE)
                		if(dep_type STREQUAL "SHARED_LIBRARY")
                			# Get the output filename of the dependency
					set(dep_location $<TARGET_FILE:${dep}>)
                    			if(dep_location)
                        			list(APPEND ${collected_deps} ${dep_location})
                    			endif()
                		endif()
                		# Recursively collect dependencies of the current dependency
                		frcmake_get_all_shared_dependency_filenames(${dep} ${collected_deps})
            		endif()
        	endforeach()
    	endif()
    	# Return the collected dependencies to the parent scope
    	set(${collected_deps} ${${collected_deps}} PARENT_SCOPE)
endfunction()

function(frcmake_get_wpilib)
	find_path(WPILIB_ROOT
		NAMES wpilib-config.cmake.in
		PATHS ${WPILIB_SEARCH_PATH}
	)

	set(WPILIB_MODULES "wpilibc" "hal" "wpimath" "wpinet" "wpiunits" "wpiutil" "ntcore") 

	if(NOT WPILIB_ROOT)
		message(STATUS "AllWPILib not found, downloading from GitHub...")
		set(WPILIB_ROOT ${CMAKE_CURRENT_BINARY_DIR}/allwpilib)
		
		execute_process(COMMAND git clone --filter=blob:none --no-checkout https://github.com/wpilibsuite/allwpilib ${WPILIB_ROOT})
		execute_process(COMMAND git -C ${WPILIB_ROOT} sparse-checkout init --cone)
		execute_process(COMMAND git -C ${WPILIB_ROOT} sparse-checkout set ${WPILIB_MODULES} "cmake" "cameraserver")
		execute_process(COMMAND git -C ${WPILIB_ROOT} checkout main)
	else()
		message(STATUS "AllWPILib found at ${WPILIB_ROOT}")
	endif()

	list(APPEND CMAKE_MODULE_PATH ${WPILIB_ROOT}/cmake/modules)

	set(WPILIB_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/wpilib)

	foreach(module ${WPILIB_MODULES})
		add_subdirectory(${WPILIB_ROOT}/${module} ${CMAKE_CURRENT_BINARY_DIR}/${module})
	endforeach()
endfunction()

function(frcmake_set_toolchain_roborio)
	find_path(WPILIB_TOOLCHAIN_DIR
		NAMES toolchain-config.cmake
		PATHS ~/wpilib/${FRC_SEASON}/roborio
	)

	if(NOT WPILIB_TOOLCHAIN_DIR)
		message(WARNING "Failed to find WPILib toolchain!")
	else()
		message(STATUS "Found WPILib toolchain at ${WPILIB_TOOLCHAIN_DIR}")
	endif()

	set(CMAKE_TOOLCHAIN_FILE ${WPILIB_TOOLCHAIN_DIR}/${FRC_SEASON}/roborio/toolchain-config.cmake)
endfunction()

function(frcmake_generate_deploy_target TARGETNAME TEAM_NUMBER)
	find_path(MOD_PATH
		NAMES FRCMake.cmake frcmake-deploy.sh
		PATHS ${CMAKE_MODULE_PATH}
	)
	
	frcmake_get_all_shared_dependency_filenames(${TARGETNAME} dependencies)

	add_custom_target(deploy_${TARGETNAME}
		COMMAND ${MOD_PATH}/frcmake-deploy.sh ${TEAM_NUMBER} ${CMAKE_CURRENT_BINARY_DIR}/${TARGETNAME} ${dependencies} || true
		COMMAND_EXPAND_LISTS
		COMMENT "Deploying ${TARGETNAME} to Rio"
	)

	add_dependencies(deploy_${TARGETNAME} ${TARGETNAME})
	set_target_properties(deploy_${TARGETNAME} PROPERTIES EXCLUDE_FROM_ALL TRUE)
endfunction()
