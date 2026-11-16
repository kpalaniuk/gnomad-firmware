#!/usr/bin/env bash
# Gnomad, a fork of Felucca (see FORK.md). Not part of upstream Felucca.
# The release build on GitHub's own runners, for The Firmware Hub's shared workflow (zvenson/fm1-build, which
# provides the AC79 SDK and attests the result) or any x86-64 Linux machine. The same steps and pins as
# Gnomad's firmware.yml (in the release's source tarball):
#   - JieLi's toolchain 20250805.1 at its pinned SHA-256 (fm1-build fetches JieLi's newest; another compiler
#     makes other bytes), Pillow 12.3.0 and fontTools
#   - the build's name: "GNOMAD V1 <commit>", the commit's hex digits as many as fit the editor's 24
#   - SOURCE_DATE_EPOCH: the commit's time unless set (the ABOUT page's date, through a clang wrapper), so the same
#     commit always makes the same bytes
#   - ./build.sh, then the package with the update loader of Felucca's released 1.0.1 package
#     (.github/ci/released_package.py: installing a package runs that package's own loader)
#
#   tools/gn_ci_build.sh [COMMIT]      COMMIT: the hex the name carries (default: HEAD)
#
# Writes build/gnomad-v1-<7 hex>.fwsc. With COMMIT 115e11e it rebuilds release 12, whose SHA-256 is
# 8bab81bb3cf3a197a7f9c7a4b07ae962a45a2ae90b85bd88ae267fc2a707d052.
set -euo pipefail
cd "$(dirname "$0")/.."

TC_URL=https://jl-update.oss-cn-shenzhen.aliyuncs.com/jieli-linux-toolchains-20250805.1.tar.xz
TC_SHA256=f686586bcfb45e0f0bb27fd2b39c7a7f313cb4f0e88a66a14da621ffa8225958
UPSTREAM=https://github.com/hugelton/Felucca/releases/download/v1.0.1/felucca-1.0.1.fwsc
UPSTREAM_SHA256=7ff22a3532e75b881de0f879b5103387fb666980766f1768d8b8012e067e8fae
UPSTREAM_SIZE=609849
LOADER_SHA256=e671adf0ce6e4f69ac8514087c8833b1969fa4c470645786f19968e90b9a630f
MILESTONE=V1

python3 -m pip install --disable-pip-version-check --quiet "Pillow==12.3.0" fonttools

tc_root="$HOME/.jieli-gnomad"
if [ ! -x "$tc_root/toolchain/pi32v2/bin/clang" ]; then
    rm -rf "$tc_root" && mkdir -p "$tc_root"
    curl -fsSL --retry 3 -o "$tc_root/tc.tar.xz" "$TC_URL"
    echo "$TC_SHA256  $tc_root/tc.tar.xz" | sha256sum -c -
    tar -xJf "$tc_root/tc.tar.xz" -C "$tc_root" && rm "$tc_root/tc.tar.xz"
    ln -sfn "$(basename "$(ls -d "$tc_root"/jieli-linux-toolchains-* | sort | tail -1)")" "$tc_root/toolchain"
fi
"$tc_root/toolchain/pi32v2/bin/clang" --version | head -1

commit="${1:-$(git rev-parse HEAD)}"
# the ABOUT page's __DATE__ from SOURCE_DATE_EPOCH, not the clock (JieLi's clang 4 does not read the variable):
# a view of the toolchain whose clang adds it, so tools/build.py stays upstream's bytes (gn_protected.py)
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}"
date=$(LC_ALL=C date -u -d "@$SOURCE_DATE_EPOCH" '+%b %e %Y')
view="$tc_root/dated"
rm -rf "$view" && mkdir -p "$view/pi32v2/bin"
for e in "$tc_root/toolchain"/*; do [ "$(basename "$e")" = pi32v2 ] || ln -s "$e" "$view/"; done
for e in "$tc_root/toolchain/pi32v2"/*; do [ "$(basename "$e")" = bin ] || ln -s "$e" "$view/pi32v2/"; done
for e in "$tc_root/toolchain/pi32v2/bin"/*; do ln -s "$e" "$view/pi32v2/bin/"; done
rm "$view/pi32v2/bin/clang"
printf '#!/bin/sh\nexec %s "$@" -Wno-builtin-macro-redefined '\''-D__DATE__="%s"'\''\n' \
    "$(readlink -f "$tc_root/toolchain/pi32v2/bin/clang")" "$date" > "$view/pi32v2/bin/clang"
chmod +x "$view/pi32v2/bin/clang"
export JIELI_TOOLCHAIN="$view"
echo "__DATE__ \"$date\" (SOURCE_DATE_EPOCH $SOURCE_DATE_EPOCH)"
name=$(sed -n 's/^#define GN_NAME "\([A-Z0-9]*\)".*/\1/p' firmware/src/gn_hooks.h)
digits=$((24 - 8 - ${#name} - 1 - ${#MILESTONE} - 1))
[ "$digits" -le 6 ] || digits=6
version="$name $MILESTONE ${commit:0:$digits}"
tag="gnomad-${MILESTONE,,}-${commit:0:7}"
mkdir -p build/gen
printf '#define FELUCCA_VERSION "%s"\n' "$version" > build/gen/gn_name.h
echo "building \"FELUCCA $version\" as $tag"

./build.sh
grep -aq "FELUCCA $version" build/felucca.bin || { echo "the image does not carry \"FELUCCA $version\""; exit 1; }

curl -fsSL --retry 3 -o build/felucca-1.0.1.fwsc "$UPSTREAM"
python3 .github/ci/released_package.py build/felucca-1.0.1.fwsc "$UPSTREAM_SHA256" "$UPSTREAM_SIZE" \
    "$LOADER_SHA256" "build/$tag.fwsc" build/upstream-loader-ota.bin
cmp build/loader/ota.bin build/upstream-loader-ota.bin
rm build/felucca-1.0.1.fwsc build/upstream-loader-ota.bin
sha256sum "build/$tag.fwsc"
