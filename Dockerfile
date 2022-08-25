ARG CONTAINER=openwrt/sdk
ARG ARCH=mips_24kc
ARG MODE=normal
FROM $CONTAINER:$ARCH AS base

LABEL "com.github.actions.name"="OpenWrt SDK"

FROM base AS normal
ADD entrypoint.sh /

FROM base AS only_custom
ADD only_custom.sh /entrypoint.sh

FROM $MODE AS final
ENTRYPOINT ["/entrypoint.sh"]
