#==========================================================================
#
# This file provides a function for wrapping generic modules.
#
#==========================================================================

#--------------------------------------------------------------------------
# wrap_module(<name> <source_files>)
#
# This function wraps the module library. It is called by module_library()
# if <package>_WRAP_PYTHON, <package>_WRAP_JAVA, or <package>_WRAP_TCL
# is set and if <module>_EXCLUDE_FROM_WRAPPING is not set.
#
# The following variable must be set before this macro is called:
#   PACKAGE_PREFIX    - this is set by the package() macro
#
# The following variable is optional:
#   <module>_LIB_SUFFIX
#   <module>_WRAP_HINTS
#
# The following variable is set for use by the VTK wrapping macros:
#   KIT_HIERARCHY_FILE

function(wrap_module _name _srcs)

  set(_prefix ${PACKAGE_PREFIX})

  # Set VTK_WRAP_HINTS for vtkWrapPython.cmake et al.
  if(${_name}_WRAP_HINTS AND EXISTS "${${_name}_WRAP_HINTS}")
    set(VTK_WRAP_HINTS "${${_name}_WRAP_HINTS}")
  elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/${_name}_hints")
    set(VTK_WRAP_HINTS "${CMAKE_CURRENT_LIST_DIR}/${_name}_hints")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/hints")
    set(VTK_WRAP_HINTS "${CMAKE_CURRENT_SOURCE_DIR}/hints")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/hints.txt")
    set(VTK_WRAP_HINTS "${CMAKE_CURRENT_SOURCE_DIR}/hints.txt")
  endif()

  # Create the hierarchy file
  if("${VTK_MAJOR_VERSION}" GREATER 5 AND
     NOT ${_name}_EXCLUDE_FROM_WRAP_HIERARCHY)
    if(${_prefix}_WRAP_PYTHON OR ${_prefix}_WRAP_TCL OR ${_prefix}_WRAP_JAVA)
      set_source_files_properties(${LIB_SPECIAL} PROPERTIES WRAP_SPECIAL ON)
      set(_hname ${_name}Hierarchy)
      # _LINK_DEPENDS is a variable suffix from the VTK 6 module macros,
      # it is used by vtkWrapHierarchy, vtkWrapTcl, and vtkWrapJava
      set(${_name}_LINK_DEPENDS ${${_name}_LINK_LIBRARIES})
      include("${PACKAGE_MACROS_CMAKE_DIR}/vtkWrapHierarchy.cmake")
      vtk_wrap_hierarchy(${_name} ${CMAKE_CURRENT_BINARY_DIR} "${_srcs}")
      set(KIT_HIERARCHY_FILE ${CMAKE_CURRENT_BINARY_DIR}/${_hname}.txt)
      set(LIB_HIERARCHY_STAMP ${CMAKE_CURRENT_BINARY_DIR}/${_hname}.stamp.txt)
    endif()
  endif()

  # Wrappers
  if(${_prefix}_WRAP_PYTHON AND NOT ${_name}_EXCLUDE_FROM_WRAPPING AND
     NOT ${_name}_EXCLUDE_FROM_PYTHON_WRAPPING)
    set(XY) # Get python version, e.g. 27 for python 2.7
    if(vtkPython_LIBRARIES)
      list(GET vtkPython_LIBRARIES 0 _pylib_name)
      get_filename_component(_pylib_name "${_pylib_name}" NAME)
      string(REGEX REPLACE "^[^0-9]*([0-9])\\.*([0-9]).*$" "\\1\\2"
        XY "${_pylib_name}")
      if(NOT XY)
        set(XY)
      endif()
    endif()
    set(MODULE_PYTHON_NAME ${_name}Python)
    set(LIB_PYTHON_NAME ${_name}PythonD)
    set(LIB_PYTHON_OUTPUT_NAME ${_name}Python${XY}D)
    if("${VTK_MAJOR_VERSION}" GREATER 5)
      set(LIB_PYTHON_OUTPUT_NAME
        ${LIB_PYTHON_OUTPUT_NAME}${${_name}_LIB_SUFFIX})
    endif()
    if("${VTK_MAJOR_VERSION}" GREATER 5)
      set(LIB_PYTHON_LIBS vtkWrappingPythonCore)
      module_dep_includes(vtkWrappingPythonCore)
      include_directories(${vtkWrappingPythonCore_INCLUDE_DIRS}
                          ${vtkWrappingPythonCore_DEPENDS_INCLUDE_DIRS})
    else()
      set(LIB_PYTHON_LIBS vtkPythonCore)
      if(VTK_PYTHON_INCLUDE_DIR)
        include_directories(${VTK_PYTHON_INCLUDE_DIR})
      endif()
    endif()

    foreach(_dep IN LISTS ${_name}_DEPENDS)
      if(NOT "${_name}" STREQUAL "${_dep}" AND TARGET ${_dep}PythonD)
        list(APPEND LIB_PYTHON_LIBS ${_dep}PythonD)
      endif()
    endforeach()

    # Tell vtkWrapPython to locate the python libraries for us.
    set(VTK_WRAP_PYTHON_FIND_LIBS ON)
    include("${VTK_CMAKE_DIR}/vtkWrapPython.cmake")
    vtk_wrap_python3(${MODULE_PYTHON_NAME} LIB_PYTHON_SRCS "${_srcs}")
    add_library(${LIB_PYTHON_NAME}
      ${LIB_PYTHON_SRCS} ${LIB_PYTHON_EXTRA_SRCS}
      ${LIB_HIERARCHY_STAMP})
    set_target_properties(${LIB_PYTHON_NAME} PROPERTIES
      POSITION_INDEPENDENT_CODE ON
      OUTPUT_NAME "${LIB_PYTHON_OUTPUT_NAME}")
    target_link_libraries(${LIB_PYTHON_NAME} LINK_PUBLIC
      ${_name} ${LIB_PYTHON_LIBS})
    # On Win32 and Mac, link python library non-private
    if(WIN32 OR APPLE)
      target_link_libraries(${LIB_PYTHON_NAME} LINK_PUBLIC
        vtkRenderingCorePythonD ${VTK_PYTHON_LIBRARIES})
    else()
      target_link_libraries(${LIB_PYTHON_NAME} LINK_PRIVATE
        ${VTK_PYTHON_LIBRARIES})
    endif()
    add_library(${MODULE_PYTHON_NAME} MODULE ${MODULE_PYTHON_NAME}Init.cxx)
    set_target_properties(${MODULE_PYTHON_NAME} PROPERTIES PREFIX "")
    if(WIN32 AND NOT CYGWIN)
      set_target_properties(${MODULE_PYTHON_NAME} PROPERTIES SUFFIX ".pyd")
    endif()
    set_target_properties(${MODULE_PYTHON_NAME} PROPERTIES NO_SONAME 1)
    target_link_libraries(${MODULE_PYTHON_NAME} ${LIB_PYTHON_NAME})
  endif()

  if(${_prefix}_WRAP_TCL AND NOT ${_name}_EXCLUDE_FROM_WRAPPING AND
     NOT ${_name}_EXCLUDE_FROM_TCL_WRAPPING)
    set(LIB_TCL_NAME ${_name}TCL)
    string(TOLOWER ${_name} MODULE_TCL_NAME)
    set(LIB_TCL_OUTPUT_NAME ${LIB_TCL_NAME})
    if("${VTK_MAJOR_VERSION}" GREATER 5)
      set(LIB_TCL_OUTPUT_NAME
        ${LIB_TCL_OUTPUT_NAME}${${_name}_LIB_SUFFIX})
    endif()
    set(LIB_TCL_LIBS)
    foreach(_dep IN LISTS ${_name}_DEPENDS)
      if(NOT "${_name}" STREQUAL "${_dep}" AND TARGET ${_dep}TCL)
        list(APPEND LIB_TCL_LIBS ${_dep}TCL)
      endif()
    endforeach()
    if("${VTK_MAJOR_VERSION}" GREATER 5)
      module_dep_includes(vtkWrappingTcl)
      include_directories(${vtkWrappingTcl_INCLUDE_DIRS}
                          ${vtkWrappingTcl_DEPENDS_INCLUDE_DIRS})
    elseif(VTK_TCL_INCLUDE_DIR)
      include_directories(${VTK_TCL_INCLUDE_DIR})
    endif()
    include("${VTK_CMAKE_DIR}/vtkWrapTcl.cmake")
    vtk_wrap_tcl3(${LIB_TCL_NAME} LIB_TCL_SRCS "${_srcs}" "")
    add_library(${LIB_TCL_NAME} ${LIB_TCL_SRCS} ${LIB_TCL_EXTRA_SRCS}
                ${LIB_HIERARCHY_STAMP})
    target_link_libraries(${LIB_TCL_NAME} LINK_PUBLIC
      ${_name} ${LIB_TCL_LIBS})
    set_target_properties(${LIB_TCL_NAME} PROPERTIES
      OUTPUT_NAME ${LIB_TCL_OUTPUT_NAME})
    # create the pkgIndex.tcl file
    set(MODULE_TCL_PATH ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    configure_file(${PACKAGE_MACROS_CMAKE_DIR}/pkgIndex.tcl.in
      "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/pkgIndex.tcl" @ONLY)
    set(MODULE_TCL_PATH ${${PACKAGE_PREFIX}_LIBRARY_INSTALL_DEST})
    configure_file(${PACKAGE_MACROS_CMAKE_DIR}/pkgIndex.tcl.in
      "${CMAKE_CURRENT_BINARY_DIR}/pkgIndex.tcl" @ONLY)
  endif()

  if(${_prefix}_WRAP_JAVA AND NOT ${_name}_EXCLUDE_FROM_WRAPPING AND
     NOT ${_name}_EXCLUDE_FROM_JAVA_WRAPPING)
    set(VTK_WRAP_JAVA3_INIT_DIR "${PACKAGE_MACROS_CMAKE_DIR}")
    set(VTK_JAVA_HOME ${CMAKE_CURRENT_BINARY_DIR}/java/vtk)
    set(VTK_JAVA_MANIFEST ${CMAKE_CURRENT_BINARY_DIR}/java/manifest.txt)
    make_directory(${VTK_JAVA_HOME})
    make_directory(${CMAKE_CURRENT_BINARY_DIR}/javajar/vtk)
    string(TOLOWER "${_name}.jar" LIB_JAVA_JAR)
    set(LIB_JAVA_NAME ${_name}Java)
    set(LIB_JAVA_LIBS)
    foreach(_dep IN LISTS ${_name}_DEPENDS)
      if(NOT "${_name}" STREQUAL "${_dep}" AND TARGET ${_dep}Java)
        list(APPEND LIB_JAVA_LIBS ${_dep}Java)
      endif()
    endforeach()

    if("${VTK_MAJOR_VERSION}" GREATER 5)
      module_dep_includes(vtkWrappingJava)
      include_directories(${vtkWrappingJava_INCLUDE_DIRS}
                          ${vtkWrappingJava_DEPENDS_INCLUDE_DIRS})
    endif()
    if(VTK_JAVA_INCLUDE_DIR)
      include_directories(${VTK_JAVA_INCLUDE_DIR})
    else()
      include_directories(${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
    endif()
    include("${VTK_CMAKE_DIR}/vtkWrapJava.cmake")
    vtk_wrap_java3(${LIB_JAVA_NAME} LIB_JAVA_SRCS "${_srcs}")
    add_library(${LIB_JAVA_NAME} SHARED
      ${LIB_JAVA_SRCS} ${LIB_JAVA_EXTRA_SRCS}
      ${LIB_HIERARCHY_STAMP})
    if(APPLE)
      set_target_properties(${LIB_JAVA_NAME} PROPERTIES SUFFIX ".jnilib")
    endif()
    set_target_properties(${LIB_JAVA_NAME} PROPERTIES NO_SONAME 1)
    target_link_libraries(${LIB_JAVA_NAME} ${_name} ${LIB_JAVA_LIBS})

    set(_sep ":")
    if(WIN32)
      set(_sep "\\;")
    endif()

    add_custom_target(${_name}JavaJar ALL
      DEPENDS ${VTK_JAR_PATH}/${LIB_JAVA_JAR})
    add_custom_target(${_name}JavaClasses ALL
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/java/javac_stamp.txt)
    add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/java/javac_stamp.txt
      DEPENDS ${VTK_JAVA_DEPENDENCIES}
      COMMAND ${JAVA_COMPILE} ${JAVAC_OPTIONS}
        -source ${VTK_JAVA_SOURCE_VERSION}
        -target ${VTK_JAVA_TARGET_VERSION}
        -classpath ${VTK_JAVA_JAR}${_sep}${VTK_DIR}/java
        -sourcepath ${VTK_DIR}/java/vtk/
        -d ${CMAKE_CURRENT_BINARY_DIR}/javajar
        ${CMAKE_CURRENT_BINARY_DIR}/java/vtk/*.java
      COMMAND ${CMAKE_COMMAND}
        -E touch ${CMAKE_CURRENT_BINARY_DIR}/java/javac_stamp.txt
      COMMENT "Compiling Java Classes"
      )
    file(WRITE ${VTK_JAVA_MANIFEST} "Class-Path: vtk.jar\n")
    add_custom_command(
      COMMAND ${JAVA_ARCHIVE} -cvfm
        "${VTK_JAR_PATH}/${LIB_JAVA_JAR}"
        ${VTK_JAVA_MANIFEST}
        -C ${CMAKE_CURRENT_BINARY_DIR}/javajar
        vtk
      DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/java/javac_stamp.txt
        ${JAVA_LIBRARIES}
      OUTPUT ${VTK_JAR_PATH}/${LIB_JAVA_JAR}
      COMMENT "Java Archive"
      )
  endif()

endfunction()
