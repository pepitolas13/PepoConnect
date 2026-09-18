# Builds ../rust with Cargo (through cargokit) and bundles libpepo_native.so
# in the app's lib/ folder.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "pepo_native")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust pepo_native "")

set(pepo_native_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
