#!/bin/bash
# build.sh - cross-build git for RenkuOS arm64 and package it as git-<ver>-<rev>-arm64.hpkg.
#
# Runs on Linux inside a Haiku arm64 build environment (the haiku-builder
# container). It needs:
#   GEN       a Haiku arm64 "generated" directory with cross-tools-arm64 and
#             the host "package" tool (jam -q '<build>package')
#   SYSROOT   a sysroot with haiku, haiku_devel and gcc_syslibs(_devel)
#             extracted under boot/system (see README)
#   WORK      scratch directory (default /root/fc/git)
#
# The RenkuOS arm64 repositories ship curl, openssl3 and zlib, but no
# curl_devel, so the curl/openssl3/zlib packages (and openssl3_devel,
# zlib_devel) are extracted into the sysroot here and curl's public headers
# are taken from the curl source of the same version. There is no expat,
# pcre2, gettext, libiconv, perl, python or tcl/tk on arm64: git is built
# without them (no "http-push", no "git grep -P", English only, no git-gui,
# no git-svn/send-email/cvs), and links only against libroot, libnetwork,
# libbsd, libcurl, libssl/libcrypto and libz.
#
# Haiku-specific changes come from HaikuPorts (dev-vcs/git, git-<ver>.patchset)
# and the make flags follow its git recipe.
set -euo pipefail

VERSION=${VERSION:-2.56.0}
REVISION=${REVISION:-1}
CURL_VERSION=${CURL_VERSION:-8.22.0}
GEN=${GEN:-/root/renku-arm64-work/generated.arm64}
SYSROOT=${SYSROOT:-/root/fc/sysroot}
WORK=${WORK:-/root/fc/git}
HERE=$(cd "$(dirname "$0")" && pwd)

X=$GEN/cross-tools-arm64/bin/aarch64-unknown-haiku
PKG=$GEN/objects/linux/arm64/release/tools/package/package
export LD_LIBRARY_PATH=$GEN/objects/linux/lib
DL=$GEN/download
S=$SYSROOT/boot/system

mkdir -p "$WORK/src"
cd "$WORK/src"

# 1. runtime + devel packages into the sysroot
for p in curl-$CURL_VERSION-2-arm64 openssl3-3.5.4-1-arm64 openssl3_devel-3.5.4-1-arm64 \
		zlib-1.2.13_bootstrap-1-arm64 zlib_devel-1.2.13_bootstrap-1-arm64; do
	[ -d "x/$p" ] || { mkdir -p "x/$p"; "$PKG" extract -C "x/$p" "$DL/$p.hpkg"; }
	[ -d "x/$p/lib" ] && cp -a "x/$p/lib/." "$S/lib/"
	[ -d "x/$p/develop" ] && cp -a "x/$p/develop/." "$S/develop/"
done
ln -sfn ../../lib/libcurl.so.4 "$S/develop/lib/libcurl.so"

# 2. sources
[ -f git-$VERSION.tar.xz ] || curl -fsSLO https://www.kernel.org/pub/software/scm/git/git-$VERSION.tar.xz
[ -f git-manpages-$VERSION.tar.xz ] || curl -fsSLO https://www.kernel.org/pub/software/scm/git/git-manpages-$VERSION.tar.xz
[ -f curl-$CURL_VERSION.tar.xz ] || curl -fsSLO https://curl.se/download/curl-$CURL_VERSION.tar.xz
sha256sum -c "$HERE/SHA256SUMS"
rm -rf git-$VERSION curl-$CURL_VERSION
tar xf git-$VERSION.tar.xz
tar xf curl-$CURL_VERSION.tar.xz curl-$CURL_VERSION/include
cd git-$VERSION
patch -p1 -s < "$HERE/patches/git-$VERSION.patchset"

# 3. build
prefix=/boot/system
makeGit() {
	make prefix=$prefix \
		uname_S=Haiku uname_M=arm64 uname_O=Haiku uname_R=1 uname_V=1 \
		CC="$X-gcc --sysroot=$SYSROOT" AR="$X-ar" STRIP="$X-strip" \
		bindir_relative=bin \
		mandir=$prefix/documentation/man \
		infodir=$prefix/documentation/info \
		gitexecdir=$prefix/lib/git-core \
		sharedir=$prefix/data \
		template_dir=$prefix/data/git-core/templates \
		htmldir=$prefix/documentation/packages/git \
		sysconfdir=$prefix/settings \
		PTHREAD_LIBS= \
		NO_D_TYPE_IN_DIRENT=YesPlease \
		NO_MEMMEM=YesPlease \
		NO_ICONV=YesPlease \
		NO_GETTEXT=YesPlease \
		NO_EXPAT=YesPlease \
		NO_PERL=YesPlease \
		NO_PYTHON=YesPlease \
		NO_TCLTK=YesPlease \
		NO_RUST=YesPlease \
		CURL_CFLAGS="-I$WORK/src/curl-$CURL_VERSION/include" \
		CURL_LDFLAGS="-lcurl" \
		OPENSSLDIR= NEEDS_SSL_WITH_CRYPTO=YesPlease \
		OBJECT_CREATION_USES_RENAMES=YesPlease \
		NO_CROSS_DIRECTORY_HARDLINKS=YesPlease \
		NO_INSTALL_HARDLINKS=YesPlease \
		INSTALL_SYMLINKS=YesPlease \
		HAVE_DEV_TTY=YesPlease \
		DEFAULT_PAGER=less \
		DEFAULT_HELP_FORMAT=man \
		SHELL_PATH=/bin/sh \
		BASIC_LDFLAGS="-lnetwork -lbsd" \
		CPPFLAGS="-D_POSIX_THREAD_SAFE_FUNCTIONS" \
		"$@"
}
makeGit -j"$(nproc)" all
makeGit strip

# 4. install into the package root
R=$WORK/pkgroot
rm -rf "$R"
makeGit install DESTDIR="$R" >/dev/null
P=$R$prefix
mv "$P"/* "$R"/
rm -rf "$R/boot"
# drop the gui/perl leftovers and share/ (bash completion goes to data/)
rm -rf "$R/share" "$R/bin/gitk" "$R/lib/git-core/git-gui"* "$R/lib/git-core/git-citool"
# NO_PERL/NO_PYTHON leave stubs that only print "built without support"
find "$R/bin" "$R/lib/git-core" -type f -size -2k \
	-exec grep -q "git was built without support" {} \; -delete
find "$R/bin" "$R/lib/git-core" -xtype l -delete
mkdir -p "$R/documentation/man"
tar -C "$R/documentation/man" -xf ../git-manpages-$VERSION.tar.xz
install -d "$R/data/bash-completion/completions"
install -m 644 contrib/completion/git-completion.bash "$R/data/bash-completion/completions/git"
mkdir -p "$R/settings"
printf '[core]\n\tuntrackedCache = true\n' > "$R/settings/gitconfig"
mkdir -p "$R/data/licenses"
cp COPYING "$R/data/licenses/git"
cat > "$R/.PackageInfo" <<INFO
name		git
version		$VERSION-$REVISION
architecture	arm64
summary		"Fast, scalable, distributed revision control system"
description	"Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency. This RenkuOS arm64 build talks HTTPS through libcurl/OpenSSL; it has no Perl, Python or Tcl/Tk parts (no git-gui, git-svn, send-email) and no PCRE, gettext or iconv support."
packager	"rainygirl"
vendor		"RENKU"
copyrights {
	"2005-2026 Git Authors (see git web site for list)"
}
licenses {
	"GNU GPL v2"
}
provides {
	git = $VERSION compat >= 2.3
	cmd:git = $VERSION compat >= 2.3
	cmd:git_receive_pack = $VERSION compat >= 2.3
	cmd:git_shell = $VERSION compat >= 2.3
	cmd:git_upload_archive = $VERSION compat >= 2.3
	cmd:git_upload_pack = $VERSION compat >= 2.3
	cmd:scalar = $VERSION compat >= 2.3
}
requires {
	haiku
	lib:libcurl
	lib:libssl >= 3
	lib:libcrypto >= 3
	lib:libz
	cmd:less
}
global-writable-files {
	"settings/gitconfig" keep-old
}
user-settings-files {
	"settings/git" directory
}
INFO
mkdir -p "$HERE/dist"
OUT=$HERE/dist/git-$VERSION-$REVISION-arm64.hpkg
rm -f "$OUT"
(cd "$R" && "$PKG" create -z zlib -9 "$OUT")
ls -la "$OUT"
