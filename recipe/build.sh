#!/bin/bash
set -x

export CPPFLAGS="-I${PREFIX}/include ${CPPFLAGS}"
export LDFLAGS="-L${PREFIX}/lib -Wl,-rpath,$PREFIX/lib"
if [[ ${target_platform} =~ linux-* ]]; then
  LDFLAGS="${LDFLAGS} -Wl,--disable-new-dtags ${LDFLAGS}"
fi

cmake_options=(
  -DWITH_SSL=$PREFIX \
  -DWITH_JDBC:BOOL=ON \
  -DWITH_MYSQL=$PREFIX \
  -DWITH_BOOST=$PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH=$PREFIX \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
)

if [[ $target_platform == osx-arm64 ]] && [[ $CONDA_BUILD_CROSS_COMPILATION == 1 ]]; then
    # Build all intermediate codegen binaries for the build platform
    # xref: https://cmake.org/pipermail/cmake/2013-January/053252.html
    env -u CC -u CXX -u SDKROOT -u CONDA_BUILD_SYSROOT -u CMAKE_PREFIX_PATH \
        -u CXXFLAGS -u CPPFLAGS -u CFLAGS -u LDFLAGS -u MACOSX_DEPLOYMENT_TARGET \
        cmake -S. -Bbuild.codegen "${cmake_options[@]}" \
          -DCMAKE_C_COMPILER=$CC_FOR_BUILD \
          -DCMAKE_CXX_COMPILER=$CXX_FOR_BUILD
    cmake --build build.codegen/cdk/protocol/mysqlx/protobuf -- protoc -j${CPU_COUNT} VERBOSE=1
    cmake --build build.codegen -- save_linker_opts -j${CPU_COUNT} VERBOSE=1
    cmake_options+=(-DProtoc_CMD=$SRC_DIR/build.codegen/cdk/protocol/mysqlx/protobuf/runtime_output_directory/protoc)
    cmake_options+=(-DSave_Linker_Opts_CMD=$SRC_DIR/build.codegen/libutils/save_linker_opts)
fi

for choice in ON OFF
do
  cmake -S. \
    -Bbuild.$choice \
    -DBUILD_STATIC=$choice \
    "${cmake_options[@]}"
  cmake --build build.$choice -- -j${CPU_COUNT} VERBOSE=1
  cmake --build build.$choice -- install VERBOSE=1
done

mv ${PREFIX}/INFO_SRC ${PREFIX}/${PKG_NAME}_INFO_SRC
mv ${PREFIX}/INFO_BIN ${PREFIX}/${PKG_NAME}_INFO_BIN

mkdir -p $PREFIX/lib/cmake
cat <<EOF > $PREFIX/lib/cmake/FindMySQLConnectorCPP.cmake
# FindMySQLConnectorCPP
# --------
#
# Find the MySQLConnectorCPP library.
# Result Variables
# ^^^^^^^^^^^^^^^^
#
# This module defines the following variables:
#
# \`\`MySQLConnectorCPP_FOUND\`\`
#   MySQL-Connector-C++ installed
#
# \`\`MySQLConnectorCPP_INCLUDE_DIRS\`\`
#   MySQL-Connector-C++ include directories
#
# \`\`MySQLConnectorCPP_LIBRARIES\`\`
#   Link these to use MySQL-Connector-C++

# Look for the header file.
find_path(MySQLConnectorCPP_INCLUDE_DIR NAMES mysqlx/xdevapi.h)
mark_as_advanced(MySQLConnectorCPP_INCLUDE_DIR)

# Look for the library (sorted from most current/relevant entry to least).
find_library(MySQLConnectorCPP_LIBRARY NAMES mysqlcppconn8)
mark_as_advanced(MySQLConnectorCPP_LIBRARY)

# Look for the library (sorted from most current/relevant entry to least).
find_library(MySQLConnectorCPP_STATIC_LIBRARY NAMES mysqlcppconn8-static)
mark_as_advanced(MySQLConnectorCPP_STATIC_LIBRARY)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MySQLConnectorCPP
  REQUIRED_VARS MySQLConnectorCPP_LIBRARY MySQLConnectorCPP_STATIC_LIBRARY MySQLConnectorCPP_INCLUDE_DIR
  VERSION_VAR ${PKG_VERSION})

if(MySQLConnectorCPP_FOUND)
  set(MySQLConnectorCPP_LIBRARIES "")
  set(MySQLConnectorCPP_INCLUDE_DIRS \${MySQLConnectorCPP_INCLUDE_DIR})

  if(MySQLConnectorCPP_LIBRARY AND NOT TARGET MySQLConnectorCPP::cppconn)
    add_library(MySQLConnectorCPP::cppconn UNKNOWN IMPORTED)
    set_target_properties(MySQLConnectorCPP::cppconn PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "\${MySQLConnectorCPP_INCLUDE_DIRS}"
        IMPORTED_LOCATION "\${MySQLConnectorCPP_LIBRARY}")
    list(APPEND MySQLConnectorCPP_LIBRARIES MySQLConnectorCPP::cppconn)
  endif()
  if(MySQLConnectorCPP_STATIC_LIBRARY AND NOT TARGET MySQLConnectorCPP::cppconn::static)
    find_package(OpenSSL REQUIRED)
    find_package(Threads REQUIRED)
    add_library(MySQLConnectorCPP::cppconn::static UNKNOWN IMPORTED)
    set_target_properties(MySQLConnectorCPP::cppconn::static PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "\${MySQLConnectorCPP_INCLUDE_DIRS}"
        IMPORTED_LOCATION "\${MySQLConnectorCPP_STATIC_LIBRARY}")
    # For some reason Threads::Threads doesn't work correctly with
    # INTERFACE_LINK_LIBRARIES via set_target_properties(...)
    target_link_libraries(MySQLConnectorCPP::cppconn::static INTERFACE
        OpenSSL::Crypto;OpenSSL::SSL;Threads::Threads)
  endif()
endif()
EOF
