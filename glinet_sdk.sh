#!/bin/bash

set -ef
targets="ar71xx-1806 ath79-1907 ramips-1806 ramips-1907 ipq806x-qsdk53 ipq_ipq40xx-qsdk11 ipq_ipq60xx-qsdk11 mvebu-1907 siflower-1806 ipq807x-2102"

gl_inet_imagebuilder_url="https://github.com/gl-inet-builder"
git config --global http.sslVerify false

usage() {
	cat <<-EOF
Usage: 
./download.sh [target]   # Download the appropriate SDK

All available target list:
    ar71xx-1806         # usb150/ar150/ar300m16/mifi/ar750/ar750s/x750/x1200
    ath79-1907          # usb150/ar150/ar300m/mifi/ar750/ar750s/x750/x300b/xe300/e750/x1200 openwrt-19.07.7 ath79 target
    ramips-1806         # mt300n-v2/mt300a/mt300n/n300/vixmini
    ramips-1907         # mt1300/mt300n-v2/mt300a/mt300n/n300/vixmini
    ipq806x-qsdk53      # b1300/s1300/ap1300/b2200
    ipq_ipq40xx-qsdk11  # b1300/s1300/ap1300/b2200 (version 3.201 and above)
    ipq_ipq60xx-qsdk11  # ax1800
    mvebu-1907          # mv1000
    siflower-1806       # sf1200/sft1200
    ipq807x-2102       # ax1800/axt1800 (version 4.x and above)

EOF
	exit 0
}

sdk_name=$ARCH
cd /home/build
download_sdk() {
    echo "Download $sdk_name SDK"
    version="${sdk_name#*-}"
    target="${sdk_name%-*}"
    # Download/Update OpenWrt SDK
    git clone --depth=1 $gl_inet_imagebuilder_url/openwrt-sdk-$sdk_name.git 
    cd openwrt-sdk-$sdk_name > /dev/null
    if [ $sdk_name == 'ipq807x-2102' ]; then
    	pushd build_dir/target-arm_cortex-a7_musl_eabi/linux-ipq807x_ipq60xx/linux-4.4.60-qsdk-11f09717303ecd83c3a64e9efe23f25921dc1016/scripts/basic/  > /dev/null
	[ -e 'fixdep' ] || ln -s .fixdep.bin fixdep
	popd  > /dev/null
	pushd build_dir/target-arm_cortex-a7_musl_eabi/linux-ipq807x_ipq60xx/linux-4.4.60-qsdk-11f09717303ecd83c3a64e9efe23f25921dc1016/scripts/mod/  > /dev/null
	[ -e 'modpost' ] || ln -s .modpost.bin modpost
	popd  > /dev/null
    fi
    sed -i '/routing/d' feeds.conf.default
    sed -i '/telephony/d' feeds.conf.default
    if [ -n "$FEEDNAME" ]; then
	echo "src-link $FEEDNAME /feed/" >> feeds.conf.default
    fi
    sed -i 's/19.07.7/19.07.8/g' feeds.conf.default
    ./scripts/feeds update 
    ./scripts/feeds install uci curl libubus libubox libiwinfo libsqlite3 mqtt fcgi 
    make defconfig
    printf "\nUse 'builder.sh script to compile all your packages.\nRun './builder.sh' to get more help.\n\n"
    if [ $version == 'qsdk11' ]; then
    	local n=$(grep -n '$(Build/Patch)' include/package-defaults.mk |awk -F':' '{print $1}')
		sed -i ''${n}' i \\t[ ! -d ./src/ ] || $(CP) ./src/. $(PKG_BUILD_DIR)' include/package-defaults.mk
    fi	

}

compile_sdk(){
    for DEP in $DEPENDENCES; do
        ./scripts/feeds install "$DEP"
    done
	if [ -n "$PACKAGES" ]; then
		for PKG in $PACKAGES; do
			./scripts/feeds install -p "$FEEDNAME" -f "$PKG"
		done
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
	else
		if [ -z "$PKG" ]; then
			echo "need PKG"
			exit 0
		else
			git clone -b $BRANCH $ADDR package/$PKG
			mkdir -p dl
			cp /home/build/mbedtls-2.12.0-gpl.tgz dl/
			cp /home/build/zlib-1.2.11.tar.xz dl/
			cp /home/build/openssl-1.1.1i.tar.gz dl/
			wget -O dl/rtty-8.0.1-1.tar.gz https://github.com/innet8/rtty/releases/download/v8.0.1-1/rtty-8.0.1-1.tar.gz
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
		fi
	fi


    find "bin/" -type f -name "*.ipk" -exec cp -f {} "/artifacts" \;
    exit 0
}
download_sdk
compile_sdk
printf "\nError: Can't found '$sdk_name' target. Please check available target list again!\n\n" && usage
