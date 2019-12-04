@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

SET LUA="bin\lua\lua53.exe"
SET LUA_ARTICLE=%LUA% "scripts\article.lua"

SET ACME=bin\acme\acme.exe -I "src"
SET EXOMIZER="bin\exomizer\exomizer.exe"
SET PUCRUNCH="bin\pucrunch\pucrunch.exe"
SET C1541="bin\vice\c1541.exe"

REM # assemble BSOD64 debugger
REM ============================================================================
ECHO:
ECHO BSOD64
ECHO ----------------------------------------
PUSHD src\bsod64

REM # assemble BSOD64 into its own folder as its a sub-project

..\..\%ACME% -v1 ^
     --format cbm ^
     --report "..\..\build/bsod.txt" ^
     -Wtype-mismatch ^
          "bsod64.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # convert the article text into C64 text codes
REM ============================================================================

%LUA% "scripts\issue.lua"
IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # assemble the outfit
REM ============================================================================
<NUL (SET /P "$=Assemble Outfit...                  ")

REM # assemble fonts
REM ----------------------------------------------------------------------------
%ACME% "src\fonts\admiral64.acme"
%ACME% "src\fonts\wax-lyrics.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the ASCII maps
REM ----------------------------------------------------------------------------
%ACME% "src\fonts\scr_nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% "src\fonts\scr_reverse.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% "src\fonts\scr_logo.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the disk bootstrap
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\boot.txt" ^
     --outfile "build\boot.prg" ^
          "src\prg_boot.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the intro
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\intro.txt" ^
     --outfile "build\intro.prg" ^
          "src\prg_intro.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the main outfit
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\nucomer.txt" ^
     --outfile "build\nucomer.prg" ^
          "src\prg_nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble articles
REM ----------------------------------------------------------------------------
REM # walk through the list of articles and assemble each
FOR /F "eol=* delims=* tokens=*" %%A IN (build\issue.lst) DO (
     REM # assemble the article into its binary
     %ACME% "%%A"
     REM # ok?
     IF ERRORLEVEL 1 (
          ECHO FAIL
          EXIT /B %ERRORLEVEL%
     )
)
ECHO [OK]

REM # exomize content:
REM ============================================================================
<NUL (SET /P "$=Exomize...                          ")

%EXOMIZER% mem -l $b000 -B -q ^
     -o "build\nucomer-exo.prg" ^
     -- "build\nucomer.prg"

%PUCRUNCH% -f -c0 ^
     "build\nucomer.prg" ^
     "build\nucomer-pu.prg" ^
     2>NUL

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]

REM # package disks
REM ============================================================================
<NUL (SET /P "$=Create D64...                       ")

%C1541% < "build\c1541.txt"  1>NUL

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)
ECHO [OK]
