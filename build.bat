@ECHO OFF
CLS & TITLE Building Nucomer...
CD %~dp0

SET LUA="bin\lua\lua53.exe"
SET LUA_ARTICLE=%LUA% "scripts\article.lua"

SET ACME=bin\acme\acme.exe -I "src"
SET C1541="bin\vice\c1541.exe"

SET DASM=bin\dasm\dasm.exe

SET EXOMIZER="bin\exomizer\exomizer.exe"

TITLE Building Nucomer...
ECHO:

REM # assemble BSOD64:
REM ============================================================================
REM # the same BSOD64 binary is used across all issues,
REM # so no need to do this as part of the per-issue build
ECHO:
ECHO BSOD64
ECHO ----------------------------------------
PUSHD src\bsod64

REM # assemble BSOD64 into its own folder as its a sub-project
REM #
..\..\%ACME% -v1 ^
     --format cbm ^
     --report "..\..\build\bsod.txt" ^
      -o "build\bsod64.prg" ^
          "bsod64.acme"

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # assemble bootstrap:
REM ============================================================================
ECHO:
ECHO Bootstrap
ECHO ----------------------------------------
PUSHD src\boot

..\..\%DASM% ^
     prg_boot.dasm ^
     -o..\..\build\boot.prg ^
     -s..\..\build\boot.sym ^
     -v0 -p3

IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%
POPD

REM # compress the bootstrap!
REM ----------------------------------------------------------------------------
%EXOMIZER% sfx 0x0400 -t64 -n -B ^
     -s "lda #0 sta $d011" ^
     -o "build\boot.exo.prg" ^
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

REM # clear the build folder
DEL /F /Q build\*.*  >NUL

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

REM # the first (0th) SID is used during booting
REM # so copy it to "bootsid.prg"

COPY /Y ^
     "build\i%ISSUE_ID%_s00_*.prg" /B ^
     "build\bootsid.prg"           /B  >NUL
IF ERRORLEVEL 1 EXIT /B %ERRORLEVEL%

GOTO :assemble_outfit

:process_sid
REM ----------------------------------------------------------------------------
REM # generate output file name
SET "SID_ID=00%SID%"
SET "SID_ID=%SID_ID:~-2%"
SET "SID_NAME=%~n1"

REM # announce
SET "SID_TITLE=                                    "
SET "SID_TITLE=%~n1%SID_TITLE%"
SET "SID_TITLE=%SID_TITLE:~0,36%"
<NUL (SET /P "$=%SID_TITLE%")

REM # assemble the relocated SID, sans-header
%ACME% -- "build\%SID_NAME%.acme"

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

REM # compress the SID program...
%EXOMIZER% raw -q ^
     -o "build\%SID_NAME%.exo" ^
     -- "build\%SID_NAME%.prg"

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

REM # compress the intro
REM ----------------------------------------------------------------------------

REM %EXOMIZER% sfx 0x0800 -t64 -n -q ^
REM      -o "build\intro.exo.prg" ^
REM      -- "build\intro.prg"
REM 
REM IF ERRORLEVEL 1 (
REM      ECHO FAIL
REM      EXIT /B %ERRORLEVEL%
REM )

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

REM # pack the outfit into a single file
REM ----------------------------------------------------------------------------
<NUL (SET /P "$=Pack Outfit...                      ")

REM # make a copy of the first SID song to include with the outfit
REM # program so that it doesn't need to be loaded separately
REM # (note that in this environment, we don't know the exact file-name)
COPY /Y ^
     "build\i%ISSUE_ID%_s00_*.prg"    /B ^
     "build\i%ISSUE_ID%_s00_menu.prg" /B  >NUL

IF ERRORLEVEL 1 (
     ECHO FAIL
     EXIT /B %ERRORLEVEL%
)

%EXOMIZER% sfx 0x8000 -t64 -n -q ^
     -o "build\nucomer.exo.prg" ^
     -- "build\i%ISSUE_ID%_s00_menu.prg" ^
        "build\nucomer.prg" ^
        "build\admiral64.prg" ^
        "src\bsod64\build\bsod64.prg"

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