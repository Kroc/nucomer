@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

SET LUA="bin\lua\lua53.exe"
SET LUA_ARTICLE=%LUA% "scripts\article.lua"

SET ACME=bin\acme\acme.exe -I "src"
SET C1541="bin\vice\c1541.exe"

SET DASM=bin\dasm\dasm.exe

SET EXOMIZER="bin\exomizer\exomizer.exe"
SET EXO_RAW=raw -T4 -P-32 -M256 -c

TITLE Building Nucomer...
ECHO:

REM # clear the build folder
DEL /F /Q build\*.*  >NUL

REM # address of the bootstrap/fast-loader
SET NU_ADDR_BOOT=0400

REM # assemble BSOD64:
REM ============================================================================
REM # the same BSOD64 binary is used across all issues,
REM # so no need to do this as part of the per-issue build
ECHO:
ECHO BSOD64
ECHO ----------------------------------------
PUSHD src\bsod64

..\..\%ACME% -v1 ^
     --format cbm ^
     --report "..\..\build\bsod.src" ^
      -o "..\..\build\bsod64.prg" ^
          "bsod64.acme" 

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # and compress for fast-loading from disk

%EXOMIZER% %EXO_RAW% -q ^
     -o "build\bsod64.exo" ^
     -- "build\bsod64.prg",2

REM # assemble bootstrap:
REM ============================================================================
ECHO:
ECHO Bootstrap
ECHO ----------------------------------------
PUSHD src\boot

..\..\%DASM% ^
     prg_boot.dasm ^
     -DNU_ADDR_BOOT=$%NU_ADDR_BOOT% ^
     -o..\..\build\boot.prg ^
     -s..\..\build\boot.sym ^
     -l..\..\build\boot.src ^
     -v0 -p3

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # compress the bootstrap!
REM ----------------------------------------------------------------------------
%EXOMIZER% sfx 0x%NU_ADDR_BOOT% -t64 -n -B ^
     -T4 -M256 -c ^
     -s "lda #0 sta $d011" ^
     -o "build\boot.sfx" ^
     -- "build\boot.prg"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # loop through all issues...
REM ============================================================================
REM # begin with issue number zero
SET /A ISSUE=0
ECHO:

:next_issue
REM ----------------------------------------------------------------------------
REM # pad issue number to two digits;
REM # this is used in filenames & paths
SET "ISSUE_ID=00%ISSUE%"
REM # take the rightmost two digits
SET "ISSUE_ID=%ISSUE_ID:~-2%"
REM # combine this into a folder name
SET "ISSUE_DIR=issue#%ISSUE_ID%"
REM # and into a path, where the issues are stored
SET "ISSUE_PATH=issues\%ISSUE_DIR%\"
REM # does such an issue exist?
IF NOT EXIST "%ISSUE_PATH%" GOTO :end

:do_issue
REM ============================================================================
REM # build an individual issue
REM #
ECHO Issue #%ISSUE_ID%
ECHO ========================================

REM # process articles in the issue
%LUA% "scripts\issue.lua" %ISSUE%
IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

REM # Process SID songs
REM ============================================================================
REM # walk through the list of songs:
REM # (begin indexing from zero)
SET /A SID=0
FOR /F "eol=* delims=* tokens=*" %%A IN (build\i%ISSUE_ID%_sids.lst) DO (
     IF NOT [%%~A] == [] CALL :process_sid "%%~A"
)
ECHO ========================================

GOTO :assemble_outfit


:process_sid
REM ----------------------------------------------------------------------------
REM # generate output file name
SET "SID_NAME=%~n1"

REM # announce
SET "SID_TITLE=                                    "
SET "SID_TITLE=%~n1%SID_TITLE%"
SET "SID_TITLE=%SID_TITLE:~0,36%"
<NUL (SET /P "$=%SID_TITLE%")

REM # compress the SID tune...
REM # we skip the SID metadata header and the two-byte PRG address
%EXOMIZER% %EXO_RAW% -q ^
     -o "build\%SID_NAME%.exo" ^
     -- "build\%SID_NAME%.sid",126

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

ECHO [OK]
REM # next SID...
SET /A SID=SID+1

goto:eof

:assemble_outfit
REM # assemble the outfit
REM ============================================================================
<NUL (SET /P "$=Assemble Outfit...                  ")

REM # assemble fonts
REM ----------------------------------------------------------------------------
%ACME% -- "src\fonts\admiral64.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%EXOMIZER% %EXO_RAW% -q ^
     -o "build\admiral64.exo" ^
     -- "build\admiral64.prg",2

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the ASCII maps
REM ----------------------------------------------------------------------------
%ACME% -- "src\fonts\scr_nucomer.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% -- "src\fonts\scr_reverse.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%ACME% -- "src\fonts\scr_logo.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the logo splash screen
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\logo.src" ^
     --outfile "build\logo.prg" ^
          "src\logo\prg_logo.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # compress the logo
REM ----------------------------------------------------------------------------
%EXOMIZER% %EXO_RAW% -q ^
     -o "build\logo.exo" ^
     -- "build\logo.prg",2

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # assemble the main outfit
REM ----------------------------------------------------------------------------
%ACME% ^
     --format cbm ^
     --report "build\nucomer.src" ^
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

REM # pack the outfit into a single file
REM ----------------------------------------------------------------------------
<NUL (SET /P "$=Pack Outfit...                      ")

REM # compress the outfit

%EXOMIZER% %EXO_RAW% -q ^
     -o "build\nucomer.exo" ^
     -- "build\nucomer.prg",2

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

:end

ECHO: