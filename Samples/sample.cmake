cmake_minimum_required(VERSION 3.25)
project(QuickLookExtendedPreview LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(QLE_SUPPORTED_FORMATS yaml tf csproj md)

add_executable(qle_preview main.cpp)
target_compile_definitions(qle_preview PRIVATE
  QLE_MAX_PREVIEW_BYTES=524288
  QLE_MAX_HIGHLIGHTED_BYTES=262144
)
