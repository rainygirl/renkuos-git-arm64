# RenkuOS arm64용 Git

[English](README.md) · 한국어

Git 2.56.0을 RenkuOS(Haiku) arm64용으로 빌드한 것입니다. RenkuOS arm64
저장소에는 git이 없어서 lazygit처럼 git을 쓰는 도구가 동작하지 않았습니다.
비공식 빌드이며 Git 프로젝트와는 관련이 없습니다.

| 패키지 | 버전 | 명령 |
| --- | --- | --- |
| `git` | 2.56.0 | `git`, `git-shell`, `git-upload-pack`, `git-receive-pack`, `git-upload-archive`, `scalar` |

## 설치

RENKU Apps 저장소에서:

```sh
pkgman install git
```

패키지 파일로:

```sh
pkgman install ./git-2.56.0-1-arm64.hpkg
```

`curl`, `openssl3`, `zlib`, `less`가 필요하며 RenkuOS arm64 이미지에는 모두
기본으로 들어 있습니다.

## 되는 것과 안 되는 것

- 로컬 작업(init, add, commit, log, diff, branch, merge, rebase, stash 등)과
  libcurl/OpenSSL 3을 통한 HTTPS 원격 저장소(clone, fetch, push).
- SSH 원격 저장소는 시스템의 `ssh`(openssh)를 씁니다.
- arm64에는 Perl, Python, Tcl/Tk가 없어서 git-gui, gitk, git-svn,
  git-send-email, git-cvsimport, git-p4, gitweb은 빠져 있습니다.
- PCRE2(`git grep -P`), expat(`git http-push`), gettext(메시지는 영어만),
  iconv(UTF-8 이외의 `i18n.commitEncoding`) 없이 빌드했습니다.
- arm64에는 기본 편집기가 없으므로 `-m` 없이 `git commit`을 하려면 먼저
  편집기를 지정하세요(`git config --global core.editor <편집기>`). 아니면
  `-m`을 쓰세요.

설정 위치는 HaikuPorts와 같습니다. 사용자 설정은
`~/config/settings/git/config`, 시스템 설정은
`/boot/system/settings/gitconfig`입니다.

## 빌드

`build.sh`는 Haiku arm64 크로스 컴파일러로 git을 빌드하고 패키지로 만듭니다.
Haiku arm64 빌드 환경(`haiku-builder` 컨테이너)의 Linux에서 실행합니다.

```sh
GEN=/root/renku-arm64-work/generated.arm64 SYSROOT=/root/fc/sysroot ./build.sh
# -> dist/git-2.56.0-1-arm64.hpkg
```

- `GEN`은 `cross-tools-arm64`, 호스트용 `package` 도구, `download/`에 받아 둔
  HaikuPorts 패키지가 있는 Haiku arm64 `generated` 디렉터리입니다.
- `SYSROOT`에는 `haiku`, `haiku_devel`, `gcc_syslibs`, `gcc_syslibs_devel`을
  `boot/system` 아래에 풀어 둡니다. 스크립트가 여기에 `curl`, `openssl3`,
  `openssl3_devel`, `zlib`, `zlib_devel` 패키지를 더합니다. arm64용
  `curl_devel`이 없으므로 curl 헤더는 curl 8.22.0 소스에서 가져옵니다.
- 패치는 HaikuPorts `dev-vcs/git` 패치셋을 그대로 쓰고, make 옵션은 그
  레시피를 따릅니다. `SHA256SUMS`로 소스 아카이브를 고정합니다.

## 라이선스

스크립트와 문서는 MIT입니다([LICENSE](LICENSE)). Git 자체는 GPL-2.0입니다.
