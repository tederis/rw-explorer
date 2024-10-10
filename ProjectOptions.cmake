include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(rw_explorer_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(rw_explorer_setup_options)
  option(rw_explorer_ENABLE_HARDENING "Enable hardening" ON)
  option(rw_explorer_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    rw_explorer_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    rw_explorer_ENABLE_HARDENING
    OFF)

  rw_explorer_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR rw_explorer_PACKAGING_MAINTAINER_MODE)
    option(rw_explorer_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(rw_explorer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(rw_explorer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(rw_explorer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(rw_explorer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(rw_explorer_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(rw_explorer_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(rw_explorer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(rw_explorer_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(rw_explorer_ENABLE_IPO "Enable IPO/LTO" ON)
    option(rw_explorer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(rw_explorer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(rw_explorer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(rw_explorer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(rw_explorer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(rw_explorer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(rw_explorer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(rw_explorer_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(rw_explorer_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(rw_explorer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(rw_explorer_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      rw_explorer_ENABLE_IPO
      rw_explorer_WARNINGS_AS_ERRORS
      rw_explorer_ENABLE_USER_LINKER
      rw_explorer_ENABLE_SANITIZER_ADDRESS
      rw_explorer_ENABLE_SANITIZER_LEAK
      rw_explorer_ENABLE_SANITIZER_UNDEFINED
      rw_explorer_ENABLE_SANITIZER_THREAD
      rw_explorer_ENABLE_SANITIZER_MEMORY
      rw_explorer_ENABLE_UNITY_BUILD
      rw_explorer_ENABLE_CLANG_TIDY
      rw_explorer_ENABLE_CPPCHECK
      rw_explorer_ENABLE_COVERAGE
      rw_explorer_ENABLE_PCH
      rw_explorer_ENABLE_CACHE)
  endif()

  rw_explorer_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (rw_explorer_ENABLE_SANITIZER_ADDRESS OR rw_explorer_ENABLE_SANITIZER_THREAD OR rw_explorer_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(rw_explorer_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(rw_explorer_global_options)
  if(rw_explorer_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    rw_explorer_enable_ipo()
  endif()

  rw_explorer_supports_sanitizers()

  if(rw_explorer_ENABLE_HARDENING AND rw_explorer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR rw_explorer_ENABLE_SANITIZER_UNDEFINED
       OR rw_explorer_ENABLE_SANITIZER_ADDRESS
       OR rw_explorer_ENABLE_SANITIZER_THREAD
       OR rw_explorer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${rw_explorer_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${rw_explorer_ENABLE_SANITIZER_UNDEFINED}")
    rw_explorer_enable_hardening(rw_explorer_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(rw_explorer_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(rw_explorer_warnings INTERFACE)
  add_library(rw_explorer_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  rw_explorer_set_project_warnings(
    rw_explorer_warnings
    ${rw_explorer_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(rw_explorer_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    rw_explorer_configure_linker(rw_explorer_options)
  endif()

  include(cmake/Sanitizers.cmake)
  rw_explorer_enable_sanitizers(
    rw_explorer_options
    ${rw_explorer_ENABLE_SANITIZER_ADDRESS}
    ${rw_explorer_ENABLE_SANITIZER_LEAK}
    ${rw_explorer_ENABLE_SANITIZER_UNDEFINED}
    ${rw_explorer_ENABLE_SANITIZER_THREAD}
    ${rw_explorer_ENABLE_SANITIZER_MEMORY})

  set_target_properties(rw_explorer_options PROPERTIES UNITY_BUILD ${rw_explorer_ENABLE_UNITY_BUILD})

  if(rw_explorer_ENABLE_PCH)
    target_precompile_headers(
      rw_explorer_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(rw_explorer_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    rw_explorer_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(rw_explorer_ENABLE_CLANG_TIDY)
    rw_explorer_enable_clang_tidy(rw_explorer_options ${rw_explorer_WARNINGS_AS_ERRORS})
  endif()

  if(rw_explorer_ENABLE_CPPCHECK)
    rw_explorer_enable_cppcheck(${rw_explorer_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(rw_explorer_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    rw_explorer_enable_coverage(rw_explorer_options)
  endif()

  if(rw_explorer_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(rw_explorer_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(rw_explorer_ENABLE_HARDENING AND NOT rw_explorer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR rw_explorer_ENABLE_SANITIZER_UNDEFINED
       OR rw_explorer_ENABLE_SANITIZER_ADDRESS
       OR rw_explorer_ENABLE_SANITIZER_THREAD
       OR rw_explorer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    rw_explorer_enable_hardening(rw_explorer_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
