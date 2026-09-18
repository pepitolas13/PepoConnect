# Builds ../rust with Cargo (through cargokit) and bundles pepo_native.dll
# next to the app.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "pepo_native")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust pepo_native "")

set(pepo_native_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
