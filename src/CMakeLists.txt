cmake_minimum_required(VERSION 3.14.0)
project(font_subset LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(HARFBUZZ_ROOT ../third_party/harfbuzz/)
include(../third_party/harfbuzz/sources.cmake)

add_executable(
  font-subset
  main.cc
  hb_wrappers.h
  ${harfbuzz_subset_sources}
)

target_include_directories(
  font-subset
  PRIVATE
  .
  ../third_party/harfbuzz/src/
)

target_compile_definitions(
  font-subset
  PRIVATE
  HAVE_OT
  HB_NO_MT
  HB_NO_VISIBILITY
)

if(MSVC)
  target_compile_options(
    font-subset
    PRIVATE
    -utf-8
    -Gy
    -Gw
    -GR-
    -wd4100
    -wd4127
    -wd4244
    -wd4267
    -wd4456
    -wd4457
    -wd4458
    -wd4459
    -wd4701
    -wd4702
    -wd4706
  )
  target_compile_definitions(
    font-subset
    PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
    WIN32_LEAN_AND_MEAN
  )
else()
  target_compile_options(
    font-subset
    PRIVATE
    -fno-rtti
    -Wno-missing-field-initializers
    -Wno-unused-variable
    -Wno-sign-compare
    -Wno-array-bounds
  )
  if(APPLE)
    target_link_options(font-subset PRIVATE -Wl,-dead_strip)
  else()
    target_compile_options(
      font-subset
      PRIVATE
      -ffunction-sections
      -fdata-sections
    )
    target_link_options(font-subset PRIVATE -Wl,--gc-sections -s)
  endif()
endif()

install(
  TARGETS font-subset
  RUNTIME DESTINATION .
)
