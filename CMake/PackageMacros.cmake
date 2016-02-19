#==========================================================================
#
# This file provides macros for creating packages with generic modules.
#
#==========================================================================

# CMake compatibility policies
if(POLICY CMP0020)
  # CMake 2.8.11 allows automatic linking to qtmain on Windows
  cmake_policy(SET CMP0020 NEW)
endif()
if(POLICY CMP0022)
  # CMake 2.8.12 changed LINK_INTERFACE_LIBRARIES to INTERFACE_LINK_LIBRARIES
  cmake_policy(SET CMP0020 OLD)
endif()

# Use the QT_VERSION specified by the configure script
if(QT_VERSION)
  set(DESIRED_QT_VERSION ${QT_VERSION} CACHE BOOL "Desired Qt Version" FORCE)
endif()

# Save the current directory for later use
set(PACKAGE_MACROS_CMAKE_DIR ${CMAKE_CURRENT_LIST_DIR})

#--------------------------------------------------------------------------
# package(<name> VERSION <version>)
#
# This macro creates many important cmake variables.
#
# -- miscellaneous variables --
# PACKAGE_NAME    the package name
# PACKAGE_PREFIX  the package prefix, uppercase of PACKAGE_NAME
#
# -- version variables --
# <prefix>_VERSION        string
# <prefix>_MAJOR_VERSION  integer
# <prefix>_MINOR_VERSION  integer
# <prefix>_BUILD_VERSION  integer
# <prefix>_TWEAK_VERSION  integer, letter, or string
# <prefix>_SHORT_VERSION  "major.minor"
#
# -- output directories for the build (if not already set) --
# CMAKE_RUNTIME_OUTPUT_DIRECTORY "bin" dir for executables
# CMAKE_LIBRARY_OUTPUT_DIRECTORY "lib" dir for .so, .dylib, or .dll files
# CMAKE_ARCHIVE_OUTPUT_DIRECTORY "lib" dir dir for .a or .lib files
#
# -- other directories for the build --
# <prefix>_SOURCE_DIR   the base directory for the project
# <prefix>_BINARY_DIR   the Build directory for the project
# <prefix>_CMAKE_DIR    the CMake directory for cmake macros
# <prefix>_MODULES_DIR  the Modules dir for cmake module scripts
#
# -- output directories for "make install" --
# <prefix>_RUNTIME_INSTALL_DEST  "bin" dir, for executables
# <prefix>_LIBRARY_INSTALL_DEST  "lib" dir, for .so, .dylib, .dll, etc.
# <prefix>_ARCHIVE_INSTALL_DEST  "lib" dir, for .a, .lib, etc.
# <prefix>_INCLUDE_INSTALL_DEST  "include" dir, for headers
# <prefix>_PACKAGE_INSTALL_DEST  "cmake" dir, for exported .cmake files
# <prefix>_STORAGE_INSTALL_DEST  "share" dir, for resources etc.
#
# Configurable cache variables that modify this macro:
#
# -- path prefixes for build and install --
# <prefix>_OUTPUT_DIR  the directory for the bin and lib build subdirs
# CMAKE_INSTALL_PREFIX the install directory, default "/usr/local"
#
# -- generic configuration information --
# BUILD_SHARED_LIBS  whether to build shared libs
# BUILD_TESTING      whether to build tests
# BUILD_EXAMPLES     whether to build examples
#
# Other input variables that modify this macro:
#
# -- these allow customization of the installed directory structure --
# <prefix>_BIN_DIR  defaults to "/bin", used during install
# <prefix>_LIB_DIR  defaults to "/lib", used during install
# <prefix>_ARC_DIR  defaults to "/lib", used during install
# <prefix>_INC_DIR  defaults to "/include", used during install
# <prefix>_PKG_DIR  defaults to "/lib/<name>-x.y/cmake"
# <prefix>_STO_DIR  defaults to "/share/<name>-x.y"

macro(package)
  set(_part "_name")
  foreach(_arg ${ARGN})
    if(_arg MATCHES "^(VERSION)$")
      set(_part ${_arg})
    elseif("${_part}" STREQUAL "VERSION")
      set(_version ${_arg})
      unset(_part)
    elseif("${_part}" STREQUAL "_name")
      set(_name ${_arg})
      unset(_part)
    endif()
  endforeach()

  # set the project name and prefix
  set(PACKAGE_NAME ${CMAKE_PROJECT_NAME})
  if(_name)
    set(PACKAGE_NAME ${_name})
  endif()
  package_uppercase(${PACKAGE_NAME} PACKAGE_PREFIX)

  # set the version variables
  package_version(${_version})

  # declare options that are common to all projects
  package_options()

  # set up our directory structure for output libraries and binaries
  package_paths()
endmacro()

#--------------------------------------------------------------------------
# package_depends(<package> [<version> [EXACT]] [REQUIRED] ...)
#
# Find the packages used by this project.  If a package is optional,
# then a configuration variable will be created to allow its use to
# be turned on or off.
#
# -- input variables --
# PACKAGE_PREFIX  the project prefix
#
# -- output variables --
# <prefix>_REQUIRED_PACKAGES  list of all required packages
# <prefix>_REQUESTED_PACKAGES list of all requested packages

macro(package_depends)
  set(_prefix ${PACKAGE_PREFIX})
  # for building up the find_package() argument list
  set(_find_package_args)

  # loop through the arguments, call find_package() as needed
  foreach(_arg ${ARGN})
    if(_arg MATCHES "^[0-9].*$")
      list(APPEND _find_package_args ${_arg})
    elseif(_arg MATCHES "^(EXACT|REQUIRED|MODULE|NO_PACKAGE_SCOPE)$")
      list(APPEND _find_package_args ${_arg})
    else()
      if(_find_package_args)
        package_find_package(${_find_package_args})
      endif()
      set(_find_package_args ${_arg})
    endif()
  endforeach()

  # call find_package for the final listed package
  if(_find_package_args)
    package_find_package(${_find_package_args})
  endif()

  while(DEPENDS_REQUIRED_PACKAGES)
    list(GET DEPENDS_REQUIRED_PACKAGES 0 _head)
    list(REMOVE_AT DEPENDS_REQUIRED_PACKAGES 0)
    # this TOUPPER is needed for QT_FOUND in old versions of cmake
    string(TOUPPER "${_head}" _uhead)
    if(NOT ${_head}_FOUND AND NOT ${_uhead}_FOUND)
      message(WARNING
        "Missing package ${_head} needed by ${${_head}_REQUIRED_BY}")
      # instead, package dependencies could be loaded automatically
      # find_package(${_arg} ${_version} REQUIRED ${_extra})
    endif()
  endwhile()
endmacro()

#--------------------------------------------------------------------------
# package_modules([<subdirectory>] ...)
#
# Declare all modules by the subdirectories they reside in.
#
# -- input variables --
# PACKAGE_PREFIX      the project prefix
#
# -- output variables --
# <prefix>_MODULES_ALL      all modules, whether or not they are enabled
# <prefix>_MODULES_ENABLED  just the enabled modules

# note about variable names:
# The reuse of variables for different purposes should be avoided,
# so _DEPENDS here should be renamed to something like _INTERNAL_DEPENDS,
# because it will be stripped down to depends that can be resolved within
# the project itself.

# For Testing, note that VTK module cmake files do not explictly have
# add_directory for their Testing subdirs (because testing might have
# additional dependencies).  Instead, Testing subdirs are searched for
# and added automatically (can one testing dir depend on another?
# can their dependencies be resolved at the same time as the modules?)

macro(_module_scan _name)
  set(_module ${_name})
  list(APPEND ${_prefix}_MODULES_ALL ${_name})
  list(APPEND ${_prefix}_MODULES_ENABLED ${_name})
  set(${_name}_DEPENDS)
  set(${_name}_TEST_DEPENDS)
  foreach(_arg ${ARGN})
    if(${_arg} MATCHES "^(|TEST_)DEPENDS$")
      set(_part ${_arg})
    elseif(_part)
      list(APPEND ${_name}_${_part} "${_arg}")
    endif()
  endforeach()
endmacro()

macro(package_modules)
  # we need to use some of the module macros
  include("${PACKAGE_MACROS_CMAKE_DIR}/ModuleMacros.cmake")
  # capture all modules and their dependencies
  set(_prefix ${PACKAGE_PREFIX})
  set(${_prefix}_MODULES_ALL)
  set(${_prefix}_MODULES_ENABLED)
  set(_count 0)
  foreach(_arg ${ARGN})
    math(EXPR _count "${_count}+1")
    # read the module CMakeLists as a text file so that we can make a
    # list of module dependencies before cmake adds the directory
    # (directories cannot be added until we sort out the dependencies)
    file(READ "${_arg}/CMakeLists.txt" _contents)
    # strip all comments
    string(REGEX REPLACE "[ \t]*#[^\n]*\n" "\n" _contents "${_contents}")
    # get everything up to and including the module call
    string(REGEX MATCH "^.*(module|MODULE)\\([^)]*\\)"
           _head "${_contents}")
    # replace module() with _module_scan()
    string(REGEX REPLACE "(module|MODULE)"
           "_module_scan" _head "${_head}")
    # strip cmake_minimum_required, cmake_policy, etc.
    string(REGEX REPLACE "(^|[ \t\n])(cmake|CMAKE)_[a-zA-Z0-9_]*\\([^)]*\\)" ""
           _head "${_head}")
    # strip any project() call
    string(REGEX REPLACE "(^|[ \t\n])(project|PROJECT)\\([^)]*\\)" ""
           _head "${_head}")
    # write out to a file, and then read as a .cmake file
    file(WRITE "${PROJECT_BINARY_DIR}/CMakeFiles/depscan${_count}.cmake"
         "${_head}\n")
    include("${PROJECT_BINARY_DIR}/CMakeFiles/depscan${_count}.cmake")
    set(${_module}_srcdir "${_arg}")
    if(BUILD_TESTING)
      # check for a Testing subdirectory within the module
      if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_arg}/Testing/CMakeLists.txt")
        set(_testmod ${_module}Testing)
        list(APPEND ${_prefix}_MODULES_ENABLED ${_testmod})
        set(${_testmod}_DEPENDS ${${_module}_TEST_DEPENDS})
        list(APPEND ${_testmod}_DEPENDS ${_module})
        set(${_testmod}_srcdir "${_arg}/Testing")
      endif()
    endif()
  endforeach()
  # look only at dependencies on other modules
  foreach(_module ${${_prefix}_MODULES_ENABLED})
    set(${_module}_DEPENDS_INTERNAL)
    foreach(_dep ${${_module}_DEPENDS})
      list(FIND ${_prefix}_MODULES_ENABLED ${_dep} _index)
      if(_index GREATER -1)
        list(APPEND ${_module}_DEPENDS_INTERNAL ${_dep})
      endif()
    endforeach()
  endforeach()
  # sort modules according to interdependencies
  include("${PACKAGE_MACROS_CMAKE_DIR}/TopologicalSort.cmake")
  topological_sort(${_prefix}_MODULES_ENABLED "" _DEPENDS_INTERNAL)
  message(STATUS "Sorted: ${${_prefix}_MODULES_ENABLED}")

  # modules have been sorted, so now we can load them
  foreach(CURRENT_MODULE ${${_prefix}_MODULES_ENABLED})
    add_subdirectory("${${CURRENT_MODULE}_srcdir}")
  endforeach()

  # the very last thing is to create a makefile
  if(NOT "${PACKAGE_OUTPUT_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    configure_file("${PACKAGE_MACROS_CMAKE_DIR}/Makefile.in"
      "${PACKAGE_OUTPUT_DIR}/Makefile" COPYONLY)
  endif()
endmacro()

#--------------------------------------------------------------------------
# package_config_header(code_list)
#
# This macro creates the Config.h for the project.  Each arg
# given to this macro will be added as a line in header file.

macro(package_config_header)
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})

  # initialize the config vars
  set(_config)
  set(_config_private)

  # add BUILD_SHARED_LIBS and BUILD_TESTING
  set(_vars BUILD_SHARED_LIBS BUILD_TESTING)
  foreach(_var ${_vars})
    set(_newvar "${_prefix}_${_var}")
    if(${${_var}})
      set(_config_line "#define ${_newvar}")
    else()
      set(_config_line "//#undef ${_newvar}")
    endif()
    set(_config "${_config}\n${_config_line}")
  endforeach()

  # add user-config lines
  foreach(_config_line ${ARGN})
    set(_config "${_config}\n${_config_line}")
  endforeach()

  # generate the config header
  set(_private)
  configure_file("${PACKAGE_MACROS_CMAKE_DIR}/PackageConfig.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/${_package}Config.h" @ONLY)
  list(APPEND ${_prefix}_CONFIG_HEADERS
    "${CMAKE_CURRENT_BINARY_DIR}/${_package}Config.h")

  # install the config header
  install(FILES ${${_prefix}_CONFIG_HEADERS}
    DESTINATION ${${_prefix}_INCLUDE_INSTALL_DEST} COMPONENT Development)

endmacro()

#--------------------------------------------------------------------------
# package_export(code_list)
#
# This macro creates the Config.cmake file for the project.  Each arg
# given to this macro will be added as a line in the Config.cmake file.

macro(package_export)
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})

  # Add all targets to the build-tree export set
  get_property(_targets GLOBAL PROPERTY ${_prefix}_TARGETS)
  export(TARGETS ${_targets}
    FILE "${PACKAGE_OUTPUT_DIR}/${_package}Targets.cmake")
  list(GET _targets 0 _first_target)

  # Export the package for use from the build-tree
  # (this registers the build-tree with a global CMake-registry)
  export(PACKAGE ${_package})

  # Set extra config information
  set(_config)
  foreach(_config_line ${ARGN})
    set(_config "${_config}\n${_config_line}")
  endforeach()
  set(_config_line "set(${_prefix}_PACKAGES")
  foreach(_pkg ${${_prefix}_REQUESTED_PACKAGES})
    set(_config_line "${_config_line} ${_pkg}")
  endforeach()
  set(_config_line "${_config_line})")
  set(_config "${_config}\n${_config_line}")
  foreach(_pkg ${${_prefix}_REQUESTED_PACKAGES})
    set(_config_line "set(${_prefix}_${_pkg}_DIR \"${${_pkg}_DIR}\")")
    set(_config "${_config}\n${_config_line}")
  endforeach()

  # Create the PackageConfig.cmake and PackageConfigVersion.cmake files
  set(_required_c_flags "${${_prefix}_REQUIRED_C_FLAGS}")
  set(_required_cxx_flags "${${_prefix}_REQUIRED_CXX_FLAGS}")
  set(_modules_enabled "")
  foreach(_mod ${${_prefix}_MODULES_ENABLED})
    # If DECLARED != 1, the module is for internal use (e.g. testing)
    if(${_mod}_DECLARED EQUAL 1)
      set(_modules_enabled "${_modules_enabled} ${_mod}")
    endif()
  endforeach()
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/PackageConfigVersion.cmake.in
    "${PACKAGE_OUTPUT_DIR}/${_package}ConfigVersion.cmake" @ONLY)
  set(_core_dir "")
  if(EXISTS ${PACKAGE_MACROS_CMAKE_DIR}/PackageMacros.cmake)
    set(_core_dir "\nset(PACKAGE_MACROS_CMAKE_DIR \"${${_prefix}_CMAKE_DIR}\")")
  endif()
  # ... for the build tree
  set(_modules_dir ${${_prefix}_MODULES_DIR})
  set(_cmake_dir ${${_prefix}_CMAKE_DIR})
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/PackageConfig.cmake.in
    "${PACKAGE_OUTPUT_DIR}/${_package}Config.cmake" @ONLY)
  # ... for the install tree
  set(_modules_dir "\${${_prefix}_CMAKE_DIR}")
  set(_cmake_dir "\${PACKAGE_MACROS_CMAKE_DIR}")
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/PackageConfig.cmake.in
    "${${_prefix}_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${_package}Config.cmake"
    @ONLY)

  # Install the PackageConfig.cmake and PackageConfigVersion.cmake
  install(FILES
    "${${_prefix}_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${_package}Config.cmake"
    "${PACKAGE_OUTPUT_DIR}/${_package}ConfigVersion.cmake"
    DESTINATION "${${_prefix}_PACKAGE_INSTALL_DEST}" COMPONENT Development)

  # Install the Use file in the build and install directories
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/UsePackage.cmake.in
    ${PACKAGE_OUTPUT_DIR}/Use${_package}.cmake @ONLY)
  install(FILES
    "${PACKAGE_OUTPUT_DIR}/Use${_package}.cmake"
    DESTINATION "${${_prefix}_PACKAGE_INSTALL_DEST}" COMPONENT Development)

  # Install the export set for use with the install-tree
  install(EXPORT ${_package}Targets
    DESTINATION "${${_prefix}_PACKAGE_INSTALL_DEST}" COMPONENT Development)
endmacro()

#--------------------------------------------------------------------------
# package_uppercase(<name> <output_variable>)
#
# Generate an uppercase name from a CamelCase name, inserting
# underscores before capitals to increase legibility.  This is useful
# when the name is to be used as part of a C macro.

macro(package_uppercase _input _output)
  string(REGEX REPLACE "[+-]" "_" _tmp "${_input}")
  string(REGEX REPLACE "([a-z])([A-Z])" "\\1_\\2" _tmp "${_tmp}")
  string(TOUPPER "${_tmp}" ${_output})
endmacro()

#--------------------------------------------------------------------------
# package_lowercase(<input_name> <output_variable>)
#
# Generate a lowercase name from a CamelCase name, inserting
# underscores before capitals to increase legibility.  This is useful
# when the name is to be used as part of a C identifier.

macro(package_lowercase _input _output)
  string(REGEX REPLACE "[+-]" "_" _tmp "${_input}")
  string(REGEX REPLACE "([a-z])([A-Z])" "\\1_\\2" _tmp "${_tmp}")
  string(TOLOWER "${_tmp}" ${_output})
endmacro()

#--------------------------------------------------------------------------
# The rest of the file is private macros
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
macro(package_version _version)
  # get uppercase project name for use as variable prefix
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})

  set(PACKAGE_VERSION "${_version}")

  # use a regex pattern to decompose the version number string
  set(_regex "([0-9]*)\\.([0-9]*)\\.([0-9]*)[_.]*(.*)")
  string(REGEX REPLACE "${_regex}" "\\1" PROJECT_MAJOR_VERSION "${_version}")
  string(REGEX REPLACE "${_regex}" "\\2" PROJECT_MINOR_VERSION "${_version}")
  string(REGEX REPLACE "${_regex}" "\\3" PROJECT_BUILD_VERSION "${_version}")
  string(REGEX REPLACE "${_regex}" "\\4" PROJECT_TWEAK_VERSION "${_version}")

  set(PROJECT_SHORT_VERSION
    "${PROJECT_MAJOR_VERSION}.${PROJECT_MINOR_VERSION}")

  set(${_prefix}_VERSION ${PROJECT_VERSION})
  set(${_prefix}_MAJOR_VERSION ${PROJECT_MAJOR_VERSION})
  set(${_prefix}_MINOR_VERSION ${PROJECT_MINOR_VERSION})
  set(${_prefix}_BUILD_VERSION ${PROJECT_BUILD_VERSION})
  set(${_prefix}_TWEAK_VERSION ${PROJECT_TWEAK_VERSION})
  set(${_prefix}_SHORT_VERSION ${PROJECT_SHORT_VERSION})

endmacro()

#--------------------------------------------------------------------------
macro(package_options)
  set(_package ${CMAKE_PROJECT_NAME})
  if(BUILD_SHARED_LIBS_DEFAULT)
    option(BUILD_SHARED_LIBS "Build shared libraries." ON)
  else()
    option(BUILD_SHARED_LIBS "Build shared libraries." OFF)
  endif()
  option(BUILD_TESTING "Build the tests" ON)
  option(BUILD_EXAMPLES "Build the examples" ON)

  if(BUILD_TESTING)
    enable_testing()
  endif()
endmacro()

#--------------------------------------------------------------------------
macro(package_paths)
  # Set up our directory structure for output libraries and binaries
  # (Note: these are the build locations, not the install locations)
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})
  string(TOLOWER ${_package} _lname)
  set(${_prefix}_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
  set(${_prefix}_BINARY_DIR "${CMAKE_BINARY_DIR}")
  set(${_prefix}_CMAKE_DIR "${CMAKE_SOURCE_DIR}/CMake")
  set(${_prefix}_MODULES_DIR "${CMAKE_BINARY_DIR}/Modules")
  set(PACKAGE_OUTPUT_DIR "${CMAKE_BINARY_DIR}" CACHE PATH
      "Where to put the bin and lib directories")
  mark_as_advanced(PACKAGE_OUTPUT_DIR)
  if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PACKAGE_OUTPUT_DIR}/bin")
  endif()
  if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    if(UNIX)
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PACKAGE_OUTPUT_DIR}/lib")
    else()
      set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PACKAGE_OUTPUT_DIR}/bin")
    endif()
  endif()
  if(NOT CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PACKAGE_OUTPUT_DIR}/lib")
  endif()

  # Set up our target directory structure for "make install"
  if(NOT ${_prefix}_BIN_DIR)
    set(${_prefix}_BIN_DIR "/bin") # for executables and ".dll" libraries
  endif()
  if(NOT ${_prefix}_LIB_DIR)
    set(${_prefix}_LIB_DIR "/lib") # for unix/linux/osx shared libraries
  endif()
  if(NOT ${_prefix}_ARC_DIR)
    set(${_prefix}_ARC_DIR "${${_prefix}_LIB_DIR}") # for static or ".lib" libraries
  endif()
  if(NOT ${_prefix}_INC_DIR)
    set(${_prefix}_INC_DIR "/include") # for header files
  endif()
  if(NOT ${_prefix}_STO_DIR)
    set(${_prefix}_STO_DIR "/share/${_lname}-${${_prefix}_SHORT_VERSION}")
  endif()
  if(NOT ${_prefix}_PKG_DIR)
    set(${_prefix}_PKG_DIR "${${_prefix}_LIB_DIR}/${_lname}-${${_prefix}_SHORT_VERSION}/cmake")
  endif()

  # Set the full paths to the install tree
  set(${_prefix}_RUNTIME_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_BIN_DIR})
  set(${_prefix}_LIBRARY_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_LIB_DIR})
  set(${_prefix}_ARCHIVE_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_ARC_DIR})
  set(${_prefix}_INCLUDE_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_INC_DIR})
  set(${_prefix}_STORAGE_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_STO_DIR})
  set(${_prefix}_PACKAGE_INSTALL_DEST
    ${CMAKE_INSTALL_PREFIX}${${_prefix}_PKG_DIR})

  # Add our custom cmake scripts to the cmake path
  set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/CMake" ${CMAKE_MODULE_PATH})
endmacro()

#--------------------------------------------------------------------------
macro(package_find_package _name)
  package_uppercase(${_name} _pkg_prefix)

  # specifically for FindQt:
  set(QT_USE_IMPORTED_TARGETS 1)
  if("${_name}" STREQUAL "Qt5")
    # add core module if Qt5 requested
    set(_extra COMPONENTS Core)
  else()
    set(_extra)
  endif()

  # ARGN is a special entity, cannot be used as a list
  set(_args ${ARGN})
  list(FIND _args "REQUIRED" _index)
  if(NOT _index EQUAL -1)
    # REQUIRED
    if(DEFINED USE_${_pkg_prefix} AND NOT USE_${_pkg_prefix})
      message(ERROR "USE_${_pkg_prefix} is OFF, but ${_name} is required!")
    endif()
    find_package(${_name} ${ARGN} ${_extra})
    list(APPEND ${_prefix}_REQUIRED_PACKAGES ${_name})
    list(APPEND ${_prefix}_REQUESTED_PACKAGES ${_name})
  else()
    # OPTIONAL
    if(DEFINED USE_${_pkg_prefix} AND NOT USE_${_pkg_prefix})
      option(USE_${_pkg_prefix} "Use package ${_name}" OFF)
    elseif(USE_${_pkg_prefix})
      option(USE_${_pkg_prefix} "Use package ${_name}" ON)
      find_package(${_name} ${ARGN} ${_extra})
      list(APPEND ${_prefix}_REQUESTED_PACKAGES ${_name})
    else()
      find_package(${_name} ${ARGN} QUIET ${_extra})
      if(${_name}_FOUND)
        set(_found_version)
        if(${_name}_VERSION)
          set(_found_version " (found version \"${${_name}_VERSION}\")")
        endif()
        message(STATUS "Found ${_name}${_found_version}.")
        option(USE_${_pkg_prefix} "Use package ${_name}" ON)
      else()
        option(USE_${_pkg_prefix} "Use package ${_name}" OFF)
      endif()
    endif()
  endif()

  # reuse any _DIR variables that were configured by the package
  foreach(_pkg ${${_pkg_prefix}_PACKAGES})
    if(NOT ${_pkg}_DIR)
      if(${_pkg_prefix}_${_pkg}_DIR)
        set(${_pkg}_DIR "${${_pkg_prefix}_${_pkg}_DIR}")
      endif()
    endif()
  endforeach()

endmacro()
