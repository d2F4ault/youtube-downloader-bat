@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

rem ============================================================================
rem YouTube Downloader - standalone, safety-first Windows batch application
rem Version 3.0.0 (2026-08-17)
rem UTF-8 (no BOM), CRLF line endings required.
rem ============================================================================

title YouTube Downloader - Safety First

set "APP_NAME=YouTube Downloader"
set "APP_VERSION=3.0.0"
set "PINNED_YTDLP_VERSION=2026.07.04"

rem All application state is relative to this batch file.  PATH is never changed.
set "ROOT=%~dp0"
set "BIN=%ROOT%bin"
set "DOWNLOAD_ROOT=%ROOT%Downloads"
set "TEMP_ROOT=%ROOT%temp"
set "LOG_ROOT=%ROOT%logs"
set "LOCK_ROOT=%ROOT%locks"
set "SETTINGS_FILE=%ROOT%settings.ini"
set "ADVANCED_FILE=%ROOT%advanced-yt-dlp.conf"
set "URLS_FILE=%ROOT%urls.txt"
set "ARCHIVE_AUDIO=%ROOT%archive-audio.txt"
set "ARCHIVE_VIDEO=%ROOT%archive-video.txt"

set "YTDLP=%BIN%\yt-dlp.exe"
set "FFMPEG=%BIN%\ffmpeg.exe"
set "FFPROBE=%BIN%\ffprobe.exe"
set "ARIA2C=%BIN%\aria2c.exe"
set "ACTIVE_ROOT=%BIN%\.active"
set "TOOL_LOCK=%BIN%\.toolset.lock"
set "SETTINGS_LOCK=%LOCK_ROOT%\settings.lock"

rem Immutable, pinned upstream releases.  First run trusts this batch file's
rem embedded release identities and SHA-256 values; it never follows /latest.
set "YTDLP_URL=https://github.com/yt-dlp/yt-dlp/releases/download/2026.07.04/yt-dlp.exe"
set "YTDLP_SIZE=18226085"
set "YTDLP_SHA256=52fe3c26dcf71fbdc85b528589020bb0b8e383155cfa81b64dd447bbe35e24b8"
set "FFMPEG_URL=https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2026-08-14-17-32/ffmpeg-N-126137-gc9a585da56-win64-gpl.zip"
set "FFMPEG_SIZE=170629673"
set "FFMPEG_SHA256=8b6e300477b2fa2d026a3fd4302ef7bbb2318adf4a4164c6962d882e8be814af"
set "ARIA2_URL=https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
set "ARIA2_SIZE=2475379"
set "ARIA2_SHA256=67d015301eef0b612191212d564c5bb0a14b5b9c4796b76454276a4d28d9b288"

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "CURL_EXE=%SystemRoot%\System32\curl.exe"
set "CERTUTIL_EXE=%SystemRoot%\System32\certutil.exe"
set "TIMEOUT_EXE=%SystemRoot%\System32\timeout.exe"

set "TOOLS_VALID=0"
set "YTDLP_VERSION=not installed"
set "FFMPEG_VERSION=not installed"
set "ARIA2_VERSION=not installed"
set "SESSION_DIR="
set "SESSION_ID="
set "JOB_SEQ=0"
set "LAST_URL="
set "START_URL=%~1"
set "PROBE_CAP=2000"

call :CHECK_ARCHITECTURE
if errorlevel 1 set "ARCH_SUPPORTED=0"
if not defined ARCH_SUPPORTED set "ARCH_SUPPORTED=1"

call :INITIALIZE_FOLDERS
if errorlevel 1 goto FATAL_INIT

call :CREATE_SESSION_DIR
if errorlevel 1 goto FATAL_INIT

call :LOAD_SETTINGS
call :DETECT_SYNC_ROOT
call :WARN_LONG_ROOT

if "!ARCH_SUPPORTED!"=="1" (
    call :ENSURE_TOOLS 0
    if errorlevel 1 (
        set "TOOLS_VALID=0"
        echo.
        echo Tool setup is not ready.  The menu remains available so you can retry
        echo Repair tools, read About, or exit safely.
        echo.
        pause
    )
)

if defined START_URL (
    if "!TOOLS_VALID!"=="1" (
        set "URL=!START_URL!"
        set "LAST_URL=!URL!"
        goto URL_MENU
    )
)
goto MAIN_MENU


rem ============================================================================
rem Main menus
rem ============================================================================

:MAIN_MENU
cls
echo ==============================================================================
echo                    %APP_NAME% %APP_VERSION%
echo ==============================================================================
echo Local tools: yt-dlp !YTDLP_VERSION! ^| FFmpeg !FFMPEG_VERSION! ^| aria2 !ARIA2_VERSION!
if "!TOOLS_VALID!"=="0" echo STATUS: Tools are not validated.  Use Repair tools before downloading.
if "!SYNC_ROOT!"=="1" echo WARNING: Script state is under a synced folder.  See About before large jobs.
echo.
echo   [D] Download from one URL
echo   [Q] Process urls.txt batch file safely
echo   [R] Repair / revalidate local tools
echo   [U] Reinstall verified pinned toolset
echo   [T] YouTube extraction self-test
echo   [S] Settings and safety toggles
echo   [O] Open Downloads folder
echo   [B] Open local tools ^(bin^) folder
echo   [A] About / diagnostics
echo   [E] Exit
echo.
choice /C DQRUTSOBAE /N /M "Choose an option"
if errorlevel 10 goto EXIT_PROGRAM
if errorlevel 9 goto ABOUT_MENU
if errorlevel 8 goto OPEN_BIN
if errorlevel 7 goto OPEN_DOWNLOADS
if errorlevel 6 goto SETTINGS_MENU
if errorlevel 5 goto SELF_TEST
if errorlevel 4 goto FORCE_TOOLSET
if errorlevel 3 goto REPAIR_TOOLS
if errorlevel 2 goto BATCH_URLS
if errorlevel 1 goto PROMPT_URL
goto MAIN_MENU

:PROMPT_URL
if "!TOOLS_VALID!"=="0" (
    call :TOOLS_REQUIRED_MESSAGE
    goto MAIN_MENU
)
cls
echo ==============================================================================
echo Paste one YouTube video, playlist, or channel URL.
echo Leave it blank to return.  A pasted URL is stored only in this running window.
echo ==============================================================================
echo.
set "URL="
set /P "URL=URL: "
if not defined URL goto MAIN_MENU
call :VALIDATE_URL_SHAPE
if errorlevel 2 goto PROMPT_URL
set "LAST_URL=!URL!"
goto URL_MENU

:URL_MENU
if "!TOOLS_VALID!"=="0" (
    call :TOOLS_REQUIRED_MESSAGE
    goto MAIN_MENU
)
cls
echo ==============================================================================
echo URL selected
echo ==============================================================================
echo !URL!
echo.
call :SHOW_SETTING_SUMMARY
echo.
echo   [A] DEFAULT AUDIO - Best compatibility M4A ^(recommended^)
echo   [V] DEFAULT VIDEO - Strict compatible MP4, up to 1080p
echo   [C] Custom audio
echo   [F] Custom video
echo   [L] List available formats
echo   [S] Settings and safety toggles
echo   [B] Back
echo.
choice /C AVCFLSB /N /M "Choose an option"
if errorlevel 7 goto MAIN_MENU
if errorlevel 6 goto SETTINGS_MENU
if errorlevel 5 goto LIST_FORMATS
if errorlevel 4 goto CUSTOM_VIDEO
if errorlevel 3 goto CUSTOM_AUDIO
if errorlevel 2 (
    set "PROFILE_KIND=VIDEO"
    set "VIDEO_MODE=MP4"
    set "VIDEO_HEIGHT=1080"
    set "VIDEO_LABEL=Strict compatible MP4, up to 1080p (H.264/AAC preferred)"
    call :PREPARE_AND_RUN 0
    goto URL_MENU
)
if errorlevel 1 (
    set "PROFILE_KIND=AUDIO"
    set "AUDIO_MODE=M4A"
    set "AUDIO_QUALITY=0"
    set "AUDIO_LABEL=Best compatibility M4A, quality 0"
    call :PREPARE_AND_RUN 0
    goto URL_MENU
)
goto URL_MENU

:CUSTOM_AUDIO
cls
echo ==============================================================================
echo CUSTOM AUDIO
echo ==============================================================================
echo   [M] Best compatibility M4A
echo   [P] MP3
echo   [O] Opus
echo   [F] FLAC
echo   [W] WAV
echo   [K] Best available audio - keep original codec/container
echo   [B] Back
echo.
echo FLAC and WAV cannot improve YouTube's original audio quality; they only make
echo larger files after conversion.  WAV does not support embedded cover artwork.
echo.
set "AUDIO_MODE="
choice /C MPOFWKB /N /M "Audio format"
if errorlevel 7 goto URL_MENU
if errorlevel 6 (
    set "PROFILE_KIND=AUDIO"
    set "AUDIO_MODE=KEEP"
    set "AUDIO_QUALITY="
    set "AUDIO_LABEL=Best available audio, keep original codec/container"
    call :PREPARE_AND_RUN 0
    goto URL_MENU
)
set "AUDIO_CHOICE=!ERRORLEVEL!"
if "!AUDIO_CHOICE!"=="5" set "AUDIO_MODE=WAV"
if "!AUDIO_CHOICE!"=="4" set "AUDIO_MODE=FLAC"
if "!AUDIO_CHOICE!"=="3" set "AUDIO_MODE=OPUS"
if "!AUDIO_CHOICE!"=="2" set "AUDIO_MODE=MP3"
if "!AUDIO_CHOICE!"=="1" set "AUDIO_MODE=M4A"
if not defined AUDIO_MODE goto CUSTOM_AUDIO
set "PROFILE_KIND=AUDIO"
set "AUDIO_LABEL=!AUDIO_MODE! conversion"
goto CUSTOM_AUDIO_QUALITY

:CUSTOM_AUDIO_QUALITY
cls
echo ==============================================================================
echo AUDIO QUALITY
echo ==============================================================================
echo 0 is highest quality / largest.  9 is smallest / lowest quality.
echo For lossless FLAC/WAV this does not create source quality that YouTube lacks.
echo.
choice /C 0123456789B /N /M "Choose quality 0-9, or B to go back"
if errorlevel 11 goto CUSTOM_AUDIO
set "QUALITY_CHOICE=!ERRORLEVEL!"
if "!QUALITY_CHOICE!"=="10" set "AUDIO_QUALITY=9"
if "!QUALITY_CHOICE!"=="9" set "AUDIO_QUALITY=8"
if "!QUALITY_CHOICE!"=="8" set "AUDIO_QUALITY=7"
if "!QUALITY_CHOICE!"=="7" set "AUDIO_QUALITY=6"
if "!QUALITY_CHOICE!"=="6" set "AUDIO_QUALITY=5"
if "!QUALITY_CHOICE!"=="5" set "AUDIO_QUALITY=4"
if "!QUALITY_CHOICE!"=="4" set "AUDIO_QUALITY=3"
if "!QUALITY_CHOICE!"=="3" set "AUDIO_QUALITY=2"
if "!QUALITY_CHOICE!"=="2" set "AUDIO_QUALITY=1"
if "!QUALITY_CHOICE!"=="1" set "AUDIO_QUALITY=0"
set "AUDIO_LABEL=!AUDIO_MODE! conversion, quality !AUDIO_QUALITY!"
call :PREPARE_AND_RUN 0
goto URL_MENU

:CUSTOM_VIDEO
cls
echo ==============================================================================
echo CUSTOM VIDEO - maximum height
echo ==============================================================================
echo   [A] Up to 360p       [B] Up to 480p       [C] Up to 720p
echo   [D] Up to 1080p      [E] Up to 1440p      [F] Up to 2160p ^(4K^)
echo   [G] Best available   [X] Back
echo.
set "VIDEO_HEIGHT="
set "VIDEO_MODE="
choice /C ABCDEFGX /N /M "Maximum resolution"
if errorlevel 8 goto URL_MENU
set "VIDEO_HEIGHT_CHOICE=!ERRORLEVEL!"
if "!VIDEO_HEIGHT_CHOICE!"=="7" set "VIDEO_HEIGHT=BEST"
if "!VIDEO_HEIGHT_CHOICE!"=="6" set "VIDEO_HEIGHT=2160"
if "!VIDEO_HEIGHT_CHOICE!"=="5" set "VIDEO_HEIGHT=1440"
if "!VIDEO_HEIGHT_CHOICE!"=="4" set "VIDEO_HEIGHT=1080"
if "!VIDEO_HEIGHT_CHOICE!"=="3" set "VIDEO_HEIGHT=720"
if "!VIDEO_HEIGHT_CHOICE!"=="2" set "VIDEO_HEIGHT=480"
if "!VIDEO_HEIGHT_CHOICE!"=="1" set "VIDEO_HEIGHT=360"
if not defined VIDEO_HEIGHT goto CUSTOM_VIDEO
if "!KEEP_ORIGINAL!"=="1" goto CUSTOM_VIDEO_KEEP_ORIGINAL
goto CUSTOM_VIDEO_CONTAINER

:CUSTOM_VIDEO_KEEP_ORIGINAL
cls
echo ==============================================================================
echo KEEP ORIGINAL VIDEO FORMAT IS ENABLED
echo ==============================================================================
echo The container choice is deliberately disabled.  The downloader will select a
echo single combined stream at or below !VIDEO_HEIGHT! and will not merge, remux,
echo or re-encode it.  Its original container will be retained.
echo.
choice /C YN /N /M "Use original-format video mode"
if errorlevel 2 goto CUSTOM_VIDEO
set "PROFILE_KIND=VIDEO"
set "VIDEO_MODE=KEEP"
set "VIDEO_LABEL=Original container, maximum !VIDEO_HEIGHT!p"
call :PREPARE_AND_RUN 0
goto URL_MENU

:CUSTOM_VIDEO_CONTAINER
cls
echo ==============================================================================
echo CUSTOM VIDEO - final container
echo ==============================================================================
echo   [M] MP4 - strict compatibility; H.264 + AAC are preferred
echo   [K] MKV - flexible container; may use best available codecs
echo   [W] WebM - only WebM-compatible streams
echo   [B] Back
echo.
choice /C MKWB /N /M "Container"
if errorlevel 4 goto CUSTOM_VIDEO
set "VIDEO_CONTAINER_CHOICE=!ERRORLEVEL!"
if "!VIDEO_CONTAINER_CHOICE!"=="3" set "VIDEO_MODE=WEBM"
if "!VIDEO_CONTAINER_CHOICE!"=="2" set "VIDEO_MODE=MKV"
if "!VIDEO_CONTAINER_CHOICE!"=="1" set "VIDEO_MODE=MP4"
if not defined VIDEO_MODE goto CUSTOM_VIDEO_CONTAINER
set "PROFILE_KIND=VIDEO"
set "VIDEO_LABEL=!VIDEO_MODE! container, maximum !VIDEO_HEIGHT!p"
call :PREPARE_AND_RUN 0
goto URL_MENU

:LIST_FORMATS
call :CREATE_JOB_DIR
if errorlevel 1 (
    call :JOB_DIR_ERROR
    goto URL_MENU
)
call :WRITE_URL_FILE
if errorlevel 1 (
    call :CLEAN_CURRENT_JOB
    echo ERROR: Could not create the isolated URL input file.
    pause
    goto URL_MENU
)
cls
echo ==============================================================================
echo AVAILABLE FORMATS
echo ==============================================================================
echo This is a read-only query.  It never downloads media and always uses --no-playlist.
echo.
call :RUN_LIST_FORMATS
set "LIST_RC=!ERRORLEVEL!"
echo.
if not "!LIST_RC!"=="0" (
    echo ERROR: yt-dlp could not list formats ^(error !LIST_RC!^).
    echo Details are in: !JOB_PROBE_LOG!
) else (
    echo Format listing completed.
)
call :CLEAN_CURRENT_JOB
pause
goto URL_MENU

:BATCH_URLS
if "!TOOLS_VALID!"=="0" (
    call :TOOLS_REQUIRED_MESSAGE
    goto MAIN_MENU
)
if not exist "%URLS_FILE%" (
    >"%URLS_FILE%" (
        echo # Put one YouTube URL per line.  Lines beginning with # are ignored.
        echo # Batch mode is still safe: every playlist/channel URL is separately gated.
    )
    echo Created "%URLS_FILE%".
    echo Add URLs, save the file, then choose this menu item again.
    start "" notepad.exe "%URLS_FILE%"
    pause
    goto MAIN_MENU
)
cls
echo ==============================================================================
echo URLS.TXT BATCH MODE
echo ==============================================================================
echo Each non-comment line will be processed one at a time using safe defaults.
echo Every detected playlist or channel is separately stopped for confirmation.
echo Existing archives are respected unless Ignore archive is enabled in Settings.
echo.
echo   [A] Default compatibility M4A for every URL
echo   [V] Default strict MP4 up to 1080p for every URL
echo   [B] Back
echo.
choice /C AVB /N /M "Batch profile"
if errorlevel 3 goto MAIN_MENU
set "BATCH_CHOICE=!ERRORLEVEL!"
if "!BATCH_CHOICE!"=="2" (
    set "BATCH_KIND=VIDEO"
    set "VIDEO_MODE=MP4"
    set "VIDEO_HEIGHT=1080"
    set "VIDEO_LABEL=Batch strict compatible MP4, up to 1080p"
)
if "!BATCH_CHOICE!"=="1" (
    set "BATCH_KIND=AUDIO"
    set "AUDIO_MODE=M4A"
    set "AUDIO_QUALITY=0"
    set "AUDIO_LABEL=Batch best compatibility M4A, quality 0"
)
echo.
choice /C YN /N /M "Begin safe sequential batch processing"
if errorlevel 2 goto MAIN_MENU
set /A BATCH_TOTAL=0
set /A BATCH_OK=0
set /A BATCH_SKIPPED=0
set /A BATCH_FAILED=0
for /F "usebackq delims=" %%U in ("%URLS_FILE%") do (
    set "URL=%%U"
    if defined URL (
        if not "!URL:~0,1!"=="#" (
            set /A BATCH_TOTAL+=1
            call :VALIDATE_BATCH_URL
            if errorlevel 1 (
                echo Skipping malformed or non-YouTube urls.txt line !BATCH_TOTAL!.
                set /A BATCH_SKIPPED+=1
            ) else (
                set "PROFILE_KIND=!BATCH_KIND!"
                call :PREPARE_AND_RUN 1
                if "!JOB_OUTCOME!"=="OK" set /A BATCH_OK+=1
                if "!JOB_OUTCOME!"=="SKIPPED" set /A BATCH_SKIPPED+=1
                if "!JOB_OUTCOME!"=="FAILED" set /A BATCH_FAILED+=1
            )
        )
    )
)
echo.
echo Batch summary: !BATCH_TOTAL! URL(s), !BATCH_OK! completed, !BATCH_SKIPPED! skipped, !BATCH_FAILED! failed.
pause
goto MAIN_MENU


rem ============================================================================
rem Settings and information
rem ============================================================================

:SETTINGS_MENU
cls
echo ==============================================================================
echo SETTINGS AND SAFETY TOGGLES
echo ==============================================================================
call :SHOW_SETTING_SUMMARY
echo.
echo   [P] Playlist/channel mode and item limit
echo   [I] Toggle ignore archive for the next downloads
echo   [S] SponsorBlock categories
echo   [U] Subtitles and language preference
echo   [C] Cookies from browser
echo   [O] Custom output root
echo   [K] Toggle original-container video mode
echo   [N] Network speed / rate limit
echo   [D] Diagnostic verbose logging
echo   [Y] Compatibility profile ^(advanced workaround^)
echo   [M] Toggle actual media report after download
echo   [X] Advanced yt-dlp options file
echo   [R] Restore safe defaults
echo   [B] Back
echo.
choice /C PISUCOKNDYMXRB /N /M "Choose a setting"
if errorlevel 14 goto MAIN_MENU
if errorlevel 13 goto RESTORE_DEFAULTS
if errorlevel 12 goto OPEN_ADVANCED_FILE
if errorlevel 11 goto TOGGLE_REPORT_MEDIA
if errorlevel 10 goto COMPATIBILITY_SETTINGS
if errorlevel 9 goto TOGGLE_DIAGNOSTICS
if errorlevel 8 goto NETWORK_SETTINGS
if errorlevel 7 goto TOGGLE_KEEP_ORIGINAL
if errorlevel 6 goto OUTPUT_SETTINGS
if errorlevel 5 goto COOKIE_SETTINGS
if errorlevel 4 goto SUBTITLE_SETTINGS
if errorlevel 3 goto SPONSOR_SETTINGS
if errorlevel 2 goto TOGGLE_IGNORE_ARCHIVE
if errorlevel 1 goto PLAYLIST_SETTINGS
goto SETTINGS_MENU

:PLAYLIST_SETTINGS
cls
echo ==============================================================================
echo PLAYLIST / CHANNEL SAFETY
echo ==============================================================================
if "!MULTI_MODE!"=="1" (
    echo Multi-item mode is ON.  Every collection is still probed and confirmed.
) else (
    echo Multi-item mode is OFF.  All actual downloads use --no-playlist.
)
if defined PLAYLIST_LIMIT (echo Current limit: first !PLAYLIST_LIMIT! items.) else echo Current limit: UNRESTRICTED ^(requires a second confirmation every time^).
echo.
echo   [T] Toggle multi-item mode
echo   [L] Set a finite item limit
echo   [A] Remove limit ^(unrestricted; double confirmation required^)
echo   [B] Back
echo.
choice /C TLAB /N /M "Choose"
if errorlevel 4 goto SETTINGS_MENU
if errorlevel 3 (
    set "PLAYLIST_LIMIT="
    call :SAVE_SETTINGS
    echo Unlimited collections require a deliberate double confirmation at run time.
    pause
    goto PLAYLIST_SETTINGS
)
if errorlevel 2 goto SET_PLAYLIST_LIMIT
if errorlevel 1 (
    if "!MULTI_MODE!"=="1" (set "MULTI_MODE=0") else (set "MULTI_MODE=1")
    call :SAVE_SETTINGS
    goto PLAYLIST_SETTINGS
)
goto PLAYLIST_SETTINGS

:SET_PLAYLIST_LIMIT
cls
echo Enter a positive whole number such as 10 or 50.  Blank cancels.
set "LIMIT_INPUT="
set /P "LIMIT_INPUT=Item limit: "
if not defined LIMIT_INPUT goto PLAYLIST_SETTINGS
echo(!LIMIT_INPUT!|%SystemRoot%\System32\findstr.exe /R /X "[1-9][0-9]*" >nul
if errorlevel 1 (
    echo ERROR: Enter a positive whole number only.
    pause
    goto SET_PLAYLIST_LIMIT
)
set "PLAYLIST_LIMIT=!LIMIT_INPUT!"
set "MULTI_MODE=1"
call :SAVE_SETTINGS
echo Limit saved: first !PLAYLIST_LIMIT! item(s).
pause
goto PLAYLIST_SETTINGS

:TOGGLE_IGNORE_ARCHIVE
if "!IGNORE_ARCHIVE!"=="1" (set "IGNORE_ARCHIVE=0") else (set "IGNORE_ARCHIVE=1")
call :SAVE_SETTINGS
echo.
if "!IGNORE_ARCHIVE!"=="1" (
    echo Archive bypass is ON.  Existing archive entries will be ignored for future jobs.
    echo --no-overwrites remains enabled, so existing output files are never overwritten.
) else (
    echo Archive bypass is OFF.  Profile-specific archives will be used normally.
)
pause
goto SETTINGS_MENU

:SPONSOR_SETTINGS
cls
echo ==============================================================================
echo SPONSORBLOCK CATEGORIES
echo ==============================================================================
echo Current: !SPONSOR_CATS!
echo.
echo   [1] sponsor,intro,outro ^(safe default^)
echo   [2] sponsor,selfpromo,interaction,intro,outro,preview,filler,music_offtopic
echo   [3] Turn SponsorBlock removal off
echo   [4] Enter a custom comma-separated category list
echo   [B] Back
echo.
choice /C 1234B /N /M "Choose"
if errorlevel 5 goto SETTINGS_MENU
if errorlevel 4 goto SPONSOR_CUSTOM
set "SPONSOR_CHOICE=!ERRORLEVEL!"
if "!SPONSOR_CHOICE!"=="3" set "SPONSOR_CATS="
if "!SPONSOR_CHOICE!"=="2" set "SPONSOR_CATS=sponsor,selfpromo,interaction,intro,outro,preview,filler,music_offtopic"
if "!SPONSOR_CHOICE!"=="1" set "SPONSOR_CATS=sponsor,intro,outro"
call :SAVE_SETTINGS
goto SETTINGS_MENU

:SPONSOR_CUSTOM
set "SPONSOR_INPUT="
set /P "SPONSOR_INPUT=Categories ^(letters, commas, underscores only^): "
if not defined SPONSOR_INPUT goto SPONSOR_SETTINGS
echo(!SPONSOR_INPUT!|%SystemRoot%\System32\findstr.exe /R /X "[A-Za-z_,][A-Za-z_,]*" >nul
if errorlevel 1 (
    echo ERROR: Only letters, commas, and underscores are accepted.
    pause
    goto SPONSOR_CUSTOM
)
set "SPONSOR_CATS=!SPONSOR_INPUT!"
call :SAVE_SETTINGS
goto SETTINGS_MENU

:SUBTITLE_SETTINGS
cls
echo ==============================================================================
echo SUBTITLES
echo ==============================================================================
if "!SUBTITLES!"=="1" (echo Subtitles are ON; languages: !SUB_LANGS!) else echo Subtitles are OFF.
echo When downloading video, manual and auto-generated subtitles are embedded when
echo the selected container supports them.  Audio jobs write subtitle sidecars only.
echo.
echo   [T] Toggle subtitles
echo   [L] Set language preference ^(example: en.*,en or en,hi^)
echo   [B] Back
echo.
choice /C TLB /N /M "Choose"
if errorlevel 3 goto SETTINGS_MENU
if errorlevel 2 goto SET_SUBTITLE_LANGUAGE
if errorlevel 1 (
    if "!SUBTITLES!"=="1" (set "SUBTITLES=0") else (set "SUBTITLES=1")
    call :SAVE_SETTINGS
    goto SUBTITLE_SETTINGS
)
goto SUBTITLE_SETTINGS

:SET_SUBTITLE_LANGUAGE
set "SUB_INPUT="
set /P "SUB_INPUT=Language list: "
if not defined SUB_INPUT goto SUBTITLE_SETTINGS
echo(!SUB_INPUT!|%SystemRoot%\System32\findstr.exe /R /X "[A-Za-z0-9,._*][A-Za-z0-9,._*-]*" >nul
if errorlevel 1 (
    echo ERROR: Use only letters, digits, comma, dot, underscore, hyphen, or *.
    pause
    goto SET_SUBTITLE_LANGUAGE
)
set "SUB_LANGS=!SUB_INPUT!"
call :SAVE_SETTINGS
goto SUBTITLE_SETTINGS

:COOKIE_SETTINGS
cls
echo ==============================================================================
echo COOKIES FROM BROWSER - PRIVACY WARNING
echo ==============================================================================
echo Cookies can expose your signed-in YouTube session to this local downloader.
echo Use this only when necessary.  Close the selected browser first so its cookie
echo database is readable.  No cookies are copied into this script's settings file.
echo.
if defined COOKIE_BROWSER (echo Current browser: !COOKIE_BROWSER!) else echo Current browser: OFF
echo.
echo   [C] Chrome      [E] Microsoft Edge      [F] Firefox
echo   [N] None / turn off cookies            [B] Back
echo.
choice /C CEFNB /N /M "Browser"
if errorlevel 5 goto SETTINGS_MENU
set "COOKIE_CHOICE=!ERRORLEVEL!"
if "!COOKIE_CHOICE!"=="4" set "COOKIE_BROWSER="
if "!COOKIE_CHOICE!"=="3" set "COOKIE_BROWSER=firefox"
if "!COOKIE_CHOICE!"=="2" set "COOKIE_BROWSER=edge"
if "!COOKIE_CHOICE!"=="1" set "COOKIE_BROWSER=chrome"
call :SAVE_SETTINGS
goto SETTINGS_MENU

:OUTPUT_SETTINGS
cls
echo ==============================================================================
echo CUSTOM OUTPUT ROOT
echo ==============================================================================
if defined OUTPUT_ROOT (echo Current root: !OUTPUT_ROOT!) else echo Current root: !DOWNLOAD_ROOT!
echo Audio and Video subfolders are always preserved beneath the chosen root.
echo A relative path is resolved below this batch file's folder.  Blank restores default.
echo.
set "OUTPUT_INPUT="
set "NEW_OUTPUT_ROOT="
set /P "OUTPUT_INPUT=Output root: "
if not defined OUTPUT_INPUT (
    set "OUTPUT_ROOT="
    call :SAVE_SETTINGS
    goto SETTINGS_MENU
)
set "OUTPUT_INPUT=!OUTPUT_INPUT:"=!"
set "OUTPUT_INPUT=!OUTPUT_INPUT:/=\!"
if "!OUTPUT_INPUT:~1,1!"==":" (
    set "NEW_OUTPUT_ROOT=!OUTPUT_INPUT!"
) else (
    if "!OUTPUT_INPUT:~0,2!"=="\\" (
        set "NEW_OUTPUT_ROOT=!OUTPUT_INPUT!"
    ) else (
        set "NEW_OUTPUT_ROOT=%ROOT%!OUTPUT_INPUT!"
    )
)
if not exist "!NEW_OUTPUT_ROOT!\" mkdir "!NEW_OUTPUT_ROOT!" >nul 2>&1
if not exist "!NEW_OUTPUT_ROOT!\" (
    echo ERROR: The requested output root could not be created or accessed.
    pause
    goto OUTPUT_SETTINGS
)
set "OUTPUT_ROOT=!NEW_OUTPUT_ROOT!"
call :DETECT_SYNC_OUTPUT
call :WARN_LONG_OUTPUT
call :SAVE_SETTINGS
goto SETTINGS_MENU

:TOGGLE_KEEP_ORIGINAL
if "!KEEP_ORIGINAL!"=="1" (
    set "KEEP_ORIGINAL=0"
    echo Normal container selection is now enabled.
) else (
    set "KEEP_ORIGINAL=1"
    echo Original-container video mode is now enabled.  Container selection is disabled
    echo and a combined stream at or below the selected height is used without remuxing.
)
call :SAVE_SETTINGS
pause
goto SETTINGS_MENU

:NETWORK_SETTINGS
cls
echo ==============================================================================
echo NETWORK AND PERFORMANCE
echo ==============================================================================
echo Concurrent fragments: !FRAGMENT_COUNT! ^(sane default: 4^)
if "!DIRECT_ACCEL!"=="1" (echo Direct HTTP acceleration with local aria2c: ON) else echo Direct HTTP acceleration with local aria2c: OFF
if defined BANDWIDTH_LIMIT (echo Bandwidth cap: !BANDWIDTH_LIMIT!) else echo Bandwidth cap: OFF
echo DASH and HLS remain native yt-dlp downloads; aria2c is only configured for direct HTTP/HTTPS.
echo.
echo   [F] Set fragment count ^(4, 6, or 8^)
echo   [A] Toggle direct HTTP aria2c acceleration
echo   [L] Set bandwidth limit ^(examples: 2M, 800K, 0 for off^)
echo   [B] Back
echo.
choice /C FALB /N /M "Choose"
if errorlevel 4 goto SETTINGS_MENU
if errorlevel 3 goto SET_BANDWIDTH
if errorlevel 2 (
    if "!DIRECT_ACCEL!"=="1" (set "DIRECT_ACCEL=0") else (set "DIRECT_ACCEL=1")
    call :SAVE_SETTINGS
    goto NETWORK_SETTINGS
)
if errorlevel 1 goto SET_FRAGMENT_COUNT
goto NETWORK_SETTINGS

:SET_FRAGMENT_COUNT
choice /C 468B /N /M "Fragments: 4, 6, 8, or B to go back"
if errorlevel 4 goto NETWORK_SETTINGS
set "FRAGMENT_CHOICE=!ERRORLEVEL!"
if "!FRAGMENT_CHOICE!"=="3" set "FRAGMENT_COUNT=8"
if "!FRAGMENT_CHOICE!"=="2" set "FRAGMENT_COUNT=6"
if "!FRAGMENT_CHOICE!"=="1" set "FRAGMENT_COUNT=4"
call :SAVE_SETTINGS
goto NETWORK_SETTINGS

:SET_BANDWIDTH
set "RATE_INPUT="
set /P "RATE_INPUT=Limit ^(e.g. 2M, 800K, 0 to disable^): "
if not defined RATE_INPUT goto NETWORK_SETTINGS
if "!RATE_INPUT!"=="0" (
    set "BANDWIDTH_LIMIT="
    call :SAVE_SETTINGS
    goto NETWORK_SETTINGS
)
echo(!RATE_INPUT!|%SystemRoot%\System32\findstr.exe /I /R /X "[1-9][0-9]*[KMG]" >nul
if errorlevel 1 (
    echo ERROR: Use a positive number followed by K, M, or G ^(for example 2M^).
    pause
    goto SET_BANDWIDTH
)
set "BANDWIDTH_LIMIT=!RATE_INPUT!"
call :SAVE_SETTINGS
goto NETWORK_SETTINGS

:TOGGLE_DIAGNOSTICS
if "!DIAGNOSTIC!"=="1" (set "DIAGNOSTIC=0") else (set "DIAGNOSTIC=1")
call :SAVE_SETTINGS
if "!DIAGNOSTIC!"=="1" (
    echo Diagnostic mode is ON.  Each job writes a timestamped verbose log in "%LOG_ROOT%".
    echo To preserve an accurate log, progress is shown when the job completes instead of live.
) else (
    echo Diagnostic mode is OFF.  Downloads show normal live progress.
)
pause
goto SETTINGS_MENU

:COMPATIBILITY_SETTINGS
cls
echo ==============================================================================
echo YOUTUBE COMPATIBILITY PROFILE
echo ==============================================================================
echo Default lets the current yt-dlp release choose its own recommended YouTube clients.
echo The alternatives are advanced troubleshooting workarounds only; they are never the
echo default and can become obsolete as YouTube changes.
echo.
echo   [D] Default automatic client selection
echo   [A] android compatibility profile
echo   [W] web compatibility profile
echo   [B] Back
echo.
choice /C DAWB /N /M "Profile"
if errorlevel 4 goto SETTINGS_MENU
set "COMPAT_CHOICE=!ERRORLEVEL!"
if "!COMPAT_CHOICE!"=="3" set "COMPAT_PROFILE=web"
if "!COMPAT_CHOICE!"=="2" set "COMPAT_PROFILE=android"
if "!COMPAT_CHOICE!"=="1" set "COMPAT_PROFILE=default"
call :SAVE_SETTINGS
goto SETTINGS_MENU

:TOGGLE_REPORT_MEDIA
if "!REPORT_MEDIA!"=="1" (
    set "REPORT_MEDIA=0"
    echo Final ffprobe media reports are now OFF.
) else (
    set "REPORT_MEDIA=1"
    echo Final ffprobe media reports are now ON.
)
call :SAVE_SETTINGS
pause
goto SETTINGS_MENU

:OPEN_ADVANCED_FILE
if not exist "%ADVANCED_FILE%" (
    >"%ADVANCED_FILE%" (
        echo # One yt-dlp option per line.  This file is appended only after validation.
        echo # Lines starting with # are comments.  Unsafe options are rejected.
        echo # Do not add --exec, --output, --format, --paths, --batch-file,
        echo # --download-archive, --config-locations, or --ffmpeg-location.
        echo # Example safe option: --geo-bypass
    )
)
start "" notepad.exe "%ADVANCED_FILE%"
echo Edit and save the advanced options file, then return here.
pause
goto SETTINGS_MENU

:RESTORE_DEFAULTS
call :SET_SAFE_DEFAULTS
call :SAVE_SETTINGS
echo Safe defaults restored: --no-playlist, M4A/MP4 presets, SponsorBlock default,
echo native DASH/HLS, four fragments, no archive bypass, and no browser cookies.
pause
goto SETTINGS_MENU

:ABOUT_MENU
cls
echo ==============================================================================
echo ABOUT AND DIAGNOSTICS
echo ==============================================================================
echo %APP_NAME% %APP_VERSION%
echo.
echo Tool source policy: immutable pinned GitHub releases, exact byte-size and SHA-256
echo verification, then basic executable validation.  First run trusts this batch file
echo and its embedded release identities; the script never follows a mutable /latest URL.
echo No PowerShell ExecutionPolicy bypass is used.
echo.
echo Script root: %ROOT%
echo Temporary session: !SESSION_DIR!
echo yt-dlp: !YTDLP_VERSION!
echo FFmpeg: !FFMPEG_VERSION!
echo aria2c: !ARIA2_VERSION!
echo.
if "!SYNC_ROOT!"=="1" (
    echo SYNC WARNING: The script root appears to be under OneDrive or another synced root.
    echo Concurrent devices cannot share local locks safely.  Keep this tool in a local,
    echo non-synced folder for large jobs, tool updates, archives, and active downloads.
) else (
    echo Sync check: script root does not appear to be under the configured OneDrive root.
)
echo.
echo   [L] View active/stale lock information
echo   [C] Confirmed cleanup of a stale lock or abandoned temp job
echo   [B] Back
echo.
choice /C LCB /N /M "Choose"
if errorlevel 3 goto MAIN_MENU
if errorlevel 2 goto CLEANUP_MENU
if errorlevel 1 goto SHOW_LOCK_INFO
goto ABOUT_MENU

:SHOW_LOCK_INFO
cls
echo ==============================================================================
echo LOCK AND SESSION INFORMATION
echo ==============================================================================
if exist "%TOOL_LOCK%\" (
    echo Toolset lock exists: %TOOL_LOCK%
    if exist "%TOOL_LOCK%\owner.txt" type "%TOOL_LOCK%\owner.txt"
) else echo No toolset lock exists.
echo.
for %%A in ("%LOCK_ROOT%\archive-audio.lock" "%LOCK_ROOT%\archive-video.lock" "%SETTINGS_LOCK%") do (
    if exist "%%~fA\" echo Lock exists: %%~fA
)
echo.
if exist "%ACTIVE_ROOT%\" (
    echo Active job markers:
    dir /B "%ACTIVE_ROOT%\*.marker" 2>nul
) else echo No active job marker directory exists.
echo.
echo Isolated session directories are intentionally not auto-deleted after a crash or
echo Ctrl-C; automatic deletion could destroy an active second instance's work.
pause
goto ABOUT_MENU

:CLEANUP_MENU
cls
echo ==============================================================================
echo CONFIRMED STALE CLEANUP
echo ==============================================================================
echo Pure batch cannot reliably trap a forced Ctrl-C or a crash.  Only remove a lock
echo or session after confirming that no other YouTube_Downloader.bat instance is running.
echo.
echo   [L] Remove one named stale lock
echo   [J] Remove one named abandoned session directory
echo   [M] Remove one named stale active-job marker
echo   [B] Back
echo.
choice /C LJMB /N /M "Choose"
if errorlevel 4 goto ABOUT_MENU
if errorlevel 3 goto CLEANUP_MARKER
if errorlevel 2 goto CLEANUP_SESSION
if errorlevel 1 goto CLEANUP_LOCK
goto CLEANUP_MENU

:CLEANUP_LOCK
set "STALE_LOCK="
set "STALE_LOCK_PATH="
set /P "STALE_LOCK=Lock name ^(archive-audio.lock, archive-video.lock, settings.lock, toolset.lock^): "
if not defined STALE_LOCK goto CLEANUP_MENU
if /I "!STALE_LOCK!"=="archive-audio.lock" set "STALE_LOCK_PATH=%LOCK_ROOT%\archive-audio.lock"
if /I "!STALE_LOCK!"=="archive-video.lock" set "STALE_LOCK_PATH=%LOCK_ROOT%\archive-video.lock"
if /I "!STALE_LOCK!"=="settings.lock" set "STALE_LOCK_PATH=%SETTINGS_LOCK%"
if /I "!STALE_LOCK!"=="toolset.lock" set "STALE_LOCK_PATH=%TOOL_LOCK%"
if not defined STALE_LOCK_PATH (
    echo ERROR: That is not a recognized lock name.
    pause
    goto CLEANUP_MENU
)
if not exist "!STALE_LOCK_PATH!\" (
    echo That lock does not exist.
    pause
    goto CLEANUP_MENU
)
choice /C YN /N /M "Confirm no other instance is running and remove this lock"
if errorlevel 2 goto CLEANUP_MENU
rmdir /S /Q "!STALE_LOCK_PATH!" >nul 2>&1
if exist "!STALE_LOCK_PATH!\" (
    echo ERROR: The lock could not be removed.  It may still be active or protected.
) else (
    echo Stale lock removed.
)
pause
goto CLEANUP_MENU

:CLEANUP_MARKER
if not exist "%ACTIVE_ROOT%\" (
    echo No active-marker directory exists.
    pause
    goto CLEANUP_MENU
)
echo Active markers:
dir /B "%ACTIVE_ROOT%\*.marker" 2>nul
echo.
set "STALE_MARKER="
set /P "STALE_MARKER=Exact stale marker filename: "
if not defined STALE_MARKER goto CLEANUP_MENU
echo(!STALE_MARKER!|%SystemRoot%\System32\findstr.exe /R /X "[0-9A-Za-z-][0-9A-Za-z-]*\.marker" >nul
if errorlevel 1 (
    echo ERROR: Invalid marker name.
    pause
    goto CLEANUP_MENU
)
set "STALE_MARKER_PATH=%ACTIVE_ROOT%\!STALE_MARKER!"
if not exist "!STALE_MARKER_PATH!" (
    echo That marker does not exist.
    pause
    goto CLEANUP_MENU
)
choice /C YN /N /M "Confirm no active download owns this marker and remove it"
if errorlevel 2 goto CLEANUP_MENU
del /Q "!STALE_MARKER_PATH!" >nul 2>&1
if exist "!STALE_MARKER_PATH!" (echo ERROR: Could not remove the marker.) else echo Stale marker removed.
pause
goto CLEANUP_MENU

:CLEANUP_SESSION
echo Session directories are listed below.  Only names starting with session- are accepted.
dir /B /AD "%TEMP_ROOT%\session-*" 2>nul
echo.
set "STALE_SESSION="
set /P "STALE_SESSION=Exact abandoned session folder name: "
if not defined STALE_SESSION goto CLEANUP_MENU
echo(!STALE_SESSION!|%SystemRoot%\System32\findstr.exe /R /X "session-[0-9A-Za-z-][0-9A-Za-z-]*" >nul
if errorlevel 1 (
    echo ERROR: Invalid session folder name.
    pause
    goto CLEANUP_MENU
)
set "STALE_SESSION_PATH=%TEMP_ROOT%\!STALE_SESSION!"
if not exist "!STALE_SESSION_PATH!\" (
    echo That session directory does not exist.
    pause
    goto CLEANUP_MENU
)
choice /C YN /N /M "Confirm no active job uses it and remove this directory"
if errorlevel 2 goto CLEANUP_MENU
rmdir /S /Q "!STALE_SESSION_PATH!" >nul 2>&1
if exist "!STALE_SESSION_PATH!\" (echo ERROR: Could not remove the session directory.) else echo Abandoned session directory removed.
pause
goto CLEANUP_MENU


rem ============================================================================
rem Download flow: every invocation has a private job directory and config file
rem ============================================================================

:PREPARE_AND_RUN
set "JOB_OUTCOME=FAILED"
set "BATCH_RUN=%~1"
call :CREATE_JOB_DIR
if errorlevel 1 (
    call :JOB_DIR_ERROR
    exit /B 1
)
call :WRITE_URL_FILE
if errorlevel 1 goto JOB_SETUP_FAILURE
call :RESOLVE_JOB_OUTPUT
if errorlevel 1 goto JOB_SETUP_FAILURE
call :SET_ACTIVE_ARCHIVE
call :PROBE_URL
if errorlevel 1 (
    echo.
    echo ERROR: yt-dlp could not inspect this URL.  No media was downloaded.
    echo Probe diagnostics: !JOB_PROBE_LOG!
    call :CLEAN_CURRENT_JOB
    if "!BATCH_RUN!"=="0" pause
    exit /B 1
)
call :CONFIRM_COLLECTION_SAFETY
if errorlevel 1 (
    set "JOB_OUTCOME=SKIPPED"
    call :CLEAN_CURRENT_JOB
    exit /B 0
)
call :DISK_PREFLIGHT
call :BUILD_JOB_CONFIG
if errorlevel 1 goto JOB_SETUP_FAILURE
if "!BATCH_RUN!"=="0" (
    call :SHOW_JOB_CONFIRMATION
    if errorlevel 1 (
        set "JOB_OUTCOME=SKIPPED"
        call :CLEAN_CURRENT_JOB
        exit /B 0
    )
)
rem The profile lock is retained even when archive bypass is on.  It protects the
rem same title/id output namespace and prevents two ignored-archive jobs racing.
call :ACQUIRE_ARCHIVE_LOCK
if errorlevel 1 (
    set "JOB_OUTCOME=SKIPPED"
    call :CLEAN_CURRENT_JOB
    exit /B 1
)
call :CREATE_ACTIVE_MARKER
if errorlevel 1 (
    call :RELEASE_ARCHIVE_LOCK
    echo ERROR: Could not reserve the local toolset for this job.
    call :CLEAN_CURRENT_JOB
    if "!BATCH_RUN!"=="0" pause
    exit /B 1
)
call :RUN_JOB
set "RUN_RC=!ERRORLEVEL!"
call :REMOVE_ACTIVE_MARKER
call :RELEASE_ARCHIVE_LOCK
if "!RUN_RC!"=="0" (
    set "JOB_OUTCOME=OK"
    call :REPORT_COMPLETED_MEDIA
) else (
    set "JOB_OUTCOME=FAILED"
    echo.
    echo ERROR: yt-dlp returned error code !RUN_RC!.
    if "!DIAGNOSTIC!"=="1" (
        echo Detailed log: !JOB_LOG!
    ) else (
        echo Common causes: unavailable video, network interruption, sign-in requirement,
        echo browser-cookie access, or a YouTube change requiring a future pinned tool update.
    )
)
call :CLEAN_CURRENT_JOB
if "!BATCH_RUN!"=="0" pause
exit /B !RUN_RC!

:JOB_SETUP_FAILURE
echo.
echo ERROR: The isolated job configuration could not be prepared.  Nothing was downloaded.
call :CLEAN_CURRENT_JOB
if "!BATCH_RUN!"=="0" pause
exit /B 1

:CREATE_JOB_DIR
set /A JOB_SEQ+=1
set "JOB_DIR=%SESSION_DIR%\job-!JOB_SEQ!"
mkdir "!JOB_DIR!" >nul 2>&1
if not exist "!JOB_DIR!\" exit /B 1
set "JOB_CONFIG=!JOB_DIR!\yt-dlp-run.conf"
set "JOB_URL_FILE=!JOB_DIR!\url.txt"
set "JOB_ITEMS=!JOB_DIR!\items.txt"
set "JOB_PROBE_LOG=!JOB_DIR!\probe.log"
set "JOB_RESULT=!JOB_DIR!\completed-paths.txt"
set "JOB_MARKER=%ACTIVE_ROOT%\!SESSION_ID!-!JOB_SEQ!.marker"
set "JOB_LOG="
exit /B 0

:WRITE_URL_FILE
>"!JOB_URL_FILE!" echo(!URL!
if not exist "!JOB_URL_FILE!" exit /B 1
exit /B 0

:RESOLVE_JOB_OUTPUT
if defined OUTPUT_ROOT (
    set "JOB_OUTPUT_ROOT=!OUTPUT_ROOT!"
) else (
    set "JOB_OUTPUT_ROOT=%DOWNLOAD_ROOT%"
)
if /I "!PROFILE_KIND!"=="AUDIO" (
    set "JOB_OUTPUT_DIR=!JOB_OUTPUT_ROOT!\Audio"
) else (
    set "JOB_OUTPUT_DIR=!JOB_OUTPUT_ROOT!\Video"
)
if not exist "!JOB_OUTPUT_DIR!\" mkdir "!JOB_OUTPUT_DIR!" >nul 2>&1
if not exist "!JOB_OUTPUT_DIR!\" exit /B 1
set "JOB_OUTPUT_TEMPLATE=!JOB_OUTPUT_DIR!\%%(channel,uploader^|Unknown)s\%%(title)s [%%(id)s].%%(ext)s"
exit /B 0

:SET_ACTIVE_ARCHIVE
if /I "!PROFILE_KIND!"=="AUDIO" (
    set "ACTIVE_ARCHIVE=%ARCHIVE_AUDIO%"
    set "ARCHIVE_LOCK=%LOCK_ROOT%\archive-audio.lock"
) else (
    set "ACTIVE_ARCHIVE=%ARCHIVE_VIDEO%"
    set "ARCHIVE_LOCK=%LOCK_ROOT%\archive-video.lock"
)
exit /B 0

:PROBE_URL
set "PROBE_COUNT=0"
set "ARCHIVED_COUNT=0"
set "SOURCE_TYPE=Unknown"
if exist "!JOB_ITEMS!" del /Q "!JOB_ITEMS!" >nul 2>&1
if exist "!JOB_PROBE_LOG!" del /Q "!JOB_PROBE_LOG!" >nul 2>&1
echo Probing URL safely ^(up to !PROBE_CAP! entries; no media download^) ...
call :RUN_PROBE_COMMAND
set "PROBE_RC=!ERRORLEVEL!"
if not "!PROBE_RC!"=="0" exit /B 1
if not exist "!JOB_ITEMS!" exit /B 1
for /F "usebackq delims=" %%I in ("!JOB_ITEMS!") do (
    if not "%%I"=="" (
        set /A PROBE_COUNT+=1
        if "!IGNORE_ARCHIVE!"=="0" if exist "!ACTIVE_ARCHIVE!" (
            %SystemRoot%\System32\findstr.exe /X /C:"youtube %%I" "!ACTIVE_ARCHIVE!" >nul
            if not errorlevel 1 set /A ARCHIVED_COUNT+=1
        )
    )
)
if !PROBE_COUNT! LEQ 0 exit /B 1
call :CLASSIFY_SOURCE
exit /B 0

:RUN_PROBE_COMMAND
if defined COOKIE_BROWSER (
    if /I not "!COMPAT_PROFILE!"=="default" (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --cookies-from-browser "!COOKIE_BROWSER!" --extractor-args "youtube:player_client=!COMPAT_PROFILE!" --no-warnings --skip-download --flat-playlist --yes-playlist --playlist-end !PROBE_CAP! --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
    ) else (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --cookies-from-browser "!COOKIE_BROWSER!" --no-warnings --skip-download --flat-playlist --yes-playlist --playlist-end !PROBE_CAP! --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
    )
) else (
    if /I not "!COMPAT_PROFILE!"=="default" (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --extractor-args "youtube:player_client=!COMPAT_PROFILE!" --no-warnings --skip-download --flat-playlist --yes-playlist --playlist-end !PROBE_CAP! --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
    ) else (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --no-warnings --skip-download --flat-playlist --yes-playlist --playlist-end !PROBE_CAP! --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
    )
)
exit /B !ERRORLEVEL!

:CLASSIFY_SOURCE
if !PROBE_COUNT! EQU 1 (
    set "SOURCE_TYPE=Single video"
    exit /B 0
)
set "SOURCE_TYPE=Multi-item collection"
echo(!URL!|%SystemRoot%\System32\findstr.exe /I /C:"list=" >nul
if not errorlevel 1 set "SOURCE_TYPE=Playlist"
echo(!URL!|%SystemRoot%\System32\findstr.exe /I /C:"/channel/" /C:"/@" /C:"/c/" /C:"/user/" >nul
if not errorlevel 1 set "SOURCE_TYPE=Channel or creator feed"
if !PROBE_COUNT! GEQ !PROBE_CAP! set "SOURCE_TYPE=!SOURCE_TYPE! (count capped at !PROBE_CAP!+)"
exit /B 0

:CONFIRM_COLLECTION_SAFETY
cls
echo ==============================================================================
echo PREFLIGHT SUMMARY
echo ==============================================================================
echo Detected source: !SOURCE_TYPE!
echo Probe count: !PROBE_COUNT!
if !PROBE_COUNT! GEQ !PROBE_CAP! echo NOTE: The probe intentionally stops at !PROBE_CAP! items; actual count may be higher.
if "!IGNORE_ARCHIVE!"=="0" (echo Already in this !PROFILE_KIND! archive: !ARCHIVED_COUNT!) else echo Archive: ignored for this run by your setting.
echo Profile: !PROFILE_KIND!
if /I "!PROFILE_KIND!"=="AUDIO" echo Format: !AUDIO_LABEL!
if /I "!PROFILE_KIND!"=="VIDEO" echo Format: !VIDEO_LABEL!
echo Output folder: !JOB_OUTPUT_DIR!
echo File pattern: title [video-id].extension, organized by channel
echo.
if !PROBE_COUNT! LEQ 1 exit /B 0

echo SAFETY STOP: This URL resolves to multiple items.
if "!MULTI_MODE!"=="0" (
    echo Multi-item mode is OFF, so the normal download would use --no-playlist.
    echo.
    choice /C EB /N /M "Enable multi-item mode with a safe limit, or go Back"
    if errorlevel 2 exit /B 1
    set "MULTI_MODE=1"
    if not defined PLAYLIST_LIMIT set "PLAYLIST_LIMIT=10"
    call :SAVE_SETTINGS
    echo Multi-item mode enabled.  Limit is first !PLAYLIST_LIMIT! item(s).
    choice /C YN /N /M "Confirm download of this limited collection"
    if errorlevel 2 exit /B 1
    exit /B 0
)
if defined PLAYLIST_LIMIT (
    echo Current safety limit: first !PLAYLIST_LIMIT! item(s).
    choice /C YN /N /M "Confirm this limited multi-item download"
    if errorlevel 2 exit /B 1
    exit /B 0
)
echo UNRESTRICTED MODE: every item found by yt-dlp can be downloaded.
echo This is intentionally blocked until you make two explicit confirmations.
choice /C YN /N /M "First confirmation: allow unrestricted collection mode"
if errorlevel 2 exit /B 1
set "ALL_CONFIRM="
set /P "ALL_CONFIRM=Type DOWNLOAD ALL exactly to continue: "
if /I not "!ALL_CONFIRM!"=="DOWNLOAD ALL" (
    echo Unrestricted collection cancelled; exact confirmation was not entered.
    pause
    exit /B 1
)
echo Unrestricted collection confirmed for this job only.
exit /B 0

:DISK_PREFLIGHT
set "DISK_FREE_GB="
if not exist "%PS_EXE%" (
    echo Disk check: PowerShell unavailable; free-space amount could not be queried.
    exit /B 0
)
set "YTDL_DISK_PATH=!JOB_OUTPUT_DIR!"
for /F "usebackq delims=" %%G in (`"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$p=$env:YTDL_DISK_PATH; try { $r=[IO.Path]::GetPathRoot($p); $d=New-Object IO.DriveInfo($r); [math]::Floor($d.AvailableFreeSpace / 1GB) } catch { exit 1 }" 2^>nul`) do if not defined DISK_FREE_GB set "DISK_FREE_GB=%%G"
if defined DISK_FREE_GB (
    echo Disk preflight: approximately !DISK_FREE_GB! GB free on the output volume.
    if !DISK_FREE_GB! LSS 5 echo WARNING: Less than 5 GB free.  Video playlists can need substantially more space.
) else (
    echo Disk check: free space could not be determined.  Confirm the output volume has room.
)
exit /B 0

:SHOW_JOB_CONFIRMATION
echo.
echo ==============================================================================
echo READY TO START
echo ==============================================================================
echo The exact command uses the local executable and a private response/config file.
echo It is not shown in full to avoid overwhelming this safety screen.
echo.
echo "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --config-locations "!JOB_CONFIG!" --batch-file "!JOB_URL_FILE!"
echo.
echo Press V to view the generated configuration, Y to start, or N to cancel.
choice /C VYN /N /M "Choose"
if errorlevel 3 exit /B 1
if errorlevel 2 exit /B 0
if errorlevel 1 (
    cls
    echo ==============================================================================
    echo PRIVATE JOB CONFIGURATION: !JOB_CONFIG!
    echo ==============================================================================
    type "!JOB_CONFIG!"
    echo ==============================================================================
    choice /C YN /N /M "Start with this configuration"
    if errorlevel 2 exit /B 1
    exit /B 0
)
exit /B 1

:BUILD_JOB_CONFIG
if exist "!JOB_CONFIG!" del /Q "!JOB_CONFIG!" >nul 2>&1
>"!JOB_CONFIG!" (
    echo --ffmpeg-location
    echo "%BIN%"
    echo --windows-filenames
    echo --trim-filenames
    echo !TRIM_LENGTH!
    echo --no-overwrites
    echo --no-write-info-json
    echo --no-keep-video
    echo --continue
    echo --retries
    echo 10
    echo --fragment-retries
    echo 10
    echo --file-access-retries
    echo 3
    echo --concurrent-fragments
    echo !FRAGMENT_COUNT!
    echo --output
    echo "!JOB_OUTPUT_TEMPLATE!"
    echo --embed-metadata
    echo --embed-chapters
    echo --parse-metadata
    echo "%%(uploader^|)s:%%(meta_artist)s"
    echo --print-to-file
    echo "after_move:filepath" "!JOB_RESULT!"
)
if errorlevel 1 exit /B 1
if not exist "!JOB_CONFIG!" exit /B 1
if "!MULTI_MODE!"=="1" (
    >>"!JOB_CONFIG!" echo --yes-playlist
    if defined PLAYLIST_LIMIT (
        >>"!JOB_CONFIG!" echo --playlist-end
        >>"!JOB_CONFIG!" echo !PLAYLIST_LIMIT!
    )
) else (
    >>"!JOB_CONFIG!" echo --no-playlist
)
if "!IGNORE_ARCHIVE!"=="0" (
    >>"!JOB_CONFIG!" echo --download-archive
    >>"!JOB_CONFIG!" echo "!ACTIVE_ARCHIVE!"
)
if defined SPONSOR_CATS (
    >>"!JOB_CONFIG!" echo --sponsorblock-remove
    >>"!JOB_CONFIG!" echo !SPONSOR_CATS!
)
if "!SUBTITLES!"=="1" (
    >>"!JOB_CONFIG!" echo --write-subs
    >>"!JOB_CONFIG!" echo --write-auto-subs
    >>"!JOB_CONFIG!" echo --sub-langs
    >>"!JOB_CONFIG!" echo !SUB_LANGS!
    if /I "!PROFILE_KIND!"=="VIDEO" >>"!JOB_CONFIG!" echo --embed-subs
)
if defined COOKIE_BROWSER (
    >>"!JOB_CONFIG!" echo --cookies-from-browser
    >>"!JOB_CONFIG!" echo !COOKIE_BROWSER!
)
if /I not "!COMPAT_PROFILE!"=="default" (
    >>"!JOB_CONFIG!" echo --extractor-args
    >>"!JOB_CONFIG!" echo "youtube:player_client=!COMPAT_PROFILE!"
)
if defined BANDWIDTH_LIMIT (
    >>"!JOB_CONFIG!" echo --limit-rate
    >>"!JOB_CONFIG!" echo !BANDWIDTH_LIMIT!
)
if "!DIRECT_ACCEL!"=="1" (
    >>"!JOB_CONFIG!" echo --downloader
    >>"!JOB_CONFIG!" echo "dash,m3u8:native"
    >>"!JOB_CONFIG!" echo --downloader
    >>"!JOB_CONFIG!" echo "http,https:!ARIA2C!"
    >>"!JOB_CONFIG!" echo --downloader-args
    >>"!JOB_CONFIG!" echo "aria2c:-x!FRAGMENT_COUNT! -s!FRAGMENT_COUNT! -k1M --file-allocation=none"
)
if /I "!PROFILE_KIND!"=="AUDIO" (
    call :APPEND_AUDIO_OPTIONS
) else (
    call :APPEND_VIDEO_OPTIONS
)
if errorlevel 1 exit /B 1
call :APPEND_ADVANCED_OPTIONS
if errorlevel 1 exit /B 1
exit /B 0

:APPEND_AUDIO_OPTIONS
>>"!JOB_CONFIG!" echo --format
>>"!JOB_CONFIG!" echo "bestaudio[acodec!=none]/bestaudio"
if /I "!AUDIO_MODE!"=="KEEP" (
    rem Pure bestaudio only; no extract-audio and no video selector/fallback exists.
    >>"!JOB_CONFIG!" echo --embed-thumbnail
    >>"!JOB_CONFIG!" echo --convert-thumbnails
    >>"!JOB_CONFIG!" echo jpg
    exit /B 0
)
>>"!JOB_CONFIG!" echo --extract-audio
>>"!JOB_CONFIG!" echo --audio-format
>>"!JOB_CONFIG!" echo !AUDIO_MODE!
>>"!JOB_CONFIG!" echo --audio-quality
>>"!JOB_CONFIG!" echo !AUDIO_QUALITY!
if /I "!AUDIO_MODE!"=="WAV" (
    rem WAV has no reliable embedded-artwork container.  Metadata/chapters remain requested.
    exit /B 0
)
>>"!JOB_CONFIG!" echo --embed-thumbnail
>>"!JOB_CONFIG!" echo --convert-thumbnails
>>"!JOB_CONFIG!" echo jpg
exit /B 0

:APPEND_VIDEO_OPTIONS
if /I "!VIDEO_MODE!"=="KEEP" (
    >>"!JOB_CONFIG!" echo --format
    if /I "!VIDEO_HEIGHT!"=="BEST" (
        >>"!JOB_CONFIG!" echo "b[acodec!=none][vcodec!=none]/best[acodec!=none][vcodec!=none]"
    ) else (
        >>"!JOB_CONFIG!" echo "b[height^<=!VIDEO_HEIGHT!][acodec!=none][vcodec!=none]/best[height^<=!VIDEO_HEIGHT!][acodec!=none][vcodec!=none]"
    )
    >>"!JOB_CONFIG!" echo --embed-thumbnail
    >>"!JOB_CONFIG!" echo --convert-thumbnails
    >>"!JOB_CONFIG!" echo jpg
    exit /B 0
)
if /I "!VIDEO_MODE!"=="MP4" (
    >>"!JOB_CONFIG!" echo --format
    if /I "!VIDEO_HEIGHT!"=="BEST" (
        >>"!JOB_CONFIG!" echo "bv*[ext=mp4][vcodec*=avc]+ba[ext=m4a][acodec*=mp4a]/b[ext=mp4][vcodec*=avc][acodec*=mp4a]"
    ) else (
        >>"!JOB_CONFIG!" echo "bv*[height^<=!VIDEO_HEIGHT!][ext=mp4][vcodec*=avc]+ba[ext=m4a][acodec*=mp4a]/b[height^<=!VIDEO_HEIGHT!][ext=mp4][vcodec*=avc][acodec*=mp4a]"
    )
    >>"!JOB_CONFIG!" echo --merge-output-format
    >>"!JOB_CONFIG!" echo mp4
)
if /I "!VIDEO_MODE!"=="MKV" (
    >>"!JOB_CONFIG!" echo --format
    if /I "!VIDEO_HEIGHT!"=="BEST" (
        >>"!JOB_CONFIG!" echo "bv*+ba/b[acodec!=none][vcodec!=none]"
    ) else (
        >>"!JOB_CONFIG!" echo "bv*[height^<=!VIDEO_HEIGHT!]+ba/b[height^<=!VIDEO_HEIGHT!][acodec!=none][vcodec!=none]"
    )
    >>"!JOB_CONFIG!" echo --merge-output-format
    >>"!JOB_CONFIG!" echo mkv
)
if /I "!VIDEO_MODE!"=="WEBM" (
    >>"!JOB_CONFIG!" echo --format
    if /I "!VIDEO_HEIGHT!"=="BEST" (
        >>"!JOB_CONFIG!" echo "bv*[ext=webm]+ba[ext=webm]/b[ext=webm][acodec!=none][vcodec!=none]"
    ) else (
        >>"!JOB_CONFIG!" echo "bv*[height^<=!VIDEO_HEIGHT!][ext=webm]+ba[ext=webm]/b[height^<=!VIDEO_HEIGHT!][ext=webm][acodec!=none][vcodec!=none]"
    )
    >>"!JOB_CONFIG!" echo --merge-output-format
    >>"!JOB_CONFIG!" echo webm
)
>>"!JOB_CONFIG!" echo --embed-thumbnail
>>"!JOB_CONFIG!" echo --convert-thumbnails
>>"!JOB_CONFIG!" echo jpg
exit /B 0

:APPEND_ADVANCED_OPTIONS
if not exist "%ADVANCED_FILE%" exit /B 0
set "BAD_ADVANCED="
for /F "usebackq delims=" %%L in ("%ADVANCED_FILE%") do (
    set "ADV_LINE=%%L"
    if defined ADV_LINE (
        if not "!ADV_LINE:~0,1!"=="#" (
            call :VALIDATE_ADVANCED_LINE
            if errorlevel 1 set "BAD_ADVANCED=1"
            if not errorlevel 1 >>"!JOB_CONFIG!" echo(!ADV_LINE!
        )
    )
)
if defined BAD_ADVANCED (
    echo ERROR: advanced-yt-dlp.conf contains a rejected or malformed option.
    echo Unsafe options cannot override output paths, archives, format selection, config,
    echo batch inputs, ffmpeg location, or execute external commands.
    exit /B 1
)
exit /B 0

:VALIDATE_ADVANCED_LINE
if not "!ADV_LINE:~0,1!"=="-" exit /B 1
echo(!ADV_LINE!|%SystemRoot%\System32\findstr.exe /I /C:"--exec" /C:"--output" /C:"--paths" /C:"--format" /C:"--download-archive" /C:"--config-locations" /C:"--ignore-config" /C:"--batch-file" /C:"--ffmpeg-location" /C:"--use-postprocessor" >nul
if not errorlevel 1 exit /B 1
exit /B 0

:RUN_JOB
if "!DIAGNOSTIC!"=="1" (
    call :GET_TIMESTAMP
    set "JOB_LOG=%LOG_ROOT%\yt-dlp-!STAMP!-!SESSION_ID!-!JOB_SEQ!.log"
    echo.
    echo Diagnostic mode: running yt-dlp with --verbose.  Live progress is captured in:
    echo !JOB_LOG!
    "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --config-locations "!JOB_CONFIG!" --batch-file "!JOB_URL_FILE!" --verbose >"!JOB_LOG!" 2>&1
    set "RUN_RC=!ERRORLEVEL!"
    echo.
    type "!JOB_LOG!"
    exit /B !RUN_RC!
)
echo.
echo Starting yt-dlp.  Live progress messages follow.
echo.
"%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --config-locations "!JOB_CONFIG!" --batch-file "!JOB_URL_FILE!"
exit /B !ERRORLEVEL!

:REPORT_COMPLETED_MEDIA
if "!REPORT_MEDIA!"=="0" exit /B 0
if not exist "!JOB_RESULT!" (
    echo yt-dlp completed, but did not report a final output path.
    exit /B 0
)
echo.
echo Completed media report:
for /F "usebackq delims=" %%P in ("!JOB_RESULT!") do (
    set "MEDIA_PATH=%%P"
    if defined MEDIA_PATH call :REPORT_ONE_MEDIA
)
exit /B 0

:REPORT_ONE_MEDIA
if not exist "!MEDIA_PATH!" (
    echo   Output path reported but not found: !MEDIA_PATH!
    exit /B 0
)
echo   !MEDIA_PATH!
if /I "!PROFILE_KIND!"=="VIDEO" (
    "%FFPROBE%" -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of default=noprint_wrappers=1 "!MEDIA_PATH!" 2>nul
    "%FFPROBE%" -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1 "!MEDIA_PATH!" 2>nul
) else (
    "%FFPROBE%" -v error -select_streams a:0 -show_entries stream=codec_name,channels,sample_rate -of default=noprint_wrappers=1 "!MEDIA_PATH!" 2>nul
)
exit /B 0

:RUN_LIST_FORMATS
if defined COOKIE_BROWSER (
    if /I not "!COMPAT_PROFILE!"=="default" (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --cookies-from-browser "!COOKIE_BROWSER!" --extractor-args "youtube:player_client=!COMPAT_PROFILE!" --no-playlist -F --batch-file "!JOB_URL_FILE!" 2>"!JOB_PROBE_LOG!"
    ) else (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --cookies-from-browser "!COOKIE_BROWSER!" --no-playlist -F --batch-file "!JOB_URL_FILE!" 2>"!JOB_PROBE_LOG!"
    )
) else (
    if /I not "!COMPAT_PROFILE!"=="default" (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --extractor-args "youtube:player_client=!COMPAT_PROFILE!" --no-playlist -F --batch-file "!JOB_URL_FILE!" 2>"!JOB_PROBE_LOG!"
    ) else (
        "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --no-playlist -F --batch-file "!JOB_URL_FILE!" 2>"!JOB_PROBE_LOG!"
    )
)
exit /B !ERRORLEVEL!


rem ============================================================================
rem Archive locks and active toolset markers
rem ============================================================================

:ACQUIRE_ARCHIVE_LOCK
:TRY_ARCHIVE_LOCK
mkdir "!ARCHIVE_LOCK!" >nul 2>&1
if not errorlevel 1 (
    >"!ARCHIVE_LOCK!\owner.txt" echo Session !SESSION_ID!, job !JOB_SEQ!, profile !PROFILE_KIND!
    exit /B 0
)
echo.
echo Another !PROFILE_KIND! job holds the archive lock:
echo !ARCHIVE_LOCK!
if exist "!ARCHIVE_LOCK!\owner.txt" type "!ARCHIVE_LOCK!\owner.txt"
echo This prevents concurrent jobs from corrupting or racing the same profile archive.
choice /C WB /N /M "Wait five seconds, or go Back"
if errorlevel 2 exit /B 1
"%TIMEOUT_EXE%" /T 5 /NOBREAK >nul
goto TRY_ARCHIVE_LOCK

:RELEASE_ARCHIVE_LOCK
if defined ARCHIVE_LOCK if exist "!ARCHIVE_LOCK!\" rmdir /S /Q "!ARCHIVE_LOCK!" >nul 2>&1
exit /B 0

:CREATE_ACTIVE_MARKER
call :WAIT_FOR_TOOL_LOCK
if errorlevel 1 exit /B 1
if not exist "%ACTIVE_ROOT%\" mkdir "%ACTIVE_ROOT%" >nul 2>&1
>"!JOB_MARKER!" echo Session !SESSION_ID!, job !JOB_SEQ!, started !DATE! !TIME!
call :RELEASE_TOOL_LOCK
if not exist "!JOB_MARKER!" exit /B 1
exit /B 0

:REMOVE_ACTIVE_MARKER
if defined JOB_MARKER if exist "!JOB_MARKER!" del /Q "!JOB_MARKER!" >nul 2>&1
exit /B 0


rem ============================================================================
rem Tool setup: x64-only, pinned releases, private staging, transactional install
rem ============================================================================

:CHECK_ARCHITECTURE
set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
if not defined NATIVE_ARCH set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if /I "!NATIVE_ARCH!"=="AMD64" exit /B 0
cls
echo ==============================================================================
echo UNSUPPORTED ARCHITECTURE
echo ==============================================================================
echo This release manages verified x64-only yt-dlp, FFmpeg, and aria2c binaries.
echo Detected native architecture: !NATIVE_ARCH!
echo A 32-bit Windows installation and ARM64 are intentionally refused rather than
echo silently using an unsupported binary or a non-native emulation path.
echo.
pause
exit /B 1

:ENSURE_TOOLS
set "FORCE_TOOLSET=%~1"
set "TOOLS_VALID=0"
call :VALIDATE_LIVE_TOOLS
if not errorlevel 1 if "!FORCE_TOOLSET!"=="0" (
    set "TOOLS_VALID=1"
    exit /B 0
)
call :WAIT_FOR_TOOL_LOCK
if errorlevel 1 exit /B 1
call :TOOLSET_HAS_ACTIVE_JOBS
if not errorlevel 1 (
    echo ERROR: A download is currently using the local tools.  Tool replacement is deferred.
    call :RELEASE_TOOL_LOCK
    exit /B 1
)
call :VALIDATE_LIVE_TOOLS
if not errorlevel 1 if "!FORCE_TOOLSET!"=="0" (
    set "TOOLS_VALID=1"
    call :RELEASE_TOOL_LOCK
    exit /B 0
)
echo.
echo Installing the verified pinned local toolset.  Existing working binaries are kept
echo until every staged replacement has passed integrity and execution validation.
call :INSTALL_TOOLSET_TRANSACTION
set "INSTALL_RC=!ERRORLEVEL!"
call :RELEASE_TOOL_LOCK
if not "!INSTALL_RC!"=="0" exit /B 1
call :VALIDATE_LIVE_TOOLS
if errorlevel 1 (
    echo ERROR: The transaction ended but the local toolset did not validate.
    exit /B 1
)
set "TOOLS_VALID=1"
exit /B 0

:WAIT_FOR_TOOL_LOCK
:TRY_TOOL_LOCK
mkdir "%TOOL_LOCK%" >nul 2>&1
if not errorlevel 1 (
    >"%TOOL_LOCK%\owner.txt" echo Session !SESSION_ID!, started !DATE! !TIME!
    exit /B 0
)
echo.
echo Another instance is validating or replacing the local toolset.
if exist "%TOOL_LOCK%\owner.txt" type "%TOOL_LOCK%\owner.txt"
choice /C WB /N /M "Wait five seconds, or go Back"
if errorlevel 2 exit /B 1
"%TIMEOUT_EXE%" /T 5 /NOBREAK >nul
goto TRY_TOOL_LOCK

:RELEASE_TOOL_LOCK
if exist "%TOOL_LOCK%\" rmdir /S /Q "%TOOL_LOCK%" >nul 2>&1
exit /B 0

:TOOLSET_HAS_ACTIVE_JOBS
if not exist "%ACTIVE_ROOT%\" exit /B 1
dir /B "%ACTIVE_ROOT%\*.marker" >"!SESSION_DIR!\active-markers.txt" 2>nul
for /F "usebackq delims=" %%M in ("!SESSION_DIR!\active-markers.txt") do exit /B 0
exit /B 1

:VALIDATE_LIVE_TOOLS
set "YTDLP_VERSION=not installed"
set "FFMPEG_VERSION=not installed"
set "ARIA2_VERSION=not installed"
call :VALIDATE_YTDLP_FILE "%YTDLP%"
if errorlevel 1 exit /B 1
set "YTDLP_VERSION=!CHECK_VERSION!"
call :VALIDATE_FFMPEG_FILES "%FFMPEG%" "%FFPROBE%"
if errorlevel 1 exit /B 1
set "FFMPEG_VERSION=!CHECK_VERSION!"
call :VALIDATE_ARIA2_FILE "%ARIA2C%"
if errorlevel 1 exit /B 1
set "ARIA2_VERSION=!CHECK_VERSION!"
exit /B 0

:VALIDATE_YTDLP_FILE
set "CHECK_VERSION="
if not exist "%~1" exit /B 1
for /F "usebackq delims=" %%V in (`"%~1" --ffmpeg-location "%BIN%" --version 2^>^&1`) do if not defined CHECK_VERSION set "CHECK_VERSION=%%V"
if not defined CHECK_VERSION exit /B 1
if /I not "!CHECK_VERSION!"=="%PINNED_YTDLP_VERSION%" exit /B 1
exit /B 0

:VALIDATE_FFMPEG_FILES
set "CHECK_VERSION="
if not exist "%~1" exit /B 1
if not exist "%~2" exit /B 1
for /F "usebackq tokens=1,2,3" %%A in (`"%~1" -version 2^>^&1`) do if not defined CHECK_VERSION set "CHECK_VERSION=%%A %%B %%C"
if not defined CHECK_VERSION exit /B 1
"%~2" -version >nul 2>&1
if errorlevel 1 exit /B 1
exit /B 0

:VALIDATE_ARIA2_FILE
set "CHECK_VERSION="
if not exist "%~1" exit /B 1
for /F "usebackq tokens=1,2,3" %%A in (`"%~1" --version 2^>^&1`) do if not defined CHECK_VERSION set "CHECK_VERSION=%%A %%B %%C"
if not defined CHECK_VERSION exit /B 1
echo !CHECK_VERSION!|%SystemRoot%\System32\findstr.exe /I /C:"aria2" >nul
if errorlevel 1 exit /B 1
exit /B 0

:INSTALL_TOOLSET_TRANSACTION
set "STAGE_ROOT=!SESSION_DIR!\tool-stage"
set "STAGE_EXTRACT=!STAGE_ROOT!\ffmpeg-extract"
mkdir "!STAGE_ROOT!" >nul 2>&1
if not exist "!STAGE_ROOT!\" exit /B 1
set "STAGE_YTDLP=!STAGE_ROOT!\yt-dlp.new.exe"
set "STAGE_FFMPEG_ZIP=!STAGE_ROOT!\ffmpeg.new.zip"
set "STAGE_ARIA2_ZIP=!STAGE_ROOT!\aria2.new.zip"
set "STAGE_FFMPEG=!BIN%\ffmpeg.!SESSION_ID!.new.exe"
set "STAGE_FFPROBE=!BIN%\ffprobe.!SESSION_ID!.new.exe"
set "STAGE_ARIA2=!BIN%\aria2c.!SESSION_ID!.new.exe"
set "STAGE_YTDLP_BIN=!BIN%\yt-dlp.!SESSION_ID!.new.exe"
set "BACKUP_YTDLP=!BIN%\yt-dlp.!SESSION_ID!.bak.exe"
set "BACKUP_FFMPEG=!BIN%\ffmpeg.!SESSION_ID!.bak.exe"
set "BACKUP_FFPROBE=!BIN%\ffprobe.!SESSION_ID!.bak.exe"
set "BACKUP_ARIA2=!BIN%\aria2c.!SESSION_ID!.bak.exe"
set "HAD_YTDLP=0"
set "HAD_FFMPEG=0"
set "HAD_FFPROBE=0"
set "HAD_ARIA2=0"
if exist "%YTDLP%" set "HAD_YTDLP=1"
if exist "%FFMPEG%" set "HAD_FFMPEG=1"
if exist "%FFPROBE%" set "HAD_FFPROBE=1"
if exist "%ARIA2C%" set "HAD_ARIA2=1"

call :DOWNLOAD_VERIFIED "%YTDLP_URL%" "!STAGE_YTDLP!" "%YTDLP_SIZE%" "%YTDLP_SHA256%" "yt-dlp.exe"
if errorlevel 1 goto INSTALL_FAIL
call :VALIDATE_YTDLP_FILE "!STAGE_YTDLP!"
if errorlevel 1 (
    echo ERROR: Staged yt-dlp did not report the expected version %PINNED_YTDLP_VERSION%.
    goto INSTALL_FAIL
)
call :DOWNLOAD_VERIFIED "%FFMPEG_URL%" "!STAGE_FFMPEG_ZIP!" "%FFMPEG_SIZE%" "%FFMPEG_SHA256%" "FFmpeg ZIP"
if errorlevel 1 goto INSTALL_FAIL
call :EXPAND_VERIFIED_ZIP "!STAGE_FFMPEG_ZIP!" "!STAGE_EXTRACT!" "FFmpeg ZIP"
if errorlevel 1 goto INSTALL_FAIL
call :STAGE_FFMPEG_BINARIES
if errorlevel 1 goto INSTALL_FAIL
call :DOWNLOAD_VERIFIED "%ARIA2_URL%" "!STAGE_ARIA2_ZIP!" "%ARIA2_SIZE%" "%ARIA2_SHA256%" "aria2 ZIP"
if errorlevel 1 goto INSTALL_FAIL
call :EXPAND_VERIFIED_ZIP "!STAGE_ARIA2_ZIP!" "!STAGE_ROOT!\aria2-extract" "aria2 ZIP"
if errorlevel 1 goto INSTALL_FAIL
call :STAGE_ARIA2_BINARY
if errorlevel 1 goto INSTALL_FAIL

copy /Y "!STAGE_YTDLP!" "!STAGE_YTDLP_BIN!" >nul 2>&1
if errorlevel 1 goto INSTALL_FAIL
call :VALIDATE_YTDLP_FILE "!STAGE_YTDLP_BIN!"
if errorlevel 1 goto INSTALL_FAIL
call :VALIDATE_FFMPEG_FILES "!STAGE_FFMPEG!" "!STAGE_FFPROBE!"
if errorlevel 1 goto INSTALL_FAIL
call :VALIDATE_ARIA2_FILE "!STAGE_ARIA2!"
if errorlevel 1 goto INSTALL_FAIL

call :ATOMIC_REPLACE_FILE "!STAGE_YTDLP_BIN!" "%YTDLP%" "!BACKUP_YTDLP!"
if errorlevel 1 goto INSTALL_ROLLBACK
call :VALIDATE_YTDLP_FILE "%YTDLP%"
if errorlevel 1 goto INSTALL_ROLLBACK
call :ATOMIC_REPLACE_FILE "!STAGE_FFMPEG!" "%FFMPEG%" "!BACKUP_FFMPEG!"
if errorlevel 1 goto INSTALL_ROLLBACK
call :VALIDATE_FFMPEG_FILES "%FFMPEG%" "!STAGE_FFPROBE!"
if errorlevel 1 goto INSTALL_ROLLBACK
call :ATOMIC_REPLACE_FILE "!STAGE_FFPROBE!" "%FFPROBE%" "!BACKUP_FFPROBE!"
if errorlevel 1 goto INSTALL_ROLLBACK
call :VALIDATE_FFMPEG_FILES "%FFMPEG%" "%FFPROBE%"
if errorlevel 1 goto INSTALL_ROLLBACK
call :ATOMIC_REPLACE_FILE "!STAGE_ARIA2!" "%ARIA2C%" "!BACKUP_ARIA2!"
if errorlevel 1 goto INSTALL_ROLLBACK
call :VALIDATE_ARIA2_FILE "%ARIA2C%"
if errorlevel 1 goto INSTALL_ROLLBACK

call :DELETE_TOOL_BACKUPS
call :CLEAN_TOOL_STAGE
echo Verified pinned local toolset installed successfully.
exit /B 0

:INSTALL_ROLLBACK
echo ERROR: A post-replacement validation failed.  Restoring prior local tools where available...
call :ROLLBACK_TOOLSET
call :CLEAN_TOOL_STAGE
exit /B 1

:INSTALL_FAIL
echo ERROR: Toolset staging failed.  Existing local tools were not replaced.
call :CLEAN_TOOL_STAGE
exit /B 1

:STAGE_FFMPEG_BINARIES
set "EXTRACT_FFMPEG="
set "EXTRACT_FFPROBE="
for /R "!STAGE_EXTRACT!" %%F in (ffmpeg.exe) do if not defined EXTRACT_FFMPEG set "EXTRACT_FFMPEG=%%~fF"
for /R "!STAGE_EXTRACT!" %%F in (ffprobe.exe) do if not defined EXTRACT_FFPROBE set "EXTRACT_FFPROBE=%%~fF"
if not defined EXTRACT_FFMPEG (
    echo ERROR: Verified FFmpeg ZIP did not contain ffmpeg.exe.
    exit /B 1
)
if not defined EXTRACT_FFPROBE (
    echo ERROR: Verified FFmpeg ZIP did not contain ffprobe.exe.
    exit /B 1
)
copy /Y "!EXTRACT_FFMPEG!" "!STAGE_FFMPEG!" >nul 2>&1
if errorlevel 1 exit /B 1
copy /Y "!EXTRACT_FFPROBE!" "!STAGE_FFPROBE!" >nul 2>&1
if errorlevel 1 exit /B 1
exit /B 0

:STAGE_ARIA2_BINARY
set "EXTRACT_ARIA2="
for /R "!STAGE_ROOT!\aria2-extract" %%F in (aria2c.exe) do if not defined EXTRACT_ARIA2 set "EXTRACT_ARIA2=%%~fF"
if not defined EXTRACT_ARIA2 (
    echo ERROR: Verified aria2 ZIP did not contain aria2c.exe.
    exit /B 1
)
copy /Y "!EXTRACT_ARIA2!" "!STAGE_ARIA2!" >nul 2>&1
if errorlevel 1 exit /B 1
exit /B 0

:DOWNLOAD_VERIFIED
rem Arguments: URL, staged destination, exact byte count, SHA-256, readable label.
set "DL_URL=%~1"
set "DL_DEST=%~2"
set "DL_SIZE=%~3"
set "DL_HASH=%~4"
set "DL_LABEL=%~5"
set "DL_PART=%DL_DEST%.part"
if exist "%DL_PART%" del /Q "%DL_PART%" >nul 2>&1
echo.
echo Downloading %DL_LABEL% ...
if exist "%CURL_EXE%" (
    "%CURL_EXE%" --fail --location --show-error --progress-bar --retry 2 --retry-delay 2 --connect-timeout 20 --output "%DL_PART%" "%DL_URL%"
    if not errorlevel 1 goto DOWNLOAD_CHECK
    echo curl failed or was blocked.  Trying built-in PowerShell without policy bypass...
) else (
    echo curl.exe is unavailable.  Trying built-in PowerShell without policy bypass...
)
if exist "%DL_PART%" del /Q "%DL_PART%" >nul 2>&1
if not exist "%PS_EXE%" (
    echo ERROR: Neither curl.exe nor PowerShell is available for the download.
    exit /B 1
)
set "YTDL_DL_URL=%DL_URL%"
set "YTDL_DL_OUT=%DL_PART%"
"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -UseBasicParsing -Uri $env:YTDL_DL_URL -OutFile $env:YTDL_DL_OUT;if((Get-Item -LiteralPath $env:YTDL_DL_OUT).Length -lt 1){throw 'Downloaded file is empty'}"
if errorlevel 1 (
    echo ERROR: PowerShell download failed or is restricted.  Check internet access, TLS, proxy,
    echo and PowerShell policy.  No local tool was changed.
    if exist "%DL_PART%" del /Q "%DL_PART%" >nul 2>&1
    exit /B 1
)
:DOWNLOAD_CHECK
call :CHECK_FILE_INTEGRITY "%DL_PART%" "%DL_SIZE%" "%DL_HASH%" "%DL_LABEL%"
if errorlevel 1 (
    if exist "%DL_PART%" del /Q "%DL_PART%" >nul 2>&1
    exit /B 1
)
move /Y "%DL_PART%" "%DL_DEST%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Downloaded %DL_LABEL% could not be staged in the private job directory.
    if exist "%DL_PART%" del /Q "%DL_PART%" >nul 2>&1
    exit /B 1
)
exit /B 0

:CHECK_FILE_INTEGRITY
if not exist "%~1" (
    echo ERROR: %~4 was not created.
    exit /B 1
)
set "ACTUAL_SIZE="
for %%S in ("%~1") do set "ACTUAL_SIZE=%%~zS"
if not "!ACTUAL_SIZE!"=="%~2" (
    echo ERROR: %~4 has unexpected size !ACTUAL_SIZE! bytes; expected %~2 bytes.
    exit /B 1
)
call :GET_SHA256 "%~1"
if errorlevel 1 (
    echo ERROR: Could not calculate SHA-256 for %~4.
    exit /B 1
)
if /I not "!ACTUAL_SHA256!"=="%~3" (
    echo ERROR: SHA-256 mismatch for %~4.  The staged file is rejected.
    exit /B 1
)
echo Verified %~4: exact size and SHA-256 match.
exit /B 0

:GET_SHA256
set "ACTUAL_SHA256="
if exist "%CERTUTIL_EXE%" (
    for /F "skip=1 tokens=1" %%H in ('"%CERTUTIL_EXE%" -hashfile "%~1" SHA256 2^>nul') do if not defined ACTUAL_SHA256 set "ACTUAL_SHA256=%%H"
)
if defined ACTUAL_SHA256 exit /B 0
if not exist "%PS_EXE%" exit /B 1
set "YTDL_HASH_FILE=%~1"
for /F "usebackq delims=" %%H in (`"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "try {(Get-FileHash -LiteralPath $env:YTDL_HASH_FILE -Algorithm SHA256 -ErrorAction Stop).Hash} catch {exit 1}" 2^>nul`) do if not defined ACTUAL_SHA256 set "ACTUAL_SHA256=%%H"
if not defined ACTUAL_SHA256 exit /B 1
exit /B 0

:EXPAND_VERIFIED_ZIP
rem Arguments: ZIP file, private extraction directory, readable label.
if not exist "%~1" exit /B 1
if not exist "%PS_EXE%" (
    echo ERROR: PowerShell is required for built-in Expand-Archive and is unavailable.
    exit /B 1
)
mkdir "%~2" >nul 2>&1
if not exist "%~2\" exit /B 1
set "YTDL_ZIP=%~1"
set "YTDL_EXTRACT=%~2"
echo Extracting %~3 with built-in Expand-Archive...
"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop';Expand-Archive -LiteralPath $env:YTDL_ZIP -DestinationPath $env:YTDL_EXTRACT -Force"
if errorlevel 1 (
    echo ERROR: Expand-Archive failed.  The verified ZIP remains isolated and no local tool was changed.
    exit /B 1
)
exit /B 0

:ATOMIC_REPLACE_FILE
rem Arguments: validated staged source, live destination, same-volume backup path.
if not exist "%~1" exit /B 1
if not exist "%PS_EXE%" exit /B 1
set "YTDL_REPLACE_SRC=%~1"
set "YTDL_REPLACE_DST=%~2"
set "YTDL_REPLACE_BAK=%~3"
"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop';$s=$env:YTDL_REPLACE_SRC;$d=$env:YTDL_REPLACE_DST;$b=$env:YTDL_REPLACE_BAK;if(Test-Path -LiteralPath $d){if(Test-Path -LiteralPath $b){Remove-Item -LiteralPath $b -Force};[IO.File]::Replace($s,$d,$b,$true)}else{[IO.File]::Move($s,$d)}"
if errorlevel 1 (
    echo ERROR: Atomic replacement failed.  The existing live file was left untouched.
    exit /B 1
)
exit /B 0

:RESTORE_ONE_FILE
rem Arguments: backup, destination, whether destination existed before installation.
if "%~3"=="1" (
    if not exist "%~1" exit /B 1
    set "YTDL_RESTORE_SRC=%~1"
    set "YTDL_RESTORE_DST=%~2"
    set "YTDL_RESTORE_TMP=%~1.restore.tmp"
    "%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop';[IO.File]::Replace($env:YTDL_RESTORE_SRC,$env:YTDL_RESTORE_DST,$env:YTDL_RESTORE_TMP,$true)" >nul 2>&1
    exit /B !ERRORLEVEL!
)
if exist "%~2" del /Q "%~2" >nul 2>&1
exit /B 0

:ROLLBACK_TOOLSET
call :RESTORE_ONE_FILE "!BACKUP_ARIA2!" "%ARIA2C%" "!HAD_ARIA2!"
call :RESTORE_ONE_FILE "!BACKUP_FFPROBE!" "%FFPROBE%" "!HAD_FFPROBE!"
call :RESTORE_ONE_FILE "!BACKUP_FFMPEG!" "%FFMPEG%" "!HAD_FFMPEG!"
call :RESTORE_ONE_FILE "!BACKUP_YTDLP!" "%YTDLP%" "!HAD_YTDLP!"
call :DELETE_TOOL_BACKUPS
exit /B 0

:DELETE_TOOL_BACKUPS
for %%B in ("!BACKUP_YTDLP!" "!BACKUP_FFMPEG!" "!BACKUP_FFPROBE!" "!BACKUP_ARIA2!") do if exist "%%~fB" del /Q "%%~fB" >nul 2>&1
exit /B 0

:CLEAN_TOOL_STAGE
if defined STAGE_ROOT if exist "!STAGE_ROOT!\" rmdir /S /Q "!STAGE_ROOT!" >nul 2>&1
for %%N in ("!STAGE_YTDLP_BIN!" "!STAGE_FFMPEG!" "!STAGE_FFPROBE!" "!STAGE_ARIA2!") do if exist "%%~fN" del /Q "%%~fN" >nul 2>&1
exit /B 0

:REPAIR_TOOLS
if "!ARCH_SUPPORTED!"=="0" goto MAIN_MENU
cls
echo ==============================================================================
echo REPAIR / REVALIDATE TOOLS
echo ==============================================================================
call :VALIDATE_LIVE_TOOLS
if not errorlevel 1 (
    set "TOOLS_VALID=1"
    echo All local tools are already validated for this session.
    echo yt-dlp: !YTDLP_VERSION!
    echo FFmpeg: !FFMPEG_VERSION!
    echo aria2c: !ARIA2_VERSION!
    pause
    goto MAIN_MENU
)
echo One or more local tools are missing, corrupted, or do not match the pinned release.
choice /C YN /N /M "Download and transactionally repair the pinned toolset"
if errorlevel 2 goto MAIN_MENU
call :ENSURE_TOOLS 1
if errorlevel 1 (
    set "TOOLS_VALID=0"
    echo Repair did not complete.  Existing working tools were preserved when present.
) else (
    echo Repair completed successfully.
)
pause
goto MAIN_MENU

:FORCE_TOOLSET
if "!ARCH_SUPPORTED!"=="0" goto MAIN_MENU
cls
echo ==============================================================================
echo REINSTALL VERIFIED PINNED TOOLSET
echo ==============================================================================
echo This downloads immutable versions baked into this batch file and verifies exact
echo SHA-256 hashes.  It is not a mutable latest-version updater.
echo Active downloads prevent replacement.
echo.
choice /C YN /N /M "Reinstall the verified pinned toolset now"
if errorlevel 2 goto MAIN_MENU
call :ENSURE_TOOLS 1
if errorlevel 1 (
    set "TOOLS_VALID=0"
    echo Reinstallation failed.  Existing working files were retained when possible.
) else (
    echo Reinstallation completed.
)
pause
goto MAIN_MENU

:SELF_TEST
if "!TOOLS_VALID!"=="0" (
    call :TOOLS_REQUIRED_MESSAGE
    goto MAIN_MENU
)
cls
echo ==============================================================================
echo YOUTUBE EXTRACTION SELF-TEST
echo ==============================================================================
echo This performs a read-only metadata extraction with --skip-download.  It verifies
echo that yt-dlp can currently reach and extract a real YouTube URL, not merely --version.
echo Use a known public video.  No media is downloaded.
echo.
set "SELF_URL=!LAST_URL!"
if defined SELF_URL echo Press Enter to test the last URL, or paste another public video URL.
set /P "SELF_URL=Self-test URL: "
if not defined SELF_URL (
    echo Self-test cancelled; no URL was supplied.
    pause
    goto MAIN_MENU
)
set "URL=!SELF_URL!"
set "SELF_ID="
call :CREATE_JOB_DIR
if errorlevel 1 (
    call :JOB_DIR_ERROR
    goto MAIN_MENU
)
call :WRITE_URL_FILE
if errorlevel 1 goto SELF_TEST_FAILURE
echo.
echo Exact yt-dlp command:
echo "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --no-playlist --skip-download --print "%%(id)s" --batch-file "!JOB_URL_FILE!"
echo.
call :RUN_SELF_TEST_COMMAND
set "SELF_RC=!ERRORLEVEL!"
if not "!SELF_RC!"=="0" goto SELF_TEST_FAILURE
if not exist "!JOB_ITEMS!" goto SELF_TEST_FAILURE
for /F "usebackq delims=" %%I in ("!JOB_ITEMS!") do set "SELF_ID=%%I"
if not defined SELF_ID goto SELF_TEST_FAILURE
echo SUCCESS: YouTube extraction returned video ID !SELF_ID!.
call :CLEAN_CURRENT_JOB
pause
goto MAIN_MENU

:RUN_SELF_TEST_COMMAND
if defined COOKIE_BROWSER (
    "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --cookies-from-browser "!COOKIE_BROWSER!" --no-playlist --skip-download --no-warnings --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
) else (
    "%YTDLP%" --ignore-config --ffmpeg-location "%BIN%" --no-playlist --skip-download --no-warnings --print "%%(id)s" --batch-file "!JOB_URL_FILE!" >"!JOB_ITEMS!" 2>"!JOB_PROBE_LOG!"
)
exit /B !ERRORLEVEL!

:SELF_TEST_FAILURE
echo ERROR: The YouTube extraction self-test failed.  No media was downloaded.
echo Diagnostic output: !JOB_PROBE_LOG!
if exist "!JOB_PROBE_LOG!" type "!JOB_PROBE_LOG!"
call :CLEAN_CURRENT_JOB
pause
goto MAIN_MENU


rem ============================================================================
rem Persistent settings
rem ============================================================================

:SET_SAFE_DEFAULTS
set "MULTI_MODE=0"
set "PLAYLIST_LIMIT="
set "IGNORE_ARCHIVE=0"
set "SPONSOR_CATS=sponsor,intro,outro"
set "SUBTITLES=0"
set "SUB_LANGS=en.*,en"
set "COOKIE_BROWSER="
set "OUTPUT_ROOT="
set "KEEP_ORIGINAL=0"
set "DIRECT_ACCEL=1"
set "FRAGMENT_COUNT=4"
set "BANDWIDTH_LIMIT="
set "DIAGNOSTIC=0"
set "COMPAT_PROFILE=default"
set "TRIM_LENGTH=180"
set "REPORT_MEDIA=1"
exit /B 0

:LOAD_SETTINGS
call :SET_SAFE_DEFAULTS
if not exist "%SETTINGS_FILE%" (
    call :SAVE_SETTINGS
    exit /B 0
)
for /F "usebackq tokens=1,* delims==" %%A in ("%SETTINGS_FILE%") do (
    if /I "%%A"=="MULTI_MODE" set "MULTI_MODE=%%B"
    if /I "%%A"=="PLAYLIST_LIMIT" set "PLAYLIST_LIMIT=%%B"
    if /I "%%A"=="IGNORE_ARCHIVE" set "IGNORE_ARCHIVE=%%B"
    if /I "%%A"=="SPONSOR_CATS" set "SPONSOR_CATS=%%B"
    if /I "%%A"=="SUBTITLES" set "SUBTITLES=%%B"
    if /I "%%A"=="SUB_LANGS" set "SUB_LANGS=%%B"
    if /I "%%A"=="COOKIE_BROWSER" set "COOKIE_BROWSER=%%B"
    if /I "%%A"=="OUTPUT_ROOT" set "OUTPUT_ROOT=%%B"
    if /I "%%A"=="KEEP_ORIGINAL" set "KEEP_ORIGINAL=%%B"
    if /I "%%A"=="DIRECT_ACCEL" set "DIRECT_ACCEL=%%B"
    if /I "%%A"=="FRAGMENT_COUNT" set "FRAGMENT_COUNT=%%B"
    if /I "%%A"=="BANDWIDTH_LIMIT" set "BANDWIDTH_LIMIT=%%B"
    if /I "%%A"=="DIAGNOSTIC" set "DIAGNOSTIC=%%B"
    if /I "%%A"=="COMPAT_PROFILE" set "COMPAT_PROFILE=%%B"
    if /I "%%A"=="TRIM_LENGTH" set "TRIM_LENGTH=%%B"
    if /I "%%A"=="REPORT_MEDIA" set "REPORT_MEDIA=%%B"
)
call :VALIDATE_SETTINGS
exit /B 0

:VALIDATE_SETTINGS
if not "!MULTI_MODE!"=="0" if not "!MULTI_MODE!"=="1" set "MULTI_MODE=0"
if not "!IGNORE_ARCHIVE!"=="0" if not "!IGNORE_ARCHIVE!"=="1" set "IGNORE_ARCHIVE=0"
if not "!SUBTITLES!"=="0" if not "!SUBTITLES!"=="1" set "SUBTITLES=0"
if not "!KEEP_ORIGINAL!"=="0" if not "!KEEP_ORIGINAL!"=="1" set "KEEP_ORIGINAL=0"
if not "!DIRECT_ACCEL!"=="0" if not "!DIRECT_ACCEL!"=="1" set "DIRECT_ACCEL=1"
if not "!DIAGNOSTIC!"=="0" if not "!DIAGNOSTIC!"=="1" set "DIAGNOSTIC=0"
if not "!REPORT_MEDIA!"=="0" if not "!REPORT_MEDIA!"=="1" set "REPORT_MEDIA=1"
if not "!FRAGMENT_COUNT!"=="4" if not "!FRAGMENT_COUNT!"=="6" if not "!FRAGMENT_COUNT!"=="8" set "FRAGMENT_COUNT=4"
if /I not "!COOKIE_BROWSER!"=="" if /I not "!COOKIE_BROWSER!"=="chrome" if /I not "!COOKIE_BROWSER!"=="edge" if /I not "!COOKIE_BROWSER!"=="firefox" set "COOKIE_BROWSER="
if /I not "!COMPAT_PROFILE!"=="default" if /I not "!COMPAT_PROFILE!"=="android" if /I not "!COMPAT_PROFILE!"=="web" set "COMPAT_PROFILE=default"
echo(!PLAYLIST_LIMIT!|%SystemRoot%\System32\findstr.exe /R /X "[1-9][0-9]*" >nul
if errorlevel 1 set "PLAYLIST_LIMIT="
echo(!TRIM_LENGTH!|%SystemRoot%\System32\findstr.exe /R /X "1[2-9][0-9]" >nul
if errorlevel 1 set "TRIM_LENGTH=180"
exit /B 0

:SAVE_SETTINGS
call :ACQUIRE_SETTINGS_LOCK
if errorlevel 1 (
    echo WARNING: Settings could not be saved because another instance holds the settings lock.
    exit /B 1
)
set "SETTINGS_STAGE=!SESSION_DIR!\settings.!SESSION_ID!.new"
set "SETTINGS_BACKUP=!SESSION_DIR!\settings.!SESSION_ID!.bak"
>"!SETTINGS_STAGE!" (
    echo # %APP_NAME% persistent settings - edited by the application
    echo MULTI_MODE=!MULTI_MODE!
    echo PLAYLIST_LIMIT=!PLAYLIST_LIMIT!
    echo IGNORE_ARCHIVE=!IGNORE_ARCHIVE!
    echo SPONSOR_CATS=!SPONSOR_CATS!
    echo SUBTITLES=!SUBTITLES!
    echo SUB_LANGS=!SUB_LANGS!
    echo COOKIE_BROWSER=!COOKIE_BROWSER!
    echo OUTPUT_ROOT=!OUTPUT_ROOT!
    echo KEEP_ORIGINAL=!KEEP_ORIGINAL!
    echo DIRECT_ACCEL=!DIRECT_ACCEL!
    echo FRAGMENT_COUNT=!FRAGMENT_COUNT!
    echo BANDWIDTH_LIMIT=!BANDWIDTH_LIMIT!
    echo DIAGNOSTIC=!DIAGNOSTIC!
    echo COMPAT_PROFILE=!COMPAT_PROFILE!
    echo TRIM_LENGTH=!TRIM_LENGTH!
    echo REPORT_MEDIA=!REPORT_MEDIA!
)
if errorlevel 1 (
    call :RELEASE_SETTINGS_LOCK
    exit /B 1
)
call :ATOMIC_REPLACE_FILE "!SETTINGS_STAGE!" "%SETTINGS_FILE%" "!SETTINGS_BACKUP!"
set "SAVE_RC=!ERRORLEVEL!"
if exist "!SETTINGS_BACKUP!" del /Q "!SETTINGS_BACKUP!" >nul 2>&1
call :RELEASE_SETTINGS_LOCK
exit /B !SAVE_RC!

:ACQUIRE_SETTINGS_LOCK
:TRY_SETTINGS_LOCK
mkdir "%SETTINGS_LOCK%" >nul 2>&1
if not errorlevel 1 (
    >"%SETTINGS_LOCK%\owner.txt" echo Session !SESSION_ID!, started !DATE! !TIME!
    exit /B 0
)
echo Another instance is saving settings.
choice /C WB /N /M "Wait two seconds, or go Back"
if errorlevel 2 exit /B 1
"%TIMEOUT_EXE%" /T 2 /NOBREAK >nul
goto TRY_SETTINGS_LOCK

:RELEASE_SETTINGS_LOCK
if exist "%SETTINGS_LOCK%\" rmdir /S /Q "%SETTINGS_LOCK%" >nul 2>&1
exit /B 0

:SHOW_SETTING_SUMMARY
if "!MULTI_MODE!"=="1" (set "MULTI_TEXT=ON") else (set "MULTI_TEXT=OFF")
if defined PLAYLIST_LIMIT (set "LIMIT_TEXT=first !PLAYLIST_LIMIT!") else (set "LIMIT_TEXT=unrestricted")
if "!IGNORE_ARCHIVE!"=="1" (set "ARCHIVE_TEXT=IGNORE THIS RUN") else (set "ARCHIVE_TEXT=profile archive")
if "!SUBTITLES!"=="1" (set "SUB_TEXT=ON (!SUB_LANGS!)") else (set "SUB_TEXT=OFF")
if defined COOKIE_BROWSER (set "COOKIE_TEXT=!COOKIE_BROWSER!") else (set "COOKIE_TEXT=OFF")
if defined OUTPUT_ROOT (set "OUTPUT_TEXT=!OUTPUT_ROOT!") else (set "OUTPUT_TEXT=!DOWNLOAD_ROOT!")
if "!KEEP_ORIGINAL!"=="1" (set "KEEP_TEXT=ON") else (set "KEEP_TEXT=OFF")
echo Playlist/channel mode: !MULTI_TEXT! ^| Limit: !LIMIT_TEXT! ^| Archive: !ARCHIVE_TEXT!
echo SponsorBlock: !SPONSOR_CATS! ^| Subtitles: !SUB_TEXT! ^| Cookies: !COOKIE_TEXT!
echo Output root: !OUTPUT_TEXT! ^| Original video container: !KEEP_TEXT!
echo Network: !FRAGMENT_COUNT! fragments ^| Direct aria2c: !DIRECT_ACCEL! ^| Rate: !BANDWIDTH_LIMIT!
echo Compatibility profile: !COMPAT_PROFILE! ^| Final media report: !REPORT_MEDIA!
exit /B 0


rem ============================================================================
rem Initialization, safety messages, and cleanup
rem ============================================================================

:INITIALIZE_FOLDERS
for %%D in ("%BIN%" "%DOWNLOAD_ROOT%" "%TEMP_ROOT%" "%LOG_ROOT%" "%LOCK_ROOT%" "%ACTIVE_ROOT%") do (
    if not exist "%%~fD\" mkdir "%%~fD" >nul 2>&1
    if not exist "%%~fD\" exit /B 1
)
exit /B 0

:CREATE_SESSION_DIR
set "SESSION_ID="
if exist "%PS_EXE%" (
    for /F "usebackq delims=" %%G in (`"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "[guid]::NewGuid().ToString('N')" 2^>nul`) do if not defined SESSION_ID set "SESSION_ID=%%G"
)
if not defined SESSION_ID set "SESSION_ID=%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
set "SESSION_DIR="
for /L %%N in (1,1,40) do (
    if not defined SESSION_DIR (
        set "SESSION_TRY=!SESSION_ID!-%%N"
        mkdir "%TEMP_ROOT%\session-!SESSION_TRY!" >nul 2>&1
        if not errorlevel 1 (
            set "SESSION_ID=!SESSION_TRY!"
            set "SESSION_DIR=%TEMP_ROOT%\session-!SESSION_TRY!"
        )
    )
)
if not defined SESSION_DIR exit /B 1
exit /B 0

:DETECT_SYNC_ROOT
set "SYNC_ROOT=0"
if defined OneDrive (
    if exist "%PS_EXE%" (
        set "YTDL_ROOT_CHECK=%ROOT%"
        for /F "usebackq delims=" %%S in (`"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "$r=[IO.Path]::GetFullPath($env:YTDL_ROOT_CHECK);$o=$env:OneDrive;if($o -and $r.StartsWith([IO.Path]::GetFullPath($o),[StringComparison]::OrdinalIgnoreCase)){'SYNC'}" 2^>nul`) do if "%%S"=="SYNC" set "SYNC_ROOT=1"
    )
)
echo(%ROOT%|%SystemRoot%\System32\findstr.exe /I /C:"\OneDrive\" /C:"\Dropbox\" /C:"\Google Drive\" >nul
if not errorlevel 1 set "SYNC_ROOT=1"
if "!SYNC_ROOT!"=="1" (
    echo.
    echo IMPORTANT SYNC WARNING: This script's temp state, locks, archives, and tools are under
    echo a synced folder.  Local locks cannot protect a second PC syncing the same folder.
    echo Keep this batch in a local non-synced folder for the safest large downloads.
)
exit /B 0

:DETECT_SYNC_OUTPUT
set "SYNC_OUTPUT=0"
echo(!OUTPUT_ROOT!|%SystemRoot%\System32\findstr.exe /I /C:"\OneDrive\" /C:"\Dropbox\" /C:"\Google Drive\" >nul
if not errorlevel 1 set "SYNC_OUTPUT=1"
if "!SYNC_OUTPUT!"=="1" (
    echo WARNING: The chosen output root appears synced.  Downloads may be uploaded while still
    echo changing.  Do not run the same toolset from another synced device concurrently.
    pause
)
exit /B 0

:WARN_LONG_ROOT
set /A ROOT_LENGTH=0
for /L %%L in (0,1,400) do if not "!ROOT:~%%L,1!"=="" set /A ROOT_LENGTH=%%L+1
if !ROOT_LENGTH! GEQ 150 (
    echo WARNING: The script root is already !ROOT_LENGTH! characters long.
    echo Windows long-path policy may still limit some programs.  Keep this tool close to a drive root.
    pause
)
exit /B 0

:WARN_LONG_OUTPUT
set /A OUTPUT_LENGTH=0
for /L %%L in (0,1,400) do if not "!OUTPUT_ROOT:~%%L,1!"=="" set /A OUTPUT_LENGTH=%%L+1
if !OUTPUT_LENGTH! GEQ 150 (
    echo WARNING: The custom output root is !OUTPUT_LENGTH! characters long.  The script trims titles,
    echo but Windows long-path policy and third-party tools can still impose limits.
    pause
)
exit /B 0

:VALIDATE_URL_SHAPE
echo(!URL!|%SystemRoot%\System32\findstr.exe /I /R /C:"youtube\.com" /C:"youtu\.be" >nul
if not errorlevel 1 exit /B 0
echo.
echo WARNING: This does not look like a standard YouTube URL.
choice /C YN /N /M "Continue anyway"
if errorlevel 2 exit /B 2
exit /B 0

:VALIDATE_BATCH_URL
echo(!URL!|%SystemRoot%\System32\findstr.exe /I /R /C:"^https\?://" >nul
if errorlevel 1 exit /B 1
echo(!URL!|%SystemRoot%\System32\findstr.exe /I /R /C:"youtube\.com" /C:"youtu\.be" >nul
if errorlevel 1 exit /B 1
exit /B 0

:GET_TIMESTAMP
set "STAMP="
if exist "%PS_EXE%" (
    for /F "usebackq delims=" %%T in (`"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -Command "Get-Date -Format yyyyMMdd-HHmmss" 2^>nul`) do if not defined STAMP set "STAMP=%%T"
)
if not defined STAMP set "STAMP=%RANDOM%%RANDOM%"
exit /B 0

:CLEAN_CURRENT_JOB
call :REMOVE_ACTIVE_MARKER
if defined JOB_DIR if exist "!JOB_DIR!\" rmdir /S /Q "!JOB_DIR!" >nul 2>&1
set "JOB_DIR="
set "JOB_CONFIG="
set "JOB_URL_FILE="
set "JOB_ITEMS="
set "JOB_PROBE_LOG="
set "JOB_RESULT="
set "JOB_MARKER="
exit /B 0

:JOB_DIR_ERROR
echo ERROR: A unique private job directory could not be created under "%TEMP_ROOT%".
echo Check folder permissions, free space, antivirus locks, and sync-client activity.
pause
exit /B 0

:TOOLS_REQUIRED_MESSAGE
echo.
echo ERROR: Local tools are not validated.  Choose Repair / revalidate local tools first.
echo No download action was started.
echo.
pause
exit /B 0

:OPEN_DOWNLOADS
if not exist "%DOWNLOAD_ROOT%\" mkdir "%DOWNLOAD_ROOT%" >nul 2>&1
start "" explorer.exe "%DOWNLOAD_ROOT%"
goto MAIN_MENU

:OPEN_BIN
if not exist "%BIN%\" mkdir "%BIN%" >nul 2>&1
start "" explorer.exe "%BIN%"
goto MAIN_MENU

:FATAL_INIT
cls
echo ==============================================================================
echo INITIALIZATION ERROR
echo ==============================================================================
echo Required folders next to this batch file could not be created or accessed.
echo Move the batch file to a writable local folder and run it again.
echo The window remains open.  You may retry after fixing the folder, or choose Exit.
echo.
choice /C RE /N /M "Retry initialization, or Exit"
if errorlevel 2 (
    endlocal
    exit /B 1
)
call :INITIALIZE_FOLDERS
if errorlevel 1 goto FATAL_INIT
call :CREATE_SESSION_DIR
if errorlevel 1 goto FATAL_INIT
call :LOAD_SETTINGS
call :DETECT_SYNC_ROOT
call :WARN_LONG_ROOT
if "!ARCH_SUPPORTED!"=="1" call :ENSURE_TOOLS 0
goto MAIN_MENU

:EXIT_PROGRAM
call :CLEAN_CURRENT_JOB
if defined SESSION_DIR if exist "!SESSION_DIR!\" rmdir /S /Q "!SESSION_DIR!" >nul 2>&1
cls
echo.
echo %APP_NAME% is closing because you chose Exit.
echo.
endlocal
exit /B 0
