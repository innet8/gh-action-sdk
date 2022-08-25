#!/bin/bash

set -ef

FEEDNAME="${FEEDNAME:-action}"
BUILD_LOG="${BUILD_LOG:-1}"

cd /home/build/openwrt/

if [ -z "$NO_DEFAULT_FEEDS" ]; then
    sed \
        -e 's,https://git.openwrt.org/feed/,https://github.com/openwrt/,' \
        -e 's,https://git.openwrt.org/openwrt/,https://github.com/openwrt/,' \
        -e 's,https://git.openwrt.org/project/,https://github.com/openwrt/,' \
        feeds.conf.default > feeds.conf
fi

echo "src-link $FEEDNAME /feed/" >> feeds.conf

ALL_CUSTOM_FEEDS=
#shellcheck disable=SC2153
for EXTRA_FEED in $EXTRA_FEEDS; do
    echo "$EXTRA_FEED" | tr '|' ' ' >> feeds.conf
    ALL_CUSTOM_FEEDS+="$(echo "$EXTRA_FEED" | cut -d'|' -f2) "
done
ALL_CUSTOM_FEEDS+="$FEEDNAME"

cat feeds.conf

./scripts/feeds update -a > /dev/null
make defconfig > /dev/null

for DEP in $DEPENDENCES; do
    ./scripts/feeds install "$DEP"
done

if [ -z "$PKG" ]; then
    echo "need PKG"
    exit 0
else
    git clone -b $BRANCH $ADDR package/$PKG
    make \
        BUILD_LOG="$BUILD_LOG" \
        IGNORE_ERRORS="$IGNORE_ERRORS" \
        V=s \
        "package/$PKG/compile" || {
            RET=$?
            make "package/$PKG/compile" V=s -j 1
            exit $RET
        }
fi

find "bin/" -type f -name "*.ipk" -exec cp -f {} "/artifacts" \;