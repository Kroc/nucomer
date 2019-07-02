@ECHO OFF
CLS & TITLE Building Nucomer...
::==============================================================================
PUSHD %~dp0

SET ACME="bin\acme\acme.exe" ^
    --format cbm ^
    --color ^
     -v9 ^
     -I "src"

%ACME% ^
    --outfile   "build\nucomer.prg" ^
                "src\main.acme"

POPD