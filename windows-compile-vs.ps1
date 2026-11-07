$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

# =============================================================================
# Khronos PHP compiler for Windows
# =============================================================================
# Adapted from pmmp/PHP-Binaries "windows-compile-vs.ps1" (branch "stable").
# Provenance and attribution: original script (c) PocketMine Team, LGPL-3.0.
#
# Differences vs the pmmp script (each verified against Khronos sources):
#
#  1. Targets Khronos, not PocketMine-MP 5:
#     - No PM_VERSION_MAJOR. PHP 8.2 pinned (composer.json: "php": ">=8.2",
#       config.platform.php = 8.2).
#  2. Parity with KhronosDevs/php-binaries build.sh (the Linux runtime):
#     - ext-pmmpthread cloned from branch "fork" (build.sh does the same,
#       PMMPTHREAD_BRANCH=fork; the pmmp script used the 6.3.0 release zip).
#     - ext-yaml cloned from git master (build.sh does the same).
#     - FFI compiled (--enable-ffi=shared). build.sh compiles it on Linux and
#       both start.cmd and start.ps1 pass "-d extension=ffi -d ffi.enable=1",
#       while the shipped php.ini has ffi.enable=true. The pmmp script does
#       NOT compile FFI, which is the core functional break of the old job.
#     - Same extension set as build.sh: bcmath, ctype, curl, ffi, gmp,
#       mbstring, mysqlnd, mysqli, pdo, pdo-sqlite, pdo-mysql, opcache, phar,
#       sockets, sqlite3, yaml, zip, zlib.
#     - PM5-only extensions removed: leveldb, chunkutils2, crypto, libdeflate,
#       morton, xxhash, encoding, recursionguard, arraydebug, xdebug, gd,
#       dom/xml, com-dotnet, bz2, sodium, fileinfo, calendar, filter,
#       tokenizer, simplexml, libxml.
#     - igbinary removed: build.sh does NOT build it on Linux either (the old
#       workflow ini loaded php_igbinary.dll on Windows only; inconsistency).
#  3. Installs to bin\php7\bin (matches start.cmd "bin\php7\bin\php.exe" and
#     the Linux artifact layout bin/php7/bin/php).
#  4. Generates php.ini, php.ini-production and php.ini-development with the
#     Khronos settings from php-production.ini / php-development.ini, and
#     lists ONLY the shared DLLs that actually exist in ext\ (enumerated at
#     build time), so the ini can never reference a nonexistent extension.
#  5. Built-in smoke test: php -v, required extensions, ZTS enabled.
#
# PHP-sdk deps catalog (vs16, 8.2) provides libffi and libzip, so FFI and zip
# build on Windows exactly like on Linux.
# =============================================================================

$PHP_VERSIONS=@("8.2.30")

$PHP_SDK_VER="2.4.0"
$ARCH="x64"

$LIBYAML_VER="0.2.5"
$PTHREAD_W32_VER="3.0.0"

# Khronos parity: build.sh clones ext-pmmpthread from the "fork" branch.
$PMMPTHREAD_BRANCH="fork"
if ($env:PMMPTHREAD_BRANCH -ne $null) {
    $PMMPTHREAD_BRANCH=$env:PMMPTHREAD_BRANCH
}

function kh-echo {
    param ([string] $message)

    echo "[Khronos] $message"
    echo "[Khronos] $message" >> "$log_file"
}

function kh-echo-error {
    param ([string] $message)

    kh-echo "[ERROR] $message"
}

function kh-fatal-error {
    param ([string] $message)

    kh-echo-error $message
    exit 1
}

$library = ""
$library_version = ""
function write-library {
    param ([string] $library, [string] $version)

    Write-Host -NoNewline "[$library $version]"
    $script:library = $library
    $script:library_version = $version
}
function write-status {
    param ([string] $status)

    Write-Host -NoNewline " $status..."
    echo "[$library $library_version] $status..." >> "$log_file"
}
function write-download {
    write-status "downloading"
}
function write-extracting {
    write-status "extracting"
}
function write-configure {
    write-status "configuring"
}
function write-compile {
    write-status "compiling"
}
function write-install {
    write-status "installing"
}
function write-done {
    echo " done!"
    $script:library = ""
    $script:library_version = ""
}
function write-cached {
    write-status "using cache"
}

$log_file="$pwd\compile.log"
echo "" > "$log_file"
$outpath="$pwd"

kh-echo "Khronos PHP compiler for Windows"
date >> "$log_file"

kh-echo "Checking dependencies"

$script_dependencies = @("git", "cmake")
foreach ($dep in $script_dependencies) {
    $depInfo = Get-Command "$dep" -ErrorAction SilentlyContinue
    if ($depInfo -eq $null) {
        kh-fatal-error "$dep is required but can't be found in your PATH"
    } else {
        kh-echo "Found $dep in $($depInfo.Source)"
    }
}

kh-echo "Checking configuration options"

# Khronos targets PHP 8.2 (composer.json platform). Overridable for 8.2.x bumps.
$PHP_VERSION_BASE="8.2"
if ($env:PHP_VERSION_BASE -ne $null) {
    $PHP_VERSION_BASE=$env:PHP_VERSION_BASE
}

$PHP_DEBUG_BUILD=0
if ($env:PHP_DEBUG_BUILD -eq 1) {
    $PHP_DEBUG_BUILD=1
}

$MSBUILD_CONFIGURATION="RelWithDebInfo"

if ($PHP_DEBUG_BUILD -eq 0) {
    $OUT_PATH_REL="Release"
    $PHP_HAVE_DEBUG="enable-debug-pack"
    kh-echo "Building release binaries with debugging symbols"
} else {
    $OUT_PATH_REL="Debug"
    $PHP_HAVE_DEBUG="enable-debug"

    #YAML will crash if it's not built with the same target as PHP
    $MSBUILD_CONFIGURATION="Debug"
    kh-echo "Building debug binaries"
}

function php-version-id {
    param ([string] $version)

    $parts = $version.Split(".")

    #TODO: patch is a pain because of suffixes and we don't really need it anyway
    $result = (([int]$parts[0]) * 10000) + (([int]$parts[1]) * 100)
    return $result
}

$PHP_VER=""
foreach ($version in $PHP_VERSIONS) {
    if ($version -like "$PHP_VERSION_BASE.*") {
        $PHP_VER=$version
        break
    }
}
if ($PHP_VER -eq "") {
    kh-echo-error "Khronos targets PHP 8.2 only (unsupported base: $PHP_VERSION_BASE)"
    exit 1
}

#don't really need these except for dev versions
$PHP_GIT_REV="php-$PHP_VER"
$PHP_DISPLAY_VER="$PHP_VER"

$CMAKE_TARGET="Visual Studio 17 2022"

$VC_VER=""
$SDK_TOOLSET_FLAG=""
$CMAKE_TOOLSET_FLAG=""

$PHP_VERSION_ID = php-version-id $PHP_VER
if ($PHP_VERSION_ID -ge 80400) {
    $VC_VER="vs17"
    $SDK_TOOLSET_FLAG=""
    $CMAKE_TOOLSET_FLAG=""
} else {
    #technically it's fine to build <8.4 with vs17, but this would make the
    #binaries ABI-incompatible with community prebuilt extensions
    $VC_VER="vs16"
    $SDK_TOOLSET_FLAG="-s=14.29"
    $CMAKE_TOOLSET_FLAG="-T v142"
}

kh-echo "Selected PHP $PHP_VER ($PHP_VERSION_ID), SDK target $VC_VER ($SDK_TOOLSET_FLAG), CMake target $CMAKE_TARGET ($CMAKE_TOOLSET_FLAG)"

#Khronos php.ini ships opcache.jit=tracing (php-production.ini [JIT] section),
#so the binary must be built with JIT support. Set PHP_JIT_SUPPORT=0 to skip
#(the ini JIT directives are then silently ignored at runtime).
$PHP_JIT_ENABLE_ARG="no"
if ($env:PHP_JIT_SUPPORT -eq 1) {
    $PHP_JIT_ENABLE_ARG="yes"
    kh-echo "[WARNING] JIT support will be compiled into OPcache"
    if ($PHP_VERSION_ID -lt 80400) {
        kh-echo "[WARNING] JIT in versions below PHP 8.4 is less battle-tested than on Linux"
    }
} else {
    kh-echo "JIT support in OPcache won't be compiled (set PHP_JIT_SUPPORT=1 to enable)"
}

if ($env:SOURCES_PATH -ne $null) {
    $BASE_PATH=$env:SOURCES_PATH
} else {
    $BASE_PATH="C:\pocketmine-php"
}
$PHP_SDK_PATH="$BASE_PATH\php-sdk-binary-tools-$PHP_SDK_VER"
$SOURCES_PATH="$BASE_PATH\php-$PHP_DISPLAY_VER-$($OUT_PATH_REL.ToLower())"

kh-echo "Using path $SOURCES_PATH for PHP build sources"
if (-not (Test-Path "$BASE_PATH")) {
    mkdir "$BASE_PATH" >> $log_file 2>&1
}

if (Test-Path "$pwd\bin") {
    kh-echo "Deleting old binary folder..."
    Remove-Item -Recurse -Force "$pwd\bin" 2>&1
}
if (Test-Path $SOURCES_PATH) {
    kh-echo "Deleting old PHP build workspace $SOURCES_PATH..."
    Remove-Item -Recurse -Force $SOURCES_PATH 2>&1
}
$LIB_BUILD_DIR="$BASE_PATH\deps-build-php-$PHP_VERSION_BASE-$($OUT_PATH_REL.ToLower())"

if (Test-Path $LIB_BUILD_DIR) {
    kh-echo "Deleting old deps build workspace $LIB_BUILD_DIR..."
    Remove-Item -Recurse -Force $LIB_BUILD_DIR >> $log_file 2>&1
}

$download_cache="$pwd\download_cache"
function download-file {
    param ([string] $url, [string] $prefix)

    $cached_filename="$prefix-$($url.Substring($url.LastIndexOf("/") + 1))"
    $cached_path="$download_cache\$cached_filename"

    if (!(Test-Path $download_cache)) {
        mkdir $download_cache >> $log_file 2>&1
    }

    if (Test-Path $cached_path) {
        echo "Cache hit for URL: $url" >> $log_file
    } else {
        echo "Downloading file from $url to $cached_path" >> $log_file
        #download to a tmpfile first, so that we don't leave borked cache entries for later runs
        Invoke-WebRequest -Uri $url -OutFile "$download_cache/.temp" >> $log_file 2>&1
        Move-Item "$download_cache/.temp" $cached_path >> $log_file 2>&1
    }
    if (!(Test-Path $cached_path)) {
        kh-fatal-error "Failed to download file from $url"
    }

    return $cached_path
}

function unzip-file {
    param ([string] $file, [string] $destination)

    #expand-archive doesn't respect script-local ProgressPreference
    #https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/77
    $oldProgressPref = $global:ProgressPreference
    $global:ProgressPreference = "SilentlyContinue"
    Expand-Archive -Path $file -DestinationPath $destination >> $log_file 2>&1
    $global:ProgressPreference = $oldProgressPref
}

function append-file-utf8 {
    param ([string] $line, [string] $file)

    Out-File -Append -FilePath $file -Encoding utf8 -InputObject $line
}

function download-sdk {
    write-library "PHP SDK" $PHP_SDK_VER

    if (Test-Path "$PHP_SDK_PATH") {
        write-cached
    } else {
        write-download
        $file = download-file "https://github.com/php/php-sdk-binary-tools/archive/refs/tags/php-sdk-$PHP_SDK_VER.zip" "php-sdk"
        write-extracting
        unzip-file $file $pwd
        Move-Item "php-sdk-binary-tools-php-sdk-$PHP_SDK_VER" $PHP_SDK_PATH
    }
    write-done
}

function sdk-command {
    param ([string] $command, [string] $errorMessage = "")

    New-Item task.bat -Value $command >> $log_file 2>&1
    echo "Running SDK command: $command" >> $log_file
    $wrap = "`"$PHP_SDK_PATH\phpsdk-starter.bat`" -c $VC_VER -a $ARCH $SDK_TOOLSET_FLAG -t task.bat 2>&1"
    echo "SDK wrapper command: $wrap" >> $log_file
    (& cmd.exe /c $wrap) >> $log_file
    $result=$LASTEXITCODE
    if ($result -ne 0) {
        if ($errorMessage -eq "") {
            kh-fatal-error "Error code $result running SDK build command"
        } else {
            kh-fatal-error $errorMessage
        }
    }
    Remove-Item task.bat
}

function download-php-deps {
    write-library "PHP prebuilt deps" "$PHP_VERSION_BASE/$VC_VER"
    write-download
    sdk-command "phpsdk_deps -u -t $VC_VER -b $PHP_VERSION_BASE -a $ARCH -d $DEPS_DIR || exit 1"
    write-done
}

function build-yaml {
    write-library "yaml" $LIBYAML_VER
    write-download
    $file = download-file "https://github.com/yaml/libyaml/archive/$LIBYAML_VER.zip" "yaml"
    write-extracting
    unzip-file $file $pwd
    Move-Item "libyaml-$LIBYAML_VER" libyaml >> $log_file 2>&1
    Push-Location libyaml

    write-configure
    sdk-command "cmake -G `"$CMAKE_TARGET`" $CMAKE_TOOLSET_FLAG^`
        -DCMAKE_PREFIX_PATH=`"$DEPS_DIR`"^`
        -DCMAKE_INSTALL_PREFIX=`"$DEPS_DIR`"^`
        -DBUILD_SHARED_LIBS=ON^`
        `"$pwd`" || exit 1"
    write-compile
    sdk-command "msbuild ALL_BUILD.vcxproj /p:Configuration=$MSBUILD_CONFIGURATION /m || exit 1"
    write-install
    sdk-command "msbuild INSTALL.vcxproj /p:Configuration=$MSBUILD_CONFIGURATION /m || exit 1"
    Copy-Item "$MSBUILD_CONFIGURATION\yaml.pdb" "$DEPS_DIR\bin" >> $log_file 2>&1
    write-done
    Pop-Location
}

function build-pthreads4w {
    write-library "pthreads4w" $PTHREAD_W32_VER
    write-download
    $file = download-file "https://github.com/pmmp/DependencyMirror/releases/download/mirror/pthreads4w-code-v$PTHREAD_W32_VER.zip" "pthreads4w"
    write-extracting
    unzip-file $file $pwd
    Move-Item "pthreads4w-code-*" pthreads4w >> $log_file 2>&1
    Push-Location pthreads4w

    write-compile
    sdk-command "nmake VC || exit 1"

    write-install
    Copy-Item "pthread.h" "$DEPS_DIR\include" >> $log_file 2>&1
    Copy-Item "sched.h" "$DEPS_DIR\include" >> $log_file 2>&1
    Copy-Item "semaphore.h" "$DEPS_DIR\include" >> $log_file 2>&1
    Copy-Item "_ptw32.h" "$DEPS_DIR\include" >> $log_file 2>&1
    Copy-Item "pthreadVC3.lib" "$DEPS_DIR\lib" >> $log_file 2>&1
    Copy-Item "pthreadVC3.dll" "$DEPS_DIR\bin" >> $log_file 2>&1
    Copy-Item "pthreadVC3.pdb" "$DEPS_DIR\bin" >> $log_file 2>&1
    write-done
    Pop-Location
}

function download-php {
    write-library "PHP" $PHP_VER
    write-download

    $file = download-file "https://github.com/php/php-src/archive/$PHP_GIT_REV.zip" "php"
    write-extracting
    unzip-file $file $pwd
    Move-Item "php-src-$PHP_GIT_REV" $SOURCES_PATH >> $log_file 2>&1
    write-done
}

function download-php-extensions {
    # Khronos parity: build.sh clones ext-pmmpthread branch "fork" and
    # ext-yaml from master. Explicit target folder names ("pmmpthread",
    # "yaml") keep the ext/ layout identical to the Linux build.
    Push-Location "$SOURCES_PATH\ext" >> $log_file 2>&1

    write-library "php-ext pmmpthread" $PMMPTHREAD_BRANCH
    write-download
    (& cmd.exe /c "git clone --depth 1 --branch $PMMPTHREAD_BRANCH https://github.com/pmmp/ext-pmmpthread.git pmmpthread 2>&1") >> $log_file
    write-done

    write-library "php-ext yaml" "master"
    write-download
    (& cmd.exe /c "git clone --depth 1 https://github.com/php/pecl-file_formats-yaml.git yaml 2>&1") >> $log_file
    write-done

    Pop-Location
}

download-sdk

kh-echo "Checking that SDK can find Visual Studio"
#using CMAKE_TARGET for this is a bit meh but it's human readable at least
sdk-command "exit /b 0" "Please install $CMAKE_TARGET"

$DEPS_DIR="$BASE_PATH\deps-php-$PHP_VERSION_BASE-$($OUT_PATH_REL.ToLower())"
#custom libs depend on some standard libs, so prepare these first
#a bit annoying because this part of the build is slow and makes it take longer to find problems
download-php-deps

mkdir $LIB_BUILD_DIR >> $log_file 2>&1
cd $LIB_BUILD_DIR >> $log_file 2>&1

build-pthreads4w
build-yaml

cd $BASE_PATH >> $log_file 2>&1

download-php
download-php-extensions

cd "$SOURCES_PATH"
write-library "PHP" $PHP_VER
write-configure

# Extension set mirrors KhronosDevs/php-binaries build.sh (Linux):
#   cli, zts, ffi, sockets, pmmpthread, yaml, curl, openssl, mbstring, gmp,
#   zlib, phar, zip, bcmath, ctype, sqlite3, pdo, pdo-sqlite, mysqlnd,
#   mysqli, pdo-mysql, opcache.
# Windows specifics:
#   - ffi/openssl/sqlite3/pmmpthread are shared (DLL); on Linux they are
#     static. The generated php.ini loads them, so runtime parity holds.
#   - gmp resolves through the mpir package of the php-sdk deps (vs16).
#   - libffi and libzip are part of the php-sdk deps catalog.
sdk-command "buildconf.bat"
sdk-command "configure^`
    --with-mp=auto^`
    --with-prefix=khronos-php-bin^`
    --with-php-build=`"$DEPS_DIR`"^`
    --$PHP_HAVE_DEBUG^`
    --disable-all^`
    --disable-cgi^`
    --enable-cli^`
    --enable-zts^`
    --enable-bcmath^`
    --enable-ctype^`
    --enable-ffi=shared^`
    --enable-mbstring^`
    --enable-mysqlnd^`
    --enable-opcache^`
    --enable-opcache-jit=$PHP_JIT_ENABLE_ARG^`
    --enable-pdo^`
    --enable-phar^`
    --enable-sockets^`
    --enable-zip^`
    --enable-zlib^`
    --with-curl^`
    --with-gmp^`
    --with-iconv^`
    --with-mysqli^`
    --with-openssl^`
    --with-pcre-jit^`
    --with-pdo-mysql^`
    --with-pdo-sqlite^`
    --with-pmmpthread=shared^`
    --with-pmmpthread-sockets^`
    --with-sqlite3=shared^`
    --with-yaml^`
    --without-readline"

write-compile
sdk-command "nmake"

write-install
sdk-command "nmake snap"

#remove ICU DLLs copied unnecessarily by nmake snap
Remove-Item "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-$PHP_DISPLAY_VER\icu*.dll" >> $log_file 2>&1
#remove enchant dependencies which are unnecessarily copied
Remove-Item "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-$PHP_DISPLAY_VER\glib-*.dll" >> $log_file 2>&1
Remove-Item "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-$PHP_DISPLAY_VER\gmodule-*.dll" >> $log_file 2>&1
Remove-Item -Recurse "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-$PHP_DISPLAY_VER\lib\enchant\" >> $log_file 2>&1

cd $outpath >> $log_file 2>&1
Move-Item -Force "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-debug-pack-*.zip" $outpath
Remove-Item -Recurse bin -ErrorAction Continue >> $log_file 2>&1

# Khronos layout: php.exe, php.ini and ext\ live in bin\php7\bin, matching
# start.cmd ("bin\php7\bin\php.exe") and the Linux artifact (bin/php7/bin/php).
mkdir bin\php7\bin >> $log_file 2>&1
Move-Item "$SOURCES_PATH\$ARCH\$($OUT_PATH_REL)_TS\php-$PHP_DISPLAY_VER\*" bin\php7\bin >> $log_file 2>&1

$php_exe = "$outpath\bin\php7\bin\php.exe"

if (!(Test-Path $php_exe)) {
    kh-fatal-error "Something went wrong. php.exe not found"
}

write-status "generating php.ini"

$php_ini_dir="$outpath\bin\php7\bin"
$ext_dir="$php_ini_dir\ext"

# Enumerate the shared extensions that ACTUALLY exist in ext\ after the
# build. Static extensions (sockets, mbstring, yaml, zlib, ...) are always
# available and must not be listed. This makes it impossible for the ini to
# reference a DLL that doesn't exist (the exact bug the old workflow had).
$ext_lines = @()
foreach ($dll in (Get-ChildItem "$ext_dir\*.dll" | Sort-Object Name)) {
    if ($dll.Name -eq "php_opcache.dll") {
        continue #handled as zend_extension below
    }
    kh-echo "Shared extension: $($dll.Name)"
    $ext_lines += "extension=" + $dll.Name
}
$zend_lines = @()
if ($PHP_VERSION_ID -lt 80500) {
    $zend_lines += "zend_extension=php_opcache.dll"
}
$ext_block = ""
if ($ext_lines.Count -gt 0) { $ext_block = $ext_block + ($ext_lines -join "`r`n") + "`r`n" }
if ($zend_lines.Count -gt 0) { $ext_block = $ext_block + ($zend_lines -join "`r`n") + "`r`n" }

# Khronos ini settings, mirrored from KhronosDevs/php-binaries php-production.ini
$ini_part_a = @'
;Khronos php.ini (generated by windows-compile-vs.ps1)
;Settings mirrored from KhronosDevs/php-binaries php-production.ini (PHP 8.2 ZTS)

[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = Off
zlib.output_compression = Off
implicit_flush = Off
serialize_precision = -1

; realpath_cache stores resolved filesystem paths
realpath_cache_size = 8M
realpath_cache_ttl = 3600

; Circular reference Garbage Collector
zend.enable_gc = On

; Disable assertions in production for zero runtime overhead
zend.assertions = -1

zend.exception_ignore_args = On
zend.exception_string_param_max_len = 0

expose_php = Off

max_execution_time = 0
max_input_time = -1
memory_limit = -1

error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE
display_errors = Off
display_startup_errors = Off
log_errors = On
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On

variables_order = "GPCS"
request_order = "GP"
register_argc_argv = On
auto_globals_jit = On

post_max_size = 8M
default_mimetype = "text/html"
default_charset = "UTF-8"

user_ini.filename =
user_ini.cache_ttl = 300

; Windows layout: php.exe, php.ini and ext\ all live in bin\php7\bin
extension_dir = "ext"
enable_dl = Off

file_uploads = Off

allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

'@

$ini_part_b = @'
[ffi]
ffi.enable = true
ffi.cache_check = 0

[CLI Server]
cli_server.color = On

[Date]
date.timezone = UTC

[Pcre]
pcre.backtrack_limit = 1000000
pcre.recursion_limit = 1000000
pcre.jit = 1

[Phar]
phar.readonly = On
phar.require_hash = On

[opcache]
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 64
opcache.max_accelerated_files = 30000
opcache.max_wasted_percentage = 10
opcache.use_cwd = 1
; Disable timestamp validation in production to eliminate stat() disk I/O
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0
; Preserve PHPDoc comments and Attributes for reflection
opcache.save_comments = 1
opcache.record_warnings = 0
opcache.enable_file_override = 1
opcache.optimization_level = 0x7FFFBFFF
opcache.max_file_size = 0
opcache.consistency_checks = 0
opcache.force_restart_timeout = 180
opcache.protect_memory = 0
opcache.huge_code_pages = 0
opcache.file_update_protection = 0
; Prevent sharing SHM between different PHP binaries - they won't work because of ASLR
opcache.cache_id = KhronosPHP

[JIT]
; Tracing JIT for hot tick loops (requires a build with PHP_JIT_SUPPORT=1)
opcache.jit = tracing
opcache.jit_buffer_size = 128M
opcache.jit_hot_loop = 64
opcache.jit_hot_func = 127
opcache.jit_hot_return = 8
opcache.jit_hot_side_exit = 8
'@

# Development overrides per the php-binaries README (production vs development table)
$ini_dev_overrides = @'

; ---- development overrides (php.ini-development only) ----
error_reporting = E_ALL
display_errors = On
display_startup_errors = On
zend.assertions = 1
zend.exception_ignore_args = Off
phar.readonly = Off
opcache.validate_timestamps = 1
opcache.memory_consumption = 128M
opcache.jit_buffer_size = 64M
'@

function write-khronos-ini {
    param ([string] $file, [bool] $dev)

    $content = $ini_part_a + $ext_block + $ini_part_b
    if ($dev) {
        $content = $content + $ini_dev_overrides
    }

    Out-File -FilePath $file -Encoding ascii -InputObject $content
}

write-khronos-ini "$php_ini_dir\php.ini" $false
write-khronos-ini "$php_ini_dir\php.ini-production" $false
write-khronos-ini "$php_ini_dir\php.ini-development" $true

write-done

kh-echo "Running smoke test"

& $php_exe -v
if ($LASTEXITCODE -ne 0) {
    kh-fatal-error "php -v failed"
}

$required = @("FFI", "pmmpthread", "sockets", "mbstring", "yaml", "zlib", "json", "phar", "curl", "PDO", "sqlite3", "mysqlnd", "Zend OPcache")
$mods = & $php_exe -m
$missing = @()
foreach ($m in $required) {
    if ((($mods | Select-String -SimpleMatch $m) | Measure-Object).Count -eq 0) {
        $missing += $m
    }
}
if ($missing.Count -gt 0) {
    kh-fatal-error "Missing extensions: $($missing -join ', ')"
}

$ts = (& $php_exe -i 2>$null | Select-String "Thread Safety" | Out-String)
if ($ts -notmatch "enabled") {
    kh-fatal-error "ZTS (Thread Safety) is not enabled"
}

kh-echo "Smoke test passed"
kh-echo "NOTE: You may need to install the VC++ Redistributable for the binaries to work. Download it here: https://aka.ms/vs/16/release/vc_redist.x64.exe"
kh-echo "PHP binary files installed in $outpath\bin\php7\bin"
kh-echo "If the binary doesn't work, please report an issue at https://github.com/KhronosDevs/php-binaries and attach the `"compile.log`" file"
