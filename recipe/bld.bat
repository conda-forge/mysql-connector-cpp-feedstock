for %%O in (ON OFF) DO ( 
   cmake -S. ^
     -Bbuild.%%O ^
     -GNinja ^
     -DBUILD_STATIC=%%O ^
     -DWITH_JDBC:BOOL=ON ^
     -DCMAKE_BUILD_TYPE=Release ^
     -DCMAKE_INSTALL_LIBDIR=lib ^
     -DWITH_SSL=%LIBRARY_PREFIX% ^
     -DWITH_BOOST=%LIBRARY_PREFIX% ^
     -DWITH_MYSQL=%LIBRARY_PREFIX% ^
     -DMYSQL_LIB_DIR=%LIBRARY_LIB% ^
     -DMYSQL_INCLUDE_DIR=%LIBRARY_INC%\mysql ^
     -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON ^
     -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
     -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
     -DMYSQL_EXTERNAL_DEPENDENCIES="zlib.lib;zstd.lib"
   if ERRORLEVEL 1 EXIT 1

   cmake --build build.%%O --target install
   REM cmake --build build.%%O --target install
   REM cmake --build build.%%O --config Release --target install
   if ERRORLEVEL 1 EXIT 1
)

move %LIBRARY_PREFIX%\INFO_SRC %LIBRARY_PREFIX%\%PKG_NAME%_INFO_SRC
move %LIBRARY_PREFIX%\INFO_BIN %LIBRARY_PREFIX%\%PKG_NAME%_INFO_BIN
