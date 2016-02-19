#==========================================================================
#
# This file provides macros for creating generic modules.
#
#==========================================================================

#--------------------------------------------------------------------------
# module(<name> [ DEPENDS <dependencies> ... ])
#
# This macro creates a module, and it should be the first macro to
# appear in the CMakeLists.txt file of any source directory.
# It must give the name of the module (which will be the name used for
# the library that is created from the source files in the directory),
# followed by the names of any modules that this library depends on.
#
# The following cmake variables are set by this macro:
# MODULE_NAME          the name of the module
# <module>_DEPENDS        dependencies of the module
# <module>_TEST_DEPENDS   extra dependencies for the tests

macro(module _name)
  # verify that the name is a valid library name
  if(NOT "${_name}" MATCHES "^[a-zA-Z][a-zA-Z0-9]*$")
    message(FATAL_ERROR "Invalid module name: ${_name}")
  endif()
  # the name of the module is stored in ${module}
  set(MODULE_NAME ${_name})
  # this is set to indicate that this macro was called
  set(${MODULE_NAME}_DECLARED 1 PARENT_SCOPE)
  # all the dependencies will be added to this list
  set(${MODULE_NAME}_DEPENDS PARENT_SCOPE)
  # the dependencies of all tests will be added to this list
  set(${MODULE_NAME}_TEST_DEPENDS PARENT_SCOPE)
  # the source and build directories
  set(${MODULE_NAME}_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  set(${MODULE_NAME}_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})
  foreach(_arg ${ARGN})
    if(${_arg} MATCHES "^(|TEST_)DEPENDS$")
      set(_part ${_arg})
    elseif(_part)
      list(APPEND ${MODULE_NAME}_${_part} "${_arg}")
    endif()
  endforeach()
  foreach(_prefix "" "TEST_")
    if(${MODULE_NAME}_${_prefix}DEPENDS)
      list(SORT ${MODULE_NAME}_${_prefix}DEPENDS)
    endif()
  endforeach()
  # load all module dependencies
  module_impl()
  # initialize the config variables
  set(HEADER_CONFIG)
  set(EXPORT_CONFIG)
endmacro()

#--------------------------------------------------------------------------
# test_module()
#
# This macro creates a test module, and it should be the first
# macro to appear in the CMakeLists.txt file of any testing
# directory.

macro(test_module)
  # CURRENT_MODULE is set in project_modules()
  set(MODULE_NAME ${CURRENT_MODULE})
  # this is set to indicate that this macro was called
  set(${MODULE_NAME}_DECLARED 2 PARENT_SCOPE)
  # all the dependencies will be added to this list
  set(${MODULE_NAME}_DEPENDS PARENT_SCOPE)
  # the dependencies of all tests will be added to this list
  set(${MODULE_NAME}_TEST_DEPENDS PARENT_SCOPE)
  # the source and build directories
  set(${MODULE_NAME}_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  set(${MODULE_NAME}_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})
  # load all module dependencies
  module_impl()
endmacro()

#--------------------------------------------------------------------------
# module_library(<name> <source_files>)
#
# This function names the library that is produced by a module, and lists the
# source files that are compiled into the library.
#
# This is declared as a function, rather than as a macro, so that all of the
# variables that it defines are only defined within its own scope.

function(module_library _name)
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})

  # verify that the library name matches the module name
  if(NOT "${_name}" STREQUAL "${MODULE_NAME}")
    message(FATAL_ERROR
      "Library name ${_name} does not match module name ${MODULE_NAME}")
  endif()

  # create the library and add its dependencies
  add_library(${_name} ${ARGN})
  if(${MODULE_NAME}_LINK_LIBRARIES)
    target_link_libraries(${_name} ${${MODULE_NAME}_LINK_LIBRARIES})
  endif()
  list(APPEND ${MODULE_NAME}_LIBRARIES ${_name})

  # add the library as a project target
  set_property(GLOBAL APPEND PROPERTY ${_prefix}_TARGETS ${_name})

  # install rule for the library
  install(TARGETS
    ${_name}
    EXPORT ${_package}Targets
    RUNTIME DESTINATION ${${_prefix}_RUNTIME_INSTALL_DEST} COMPONENT RuntimeLibraries
    LIBRARY DESTINATION ${${_prefix}_LIBRARY_INSTALL_DEST} COMPONENT RuntimeLibraries
    ARCHIVE DESTINATION ${${_prefix}_ARCHIVE_INSTALL_DEST} COMPONENT Development)

  # export a .cmake file that other modules can load
  module_export_info()

  # automatically find the header for each cxx file
  set(_hdrs ${${MODULE_NAME}_HDRS})
  foreach(arg ${ARGN})
    get_filename_component(src "${arg}" ABSOLUTE)
    string(REGEX REPLACE "\\.(cxx|c|mm|m)$" ".h" hdr "${src}")
    if("${hdr}" MATCHES "\\.h$" AND EXISTS "${hdr}")
      list(APPEND _hdrs "${hdr}")
    endif()
  endforeach()

  # generate a config header for the module
  set(_libname ${_name})
  get_target_property(_type ${_name} TYPE)
  if(${_type} STREQUAL "SHARED_LIBRARY")
    set(_shared_def "#define")
  else()
    set(_shared_def "//#undef")
  endif()
  foreach(_line ${HEADER_CONFIG})
    set(_config "${_config}\n${_line}")
  endforeach()
  configure_file("${PACKAGE_MACROS_CMAKE_DIR}/Module.h.in"
    "${${MODULE_NAME}_BINARY_DIR}/${_name}Module.h" @ONLY)
  list(APPEND _hdrs "${${MODULE_NAME}_BINARY_DIR}/${_name}Module.h")

  # install rule for the headers
  install(FILES ${_hdrs}
    DESTINATION ${${_prefix}_INCLUDE_INSTALL_DEST} COMPONENT Development)

endfunction()

#-----------------------------------------------------------------------------
# Map all Qt4 module names to our desired Qt module names
set(_qt4_modules_uppercase
  QTCORE QTGUI QT3SUPPORT QTASSISTANT QTASSISTANTCLIENT QAXCONTAINER
  QAXSERVER QTDBUS QTDESIGNER QTDESIGNERCOMPONENTS QTHELP QTMOTIF
  QTMULTIMEDIA QTNETWORK QTNSPLUGIN QTOPENGL QTSCRIPT QTSQL QTSVG QTTEST
  QTUITOOLS QTWEBKIT QTXML QTXMLPATTERNS QTMAIN PHONON QTSCRIPTTOOLS)

set(_qt4_modules_camelcase
  QtCore QtGui Qt3Support QtAssistant QtAssistantClient QAxContainer
  QAxServer QtDBus QtDesigner QtDesignerComponents QtHelp QtMotif
  QtMultimedia QtNetwork QtNsPLugin QtOpenGL QtScript QtSql QtSvg QtTest
  QtUiTools QtWebKit QtXml QtXmlPatterns qtmain phonon QtScriptTools)

# list dependent modules, so dependent libraries are added
set(QT_QT3SUPPORT_MODULE_DEPENDS QTGUI QTSQL QTXML QTNETWORK QTCORE)
set(QT_QTSVG_MODULE_DEPENDS QTGUI QTXML QTCORE)
set(QT_QTUITOOLS_MODULE_DEPENDS QTGUI QTXML QTCORE)
set(QT_QTHELP_MODULE_DEPENDS QTGUI QTSQL QTXML QTNETWORK QTCORE)
if(QT_QTDBUS_FOUND)
  set(QT_PHONON_MODULE_DEPENDS QTGUI QTDBUS QTCORE)
else(QT_QTDBUS_FOUND)
  set(QT_PHONON_MODULE_DEPENDS QTGUI QTCORE)
endif(QT_QTDBUS_FOUND)
set(QT_QTDBUS_MODULE_DEPENDS QTXML QTCORE)
set(QT_QTXMLPATTERNS_MODULE_DEPENDS QTNETWORK QTCORE)
set(QT_QAXCONTAINER_MODULE_DEPENDS QTGUI QTCORE)
set(QT_QAXSERVER_MODULE_DEPENDS QTGUI QTCORE)
set(QT_QTSCRIPTTOOLS_MODULE_DEPENDS QTGUI QTCORE)
set(QT_QTWEBKIT_MODULE_DEPENDS QTXMLPATTERNS QTGUI QTCORE)
set(QT_QTDECLARATIVE_MODULE_DEPENDS QTSCRIPT QTSVG QTSQL QTXMLPATTERNS QTGUI QTCORE)
set(QT_QTMULTIMEDIA_MODULE_DEPENDS QTGUI QTCORE)
set(QT_QTOPENGL_MODULE_DEPENDS QTGUI QTCORE)
set(QT_QTSCRIPT_MODULE_DEPENDS QTCORE)
set(QT_QTGUI_MODULE_DEPENDS QTCORE)
set(QT_QTTEST_MODULE_DEPENDS QTCORE)
set(QT_QTXML_MODULE_DEPENDS QTCORE)
set(QT_QTSQL_MODULE_DEPENDS QTCORE)
set(QT_QTNETWORK_MODULE_DEPENDS QTCORE)

#-----------------------------------------------------------------------------
# Private helper macros.  Original file: vtkModuleAPI.cmake in VTK.
#-----------------------------------------------------------------------------

#--------------------------------------------------------------------------
# package_config(<prefix> <module>...)
#
# Create compile variables based on requested modules.
macro(package_config _prefix)
  set(${_prefix}_DEFINITIONS) # unused for now
  set(${_prefix}_LIBRARIES)
  set(${_prefix}_INCLUDE_DIRS)
  set(${_prefix}_LIBRARY_DIRS)
  set(${_prefix}_RUNTIME_LIBRARY_DIRS)

  foreach(_mod ${ARGN})
    module_load(${_mod})
    foreach(_part LIBRARIES INCLUDE_DIRS LIBRARY_DIRS RUNTIME_LIBRARY_DIRS)
      list(APPEND ${_prefix}_${_part} ${${_mod}_${_part}})
    endforeach()
  endforeach()

  foreach(_part LIBRARIES INCLUDE_DIRS LIBRARY_DIRS RUNTIME_LIBRARY_DIRS)
    if(${_prefix}_${_part})
      list(REMOVE_DUPLICATES ${_prefix}_${_part})
    endif()
  endforeach()

  foreach(_depend ${${_prefix}_PACKAGES})
    set(_package ${${_prefix}_PACKAGE_NAME})
    list(FIND ${_depend}_REQUIRED_BY ${_package} _index)
    if(${_index} EQUAL -1)
      list(APPEND ${_depend}_REQUIRED_BY ${_package})
      list(FIND DEPENDS_REQUIRED_PACKAGES ${_depend} _index)
      if(${_index} EQUAL -1)
        list(APPEND DEPENDS_REQUIRED_PACKAGES ${_depend})
      endif()
    endif()
  endforeach()

endmacro()

#--------------------------------------------------------------------------
# _module_config_recurse(<namespace> <module>)
#
# Internal macro to recursively load module information into the supplied
# namespace, this is called from module_config. It should be noted that
# _${ns}_${mod}_USED must be cleared if this macro is to work correctly on
# subsequent invocations. The macro will load the module files using the
# module_load, making all of its variables available in the local scope.
macro(_module_config_recurse ns mod)
  if(NOT _${ns}_${mod}_USED)
    set(_${ns}_${mod}_USED 1)
    list(APPEND _${ns}_USED_MODULES ${mod})
    module_load("${mod}")
    if(${mod}_LOADED)
      list(APPEND ${ns}_DEFINITIONS ${${mod}_DEFINITIONS})
      list(APPEND ${ns}_LIBRARIES ${${mod}_LIBRARIES})
      list(APPEND ${ns}_INCLUDE_DIRS ${${mod}_INCLUDE_DIRS})
      list(APPEND ${ns}_LIBRARY_DIRS ${${mod}_LIBRARY_DIRS})
      list(APPEND ${ns}_RUNTIME_LIBRARY_DIRS ${${mod}_RUNTIME_LIBRARY_DIRS})
      foreach(iface IN LISTS ${mod}_IMPLEMENTS)
        list(APPEND _${ns}_AUTOINIT_${iface} ${mod})
        list(APPEND _${ns}_AUTOINIT ${iface})
      endforeach()
      foreach(dep IN LISTS ${mod}_DEPENDS)
        _module_config_recurse("${ns}" "${dep}")
      endforeach()
    else()
      # "mod" was actually just a library, not a module
      list(APPEND ${ns}_LIBRARIES ${mod})
    endif()
  endif()
endmacro()

#-----------------------------------------------------------------------------
# Public interface macros.

# module_load(<module>)
#
# Loads variables describing the given module, these include custom variables
# set by the module along with the standard ones listed below:
#  <module>_LOADED         = True if the module has been loaded
#  <module>_DEPENDS        = List of dependencies on other modules
#  <module>_LIBRARIES      = Libraries to link
#  <module>_INCLUDE_DIRS   = Header search path
#  <module>_LIBRARY_DIRS   = Library search path (for outside dependencies)
#  <module>_RUNTIME_LIBRARY_DIRS = Runtime linker search path
# If the "module" was just a library, then the following is set, and the
# USE_FILE for the package owning the library is loaded.
#  <library>_RESOLVED      = True if the library target exists
macro(module_load mod)
  if(NOT ${mod}_LOADED AND NOT ${mod}_RESOLVED)
    #message(STATUS "Loading dependency: ${mod}")
    include("${${PACKAGE_PREFIX}_MODULES_DIR}/${mod}.cmake"
      OPTIONAL RESULT_VARIABLE _found)
    if(NOT _found)
      # When building applications outside this project, they can provide
      # extra module config files by simply adding the corresponding
      # locations to the CMAKE_MODULE_PATH
      include(${mod} OPTIONAL)
    endif()
    if(NOT ${mod}_LOADED)
      #message(STATUS "${mod} not found: ${CMAKE_MODULE_PATH}")
      # Still not found, it must not be a module after all!
      if(TARGET ${mod})
        # If it is a target, it is a library from an included package
        set(${mod}_RESOLVED 1)
        # Load the USE_FILE of the package the library belongs to
        foreach(_package ${${PACKAGE_PREFIX}_REQUESTED_PACKAGES})
          set(_use_file "")
          # Also try uppercase package name
          string(TOUPPER "${_package}" _upackage)
          package_uppercase("${_package}" _u_package)
          set(_pkg_list ${_package} ${_upackage} ${_u_package})
          list(REMOVE_DUPLICATES _pkg_list)
          foreach(_pkg ${_pkg_list})
            list(FIND ${_pkg}_LIBRARIES ${mod} _index)
            if(${_index} EQUAL -1)
              list(FIND ${_pkg}_MODULES ${mod} _index)
            endif()
            if(NOT ${_index} EQUAL -1)
              set(_use_file "${${_pkg}_USE_FILE}")
            endif()
          endforeach()
          if("${_use_file}" STREQUAL "")
            if(${mod} MATCHES "^Qt" AND ${_package} MATCHES "^Qt")
              set(_use_file "${QT_USE_FILE}")
            endif()
          endif()
          if(NOT "${_use_file}" STREQUAL "")
            if(NOT ${_package}_USE_FILE_INCLUDED)
              #message(STATUS "Loading ${_use_file} for ${mod} in ${_package}")
              include("${_use_file}")
              set(${_package}_USE_FILE_INCLUDED 1)
            endif()
          endif()
        endforeach()
      elseif(${mod} MATCHES "^Qt[5-9][^:]*$")
        # Qt5 is divided into sub-packages, rather than modules
        find_package(${mod})
        if(${mod}_FOUND)
          set(${mod}_LOADED 1)
        endif()
      elseif(${mod} MATCHES "^Qt[^:]*$")
        # Qt4 has its own per-module variables
        string(TOUPPER ${mod} _umod)
        if(QT_${_umod}_LIBRARY)
          set(${mod}_LOADED 1)
          foreach(_dmod ${QT_${_umod}_MODULE_DEPENDS})
            # Qt4 depends are uppercase, need to convert to mixed case
            list(FIND _qt4_modules_uppercase ${_dmod} _index)
            if(${_index} GREATER -1)
              list(GET _qt4_modules_camelcase ${_index} _dmod2)
              list(APPEND ${mod}_DEPENDS ${_dmod2})
            endif()
          endforeach()
          set(${mod}_LIBRARIES ${QT_${_umod}_LIBRARY})
          set(${mod}_INCLUDE_DIRS ${QT_${_umod}_INCLUDE_DIR})
          set(${mod}_LIBRARY_DIRS ${QT_LIBRARY_DIR})
          set(${mod}_DEFINITIONS "-DQT_${_umod}_LIB")
          if("${mod}" STREQUAL "Qt3Support")
            set(${mod}_DEFINITIONS "-DQT3_SUPPORT" ${mod}_DEFINITIONS)
          endif()
          set(QT_USE_${_umod} 1)
          if(NOT QT_DIRECTORY_PROPERTIES_ARE_SET)
            set_property(DIRECTORY APPEND PROPERTY
              COMPILE_DEFINITIONS_DEBUG QT_DEBUG)
            set_property(DIRECTORY APPEND PROPERTY
              COMPILE_DEFINITIONS_RELEASE QT_NO_DEBUG)
            set_property(DIRECTORY APPEND PROPERTY
              COMPILE_DEFINITIONS_RELWITHDEBINFO QT_NO_DEBUG)
            set_property(DIRECTORY APPEND PROPERTY
               COMPILE_DEFINITIONS_MINSIZEREL QT_NO_DEBUG)
            if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
              set_property(DIRECTORY APPEND PROPERTY
                COMPILE_DEFINITIONS QT_NO_DEBUG)
            endif()
            set(QT_DIRECTORY_PROPERTIES_ARE_SET 1)
          endif()
        endif()
      endif()
      if(NOT ${mod}_LOADED AND NOT ${mod}_RESOLVED)
        message(FATAL_ERROR "Dependency is neither a module nor a target: \"${mod}\"")
      endif()
    endif()
  endif()
endmacro()

# module_dep_includes(<module>)
#
# Loads the <module>_DEPENDS_INCLUDE_DIRS variable.
macro(module_dep_includes mod)
  module_load("${mod}")
  module_config(_dep_${mod} ${${mod}_DEPENDS})
  if(_dep_${mod}_INCLUDE_DIRS)
    set(${mod}_DEPENDS_INCLUDE_DIRS ${_dep_${mod}_INCLUDE_DIRS})
  endif()
endmacro()

# module_headers_load(<module>)
#
# Loads variables describing the headers/API of the given module, this is not
# loaded by module_config, and is mainly useful for wrapping generation:
#  <module>_HEADERS_LOADED      = True if the module header info has been loaded
#  <module>_HEADERS             = List of headers
#  <module>_HEADER_<header>_EXISTS
#  <module>_HEADER_<header>_ABSTRACT
#  <module>_HEADER_<header>_WRAP_EXCLUDE
#  <module>_HEADER_<header>_WRAP_SPECIAL
macro(module_headers_load mod)
  if(NOT ${mod}_HEADERS_LOADED)
    set(_package ${CMAKE_PROJECT_NAME})
    set(_prefix ${PACKAGE_PREFIX})
    include("${${_prefix}_MODULES_DIR}/${mod}-Headers.cmake"
      OPTIONAL RESULT_VARIABLE _found)
    if(NOT _found)
      # When building applications outside this project, they can provide
      # extra module config files by simply adding the corresponding
      # locations to the CMAKE_MODULE_PATH
      include(${mod}-Headers OPTIONAL)
    endif()
    if(NOT ${mod}_HEADERS_LOADED)
      message(FATAL_ERROR "No such module: \"${mod}\"")
    endif()
  endif()
endmacro()

# module_config(<namespace> [modules...])
#
# Configures variables describing the given modules and their dependencies:
#  <namespace>_DEFINITIONS  = Preprocessor definitions
#  <namespace>_LIBRARIES    = Libraries to link
#  <namespace>_INCLUDE_DIRS = Header search path
#  <namespace>_LIBRARY_DIRS = Library search path (for outside dependencies)
#  <namespace>_RUNTIME_LIBRARY_DIRS = Runtime linker search path
#
# Calling this macro also recursively calls module_load for all modules
# explicitly named, and their dependencies, making them available in the local
# scope. This means that module level information can be accessed once this
# macro has been called.
#
# Do not name a module as the namespace.
macro(module_config ns)
  set(_prefix ${PACKAGE_PREFIX})
  set(_${ns}_MISSING ${ARGN})
  if(_${ns}_MISSING)
    list(REMOVE_ITEM _${ns}_MISSING ${${_prefix}_MODULES_ENABLED})
  endif()
  if(_${ns}_MISSING)
    set(msg "")
    foreach(mod ${_${ns}_MISSING})
      list(FIND ${_prefix}_MODULES_ALL ${mod} _index)
      if(NOT ${_index} EQUAL -1)
        set(msg "${msg}\n  ${mod}")
      endif()
    endforeach()
    if(NOT "${msg}" STREQUAL "")
      message(FATAL_ERROR "Requested modules not enabled:${msg}")
    endif()
  endif()

  set(_parts
    DEFINITIONS LIBRARIES INCLUDE_DIRS LIBRARY_DIRS RUNTIME_LIBRARY_DIRS)

  foreach(_part ${_parts})
    set(${ns}_${_part} "")
  endforeach()

  set(_${ns}_USED_MODULES "")
  foreach(mod ${ARGN})
    _module_config_recurse("${ns}" "${mod}")
  endforeach()
  foreach(mod ${_${ns}_USED_MODULES})
    unset(_${ns}_${mod}_USED)
  endforeach()
  unset(_${ns}_USED_MODULES)

  foreach(_part ${_parts})
    if(_${ns}_${_part})
      list(REMOVE_DUPLICATES _${ns}_${_part})
    endif()
  endforeach()
endmacro()

# module_impl()
#
# This macro provides module implementation, setting up important variables
# necessary to build a module. It assumes we are in the directory of the module.
macro(module_impl)
  module_config(_dep ${${MODULE_NAME}_DEPENDS})
  if(_dep_DEFINITIONS)
    add_definitions(${_dep_DEFINITIONS})
  endif()
  include_directories(${${_prefix}_BINARY_DIR})
  if(_dep_INCLUDE_DIRS)
    include_directories(${_dep_INCLUDE_DIRS})
    # This variable is used in vtkWrapping.cmake
    set(${MODULE_NAME}_DEPENDS_INCLUDE_DIRS ${_dep_INCLUDE_DIRS})
  endif()
  if(_dep_LIBRARY_DIRS)
    link_directories(${_dep_LIBRARY_DIRS})
  endif()

  # Set the AUTOINIT definitions
  if(__dep_AUTOINIT)
    list(REMOVE_DUPLICATES __dep_AUTOINIT)
    set(_autoinit_defs)
    foreach(_mod ${__dep_AUTOINIT})
      list(LENGTH __dep_AUTOINIT_${_mod} _len)
      set(_def "${_mod}_AUTOINIT=${_len}(")
      set(_sep "")
      foreach(_imp ${__dep_AUTOINIT_${_mod}})
        set(_def "${_def}${_sep}${_imp}")
        set(_sep ",")
      endforeach()
      set(_def "${_def})")
      list(APPEND _autoinit_defs "${_def}")
    endforeach()
    set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS
                 ${_autoinit_defs})
  endif()

  list(APPEND ${MODULE_NAME}_LINK_LIBRARIES ${_dep_LIBRARIES})

  list(APPEND ${MODULE_NAME}_INCLUDE_DIRS
    ${${MODULE_NAME}_BINARY_DIR}
    ${${MODULE_NAME}_SOURCE_DIR})
  list(REMOVE_DUPLICATES ${MODULE_NAME}_INCLUDE_DIRS)

  if(${MODULE_NAME}_INCLUDE_DIRS)
    include_directories(${${MODULE_NAME}_INCLUDE_DIRS})
  endif()
  if(${MODULE_NAME}_SYSTEM_INCLUDE_DIRS)
    include_directories(${${MODULE_NAME}_SYSTEM_INCLUDE_DIRS})
  endif()

  if(${MODULE_NAME}_SYSTEM_LIBRARY_DIRS)
    link_directories(${${MODULE_NAME}_SYSTEM_LIBRARY_DIRS})
  endif()

  if(${MODULE_NAME}_THIRD_PARTY)
    module_warnings_disable(C CXX)
  endif()
endmacro()

# module_export_info()
#
# Export just the essential data from a module such as name, include directory,
# libraries provided by the module, and any custom variables that are part of
# the module configuration.
macro(module_export_info)
  set(_package ${CMAKE_PROJECT_NAME})
  set(_prefix ${PACKAGE_PREFIX})
  set(_module ${MODULE_NAME})
  # First gather and configure the high level module information.
  set(_code "")
  foreach(_line ${EXPORT_CONFIG})
    set(_code "${_code}\n${_line}")
  endforeach()
  if(${_module}_EXCLUDE_FROM_WRAPPING)
    set(_code "${_code}\nset(${_module}_EXCLUDE_FROM_WRAPPING 1)")
  endif()
  if(${_module}_IMPLEMENTS)
    set(_code "${_code}\nset(${_module}_IMPLEMENTS \"${${_module}_IMPLEMENTS}\")")
  endif()
  set(_module_export_code_build "${_code}")
  set(_module_export_code_install "${_code}")
  if(${_module}_WRAP_HINTS)
    set(_module_export_code_build
      "${_module_export_code_build}\nset(${_module}_WRAP_HINTS \"${${_module}_WRAP_HINTS}\")")
    set(_module_export_code_install
      "${_module_export_code_install}\nset(${_module}_WRAP_HINTS \"\${CMAKE_CURRENT_LIST_DIR}/${_module}_hints\")")
  endif()

  set(_module_depends "${${_module}_DEPENDS}")
  set(_module_libraries "${${_module}_LIBRARIES}")
  set(_module_include_dirs_build "${${_module}_INCLUDE_DIRS}")
  set(_module_include_dirs_install "\${${_prefix}_INSTALL_PREFIX}${${_prefix}_INC_DIR}")
  if(${_module}_SYSTEM_INCLUDE_DIRS)
    list(APPEND _module_include_dirs_build "${${_module}_SYSTEM_INCLUDE_DIRS}")
    list(APPEND _module_include_dirs_install "${${_module}_SYSTEM_INCLUDE_DIRS}")
  endif()
  if(WIN32)
    set(_module_runtime_dirs_build "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
    set(_module_runtime_dirs_install "\${${_prefix}_INSTALL_PREFIX}${${_prefix}_BIN_DIR}")
  else()
    set(_module_runtime_dirs_build "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
    set(_module_runtime_dirs_install "\${${_prefix}_INSTALL_PREFIX}${${_prefix}_LIB_DIR}")
  endif()
  set(_module_library_dirs "${${_module}_SYSTEM_LIBRARY_DIRS}")
  set(_module_runtime_dirs "${_module_runtime_dirs_build}")
  set(_module_include_dirs "${_module_include_dirs_build}")
  set(_module_export_code "${_module_export_code_build}")
  set(_module_hierarchy_file "${${_module}_WRAP_HIERARCHY_FILE}")
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/ModuleInfo.cmake.in
    ${${_prefix}_MODULES_DIR}/${_module}.cmake @ONLY)
  set(_module_include_dirs "${_module_include_dirs_install}")
  set(_module_runtime_dirs "${_module_runtime_dirs_install}")
  set(_module_export_code "${_module_export_code_install}")
  set(_module_hierarchy_file
    "\${CMAKE_CURRENT_LIST_DIR}/${_module}Hierarchy.txt")
  configure_file(${PACKAGE_MACROS_CMAKE_DIR}/ModuleInfo.cmake.in
    CMakeFiles/${_module}.cmake @ONLY)
  if (NOT ${_prefix}_INSTALL_NO_DEVELOPMENT)
    install(FILES ${${_module}_BINARY_DIR}/CMakeFiles/${_module}.cmake
      DESTINATION ${${_prefix}_PACKAGE_INSTALL_DEST}
      COMPONENT Development)
    if(NOT ${_module}_EXCLUDE_FROM_WRAPPING)
      if(${_prefix}_WRAP_PYTHON OR ${_prefix}_WRAP_TCL OR ${_prefix}_WRAP_JAVA)
        install(FILES ${${_module}_WRAP_HIERARCHY_FILE}
          DESTINATION ${${_prefix}_PACKAGE_INSTALL_DEST}
          COMPONENT Development)
      endif()
      if(${_module}_WRAP_HINTS AND EXISTS "${${_module}_WRAP_HINTS}")
        install(FILES ${${_module}_WRAP_HINTS}
          RENAME ${_module}_HINTS
          DESTINATION ${${_prefix}_PACKAGE_INSTALL_DEST}
          COMPONENT Development)
      endif()
    endif()
  endif()
endmacro()
