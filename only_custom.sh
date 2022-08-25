#!/bin/bash

set -ef

FEEDNAME="${FEEDNAME:-action}"
BUILD_LOG="${BUILD_LOG:-1}"

cd /home/build/openwrt/

if [ -n "$KEY_BUILD" ]; then
	echo "$KEY_BUILD" > key-build
	SIGNED_PACKAGES="y"
fi

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

if [ -z "$PACKAGES" ]; then
    echo "need PACKAGES"
    exit 0
else
    for PKG in $PACKAGES; do
        make \
			BUILD_LOG="$BUILD_LOG" \
			IGNORE_ERRORS="$IGNORE_ERRORS" \
			V="$V" \
			-j "$(nproc)" \
			"package/$PKG/compile" || {
				RET=$?
				make "package/$PKG/compile" V=s -j 1
				exit $RET
			}
    done
fi

if [ -d bin/ ]; then
	mv bin/ /artifacts/
fi

if [ -d logs/ ]; then
	mv logs/ /artifacts/
fi
