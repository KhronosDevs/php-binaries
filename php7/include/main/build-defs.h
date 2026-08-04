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

#define CONFIGURE_COMMAND " './configure'  '--prefix=/usr' '--sbindir=/usr/bin' '--localstatedir=/var' '--with-layout=GNU' '--disable-debug' '--mandir=/usr/share/man' '--srcdir=../php-8.2.32' '--libdir=/usr/lib/php82' '--datadir=/usr/share/php82' '--program-suffix=82' '--with-config-file-scan-dir=/etc/php82/conf.d' '--enable-filter' '--enable-session' '--with-pear' '--with-mhash=/usr' '--with-kerberos' '--with-mysql-sock=/run/mysqld/mysqld.sock' '--enable-mysqlnd-compression-support' '--datarootdir=/usr/share/php82' '--with-zlib' '--with-libxml' '--with-pcre-jit' '--with-external-pcre=/usr' '--with-password-argon2=/usr' '--disable-rpath' '--config-cache' '--with-system-tzdata' '--enable-phpdbg-readline' '--with-libedit' '--enable-zts' '--sysconfdir=/etc/php82' '--with-config-file-path=/etc/php82' '--enable-cli' '--enable-xml=shared' '--with-xsl=shared' '--enable-xmlreader=shared' '--enable-xmlwriter=shared' '--enable-dom=shared' '--enable-simplexml=shared' '--with-openssl=shared' '--enable-pdo=shared' '--enable-mysqlnd=shared' '--with-mysqli=shared,mysqlnd' '--with-pdo-mysql=shared,mysqlnd' '--enable-phar=shared' '--enable-pcntl=shared' '--enable-posix=shared' '--enable-shmop=shared' '--enable-sockets=shared' '--enable-sysvmsg=shared' '--enable-sysvsem=shared' '--enable-sysvshm=shared' '--enable-tokenizer=shared' '--enable-dba=shared' '--with-db4=/usr' '--without-gdbm' '--with-cdb' '--with-lmdb=/usr' '--with-pgsql=shared,/usr' '--with-pdo-pgsql=shared,/usr' '--with-unixODBC=shared' '--with-pdo-odbc=shared,unixODBC,/usr' '--with-pdo-firebird=shared,/usr' '--with-pdo-dblib=shared,/usr' '--with-pdo-sqlite=shared,/usr' '--with-sqlite3=shared' '--enable-gd=shared' '--with-external-gd=/usr' '--with-jpeg' '--with-xpm' '--with-webp' '--with-freetype' '--enable-exif=shared' '--with-tidy=shared,/usr' '--with-iconv=shared' '--enable-bcmath=shared' '--with-gmp=shared,/usr' '--with-zip=shared' '--with-bz2=shared,/usr' '--enable-fileinfo=shared' '--enable-ctype=shared' '--enable-mbstring=shared' '--with-onig=/usr' '--enable-mbregex' '--with-pspell=shared,/usr' '--with-enchant=shared' '--enable-intl=shared' '--enable-calendar=shared' '--with-gettext=shared,/usr' '--enable-soap=shared' '--enable-ftp=shared' '--with-curl=shared' '--with-snmp=shared,/usr' '--with-ldap=shared,/usr' '--with-ldap-sasl' '--with-sodium=shared' '--with-ffi=shared' '--enable-opcache' '--enable-huge-code-pages' '--enable-phpdbg' '--enable-cgi' '--enable-embed=shared' '--enable-fpm' '--with-fpm-user=http' '--with-fpm-group=http' '--with-fpm-systemd' '--with-fpm-acl' '--enable-litespeed' 'CFLAGS=-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -g -ffile-prefix-map=/build/php-82/src=/usr/src/debug/php82 -fPIC -Wno-error=incompatible-pointer-types' 'LDFLAGS=-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs' 'CPPFLAGS= -DU_USING_ICU_NAMESPACE=1 ' 'CXXFLAGS=-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -Wp,-D_GLIBCXX_ASSERTIONS -g -ffile-prefix-map=/build/php-82/src=/usr/src/debug/php82 -fPIC -Wno-error=incompatible-pointer-types -std=c++17'"
#define PHP_ODBC_CFLAGS	""
#define PHP_ODBC_LFLAGS		""
#define PHP_ODBC_LIBS		"-lodbc"
#define PHP_ODBC_TYPE		"unixODBC"
#define PHP_OCI8_DIR			""
#define PHP_OCI8_ORACLE_VERSION		""
#define PHP_PROG_SENDMAIL	"/bin/sendmail"
#define PEAR_INSTALLDIR         "/usr/share/php82/pear"
#define PHP_INCLUDE_PATH	".:/usr/share/php82/pear"
#define PHP_EXTENSION_DIR       "/usr/lib/php82/modules"
#define PHP_PREFIX              "/usr"
#define PHP_BINDIR              "/usr/bin"
#define PHP_SBINDIR             "/usr/bin"
#define PHP_MANDIR              "/usr/share/man"
#define PHP_LIBDIR              "/usr/lib/php82"
#define PHP_DATADIR             "/usr/share/php82"
#define PHP_SYSCONFDIR          "/etc/php82"
#define PHP_LOCALSTATEDIR       "/var"
#define PHP_CONFIG_FILE_PATH    "/etc/php82"
#define PHP_CONFIG_FILE_SCAN_DIR    "/etc/php82/conf.d"
#define PHP_SHLIB_SUFFIX        "so"
#define PHP_SHLIB_EXT_PREFIX    ""
