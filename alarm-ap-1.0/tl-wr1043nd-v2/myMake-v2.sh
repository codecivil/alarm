#!/bin/bash
cd openwrt-imagebuilder-21.02.3-ath79-generic.Linux-x86_64
make image PROFILE=tplink_tl-wr1043nd-v2 PACKAGES="$(cat ../default_packages) $(cat ../extra_packages)" FILES=files/
exit 0
