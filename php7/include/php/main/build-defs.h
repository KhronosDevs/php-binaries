/*
   +----------------------------------------------------------------------+
   | Copyright (c) The PHP Group                                          |
   +----------------------------------------------------------------------+
   | This source file is subject to version 3.01 of the PHP license,      |
   | that is bundled with this package in the file LICENSE, and is        |
   | available through the world-wide-web at the following url:           |
   | https://www.php.net/license/3_01.txt                                 |
   | If you did not receive a copy of the PHP license and are unable to   |
   | obtain it through the world-wide-web, please send a note to          |
   | license@php.net so we can mail you a copy immediately.               |
   +----------------------------------------------------------------------+
   | Author: Stig Sæther Bakken <ssb@php.net>                             |
   +----------------------------------------------------------------------+
*/

#define CONFIGURE_COMMAND " './configure'  '--prefix=/build/dist/php7' '--disable-all' '--enable-cli' '--disable-cgi' '--enable-zts' '--enable-ffi' '--enable-sockets' '--enable-pmmpthread' '--enable-yaml' '--with-libyaml=/build/work/deps' '--with-curl=/build/work/deps' '--with-openssl=/build/work/deps' '--enable-mbstring' '--with-onig=/build/work/deps' '--with-gmp=/build/work/deps' '--with-zlib=/build/work/deps' '--enable-phar' '--with-zip=/build/work/deps' '--with-ffi=/build/work/deps' '--enable-bcmath' '--enable-ctype' '--with-sqlite3=/build/work/deps' '--enable-pdo' '--with-pdo-sqlite=/build/work/deps' '--enable-mysqlnd' '--with-mysqli=mysqlnd' '--with-pdo-mysql=mysqlnd' '--enable-opcache' 'PKG_CONFIG_PATH=/build/work/deps/lib/pkgconfig' 'PKG_CONFIG_LIBDIR=/build/work/deps/lib/pkgconfig'"
#define PHP_ODBC_CFLAGS	""
#define PHP_ODBC_LFLAGS		""
#define PHP_ODBC_LIBS		""
#define PHP_ODBC_TYPE		""
#define PHP_OCI8_DIR			""
#define PHP_OCI8_ORACLE_VERSION		""
#define PHP_PROG_SENDMAIL	"/usr/sbin/sendmail"
#define PEAR_INSTALLDIR         ""
#define PHP_INCLUDE_PATH	".:"
#define PHP_EXTENSION_DIR       "/build/dist/php7/lib/php/extensions/no-debug-zts-20220829"
#define PHP_PREFIX              "/build/dist/php7"
#define PHP_BINDIR              "/build/dist/php7/bin"
#define PHP_SBINDIR             "/build/dist/php7/sbin"
#define PHP_MANDIR              "/build/dist/php7/php/man"
#define PHP_LIBDIR              "/build/dist/php7/lib/php"
#define PHP_DATADIR             "/build/dist/php7/share/php"
#define PHP_SYSCONFDIR          "/build/dist/php7/etc"
#define PHP_LOCALSTATEDIR       "/build/dist/php7/var"
#define PHP_CONFIG_FILE_PATH    "/build/dist/php7/lib"
#define PHP_CONFIG_FILE_SCAN_DIR    ""
#define PHP_SHLIB_SUFFIX        "so"
#define PHP_SHLIB_EXT_PREFIX    ""
