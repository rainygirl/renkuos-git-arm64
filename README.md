# Git for RenkuOS arm64

English · [한국어](README.ko.md)

Git 2.56.0 built for RenkuOS (Haiku) on arm64. The RenkuOS arm64 repositories
had no git, so tools that drive it, such as lazygit, could not work there.
Unofficial build, not affiliated with the Git project.

| Package | Version | Commands |
| --- | --- | --- |
| `git` | 2.56.0 | `git`, `git-shell`, `git-upload-pack`, `git-receive-pack`, `git-upload-archive`, `scalar` |

## Install

From the RENKU Apps repository:

```sh
pkgman install git
```

From a package file:

```sh
pkgman install ./git-2.56.0-1-arm64.hpkg
```

It needs `curl`, `openssl3`, `zlib` and `less`, which every RenkuOS arm64
image already has.

## What works, what does not

- Local work (init, add, commit, log, diff, branch, merge, rebase, stash, ...)
  and HTTPS remotes (clone, fetch, push) through libcurl and OpenSSL 3.
- SSH remotes use the system `ssh` (openssh).
- Not included, because arm64 has no Perl, Python or Tcl/Tk: git-gui, gitk,
  git-svn, git-send-email, git-cvsimport, git-p4, gitweb.
- Built without PCRE2 (`git grep -P`), expat (`git http-push`), gettext
  (English messages only) and iconv (`i18n.commitEncoding` other than UTF-8).
- No editor ships on arm64, so set one before running `git commit` without
  `-m` (`git config --global core.editor <editor>`), or commit with `-m`.

Settings follow HaikuPorts: the user config is
`~/config/settings/git/config`, the system config
`/boot/system/settings/gitconfig`.

## Build

`build.sh` cross-builds git with the Haiku arm64 cross compiler and packages
it. It runs on Linux in a Haiku arm64 build environment (the `haiku-builder`
container):

```sh
GEN=/root/renku-arm64-work/generated.arm64 SYSROOT=/root/fc/sysroot ./build.sh
# -> dist/git-2.56.0-1-arm64.hpkg
```

- `GEN` is a Haiku arm64 `generated` directory with `cross-tools-arm64`, the
  host `package` tool and the downloaded HaikuPorts packages in `download/`.
- `SYSROOT` holds `haiku`, `haiku_devel`, `gcc_syslibs` and
  `gcc_syslibs_devel` extracted under `boot/system`. The script adds the
  `curl`, `openssl3`, `openssl3_devel`, `zlib` and `zlib_devel` packages to
  it; curl's headers come from the curl 8.22.0 source, as there is no
  `curl_devel` for arm64.
- The patches are HaikuPorts' `dev-vcs/git` patchset, unchanged, and the make
  flags follow its recipe. `SHA256SUMS` pins the source archives.

## License

The scripts and documentation are MIT, see [LICENSE](LICENSE). Git itself is
GPL-2.0.
