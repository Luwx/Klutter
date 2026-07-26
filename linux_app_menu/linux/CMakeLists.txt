# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "linux_app_menu")
project(${PROJECT_NAME} LANGUAGES C CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "linux_app_menu_plugin")

# Wayland dependencies and protocol generation.
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(GDK_WAYLAND REQUIRED IMPORTED_TARGET gdk-wayland-3.0)

pkg_get_variable(WAYLAND_SCANNER_EXEC wayland-scanner wayland_scanner)
if(NOT WAYLAND_SCANNER_EXEC)
  find_program(WAYLAND_SCANNER_EXEC NAMES wayland-scanner)
endif()
if(NOT WAYLAND_SCANNER_EXEC)
  message(FATAL_ERROR "wayland-scanner not found; install the Wayland development tools")
endif()

set(APPMENU_PROTOCOL_XML "${CMAKE_CURRENT_SOURCE_DIR}/appmenu.xml")
set(APPMENU_PROTOCOL_C "${CMAKE_CURRENT_BINARY_DIR}/appmenu-protocol.c")
set(APPMENU_PROTOCOL_H "${CMAKE_CURRENT_BINARY_DIR}/appmenu-protocol.h")
add_custom_command(
  OUTPUT "${APPMENU_PROTOCOL_H}"
  COMMAND "${WAYLAND_SCANNER_EXEC}" client-header
          "${APPMENU_PROTOCOL_XML}" "${APPMENU_PROTOCOL_H}"
  DEPENDS "${APPMENU_PROTOCOL_XML}"
  VERBATIM
)
add_custom_command(
  OUTPUT "${APPMENU_PROTOCOL_C}"
  COMMAND "${WAYLAND_SCANNER_EXEC}" private-code
          "${APPMENU_PROTOCOL_XML}" "${APPMENU_PROTOCOL_C}"
  DEPENDS "${APPMENU_PROTOCOL_XML}" "${APPMENU_PROTOCOL_H}"
  VERBATIM
)

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "linux_app_menu_plugin.cc"
  "linux_app_menu_wayland.c"
  "${APPMENU_PROTOCOL_C}"
  "${APPMENU_PROTOCOL_H}"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GDK_WAYLAND)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(linux_app_menu_bundled_libraries
  ""
  PARENT_SCOPE
)
