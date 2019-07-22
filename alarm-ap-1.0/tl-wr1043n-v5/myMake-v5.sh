#!/bin/bash
cd openwrt-imagebuilder-18.06.1-ar71xx-generic.Linux-x86_64
make image PROFILE=tl-wr1043n-v5 PACKAGES="$(cat ../default_packages) $(cat ../extra_packages)" FILES=files/
exit 0
