#!/bin/bash
set -e -o pipefail
read -ra arr <<< "$@"
version=${arr[1]}
trap 0 1 2 ERR
# Extract DISTRO details for tagging
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID-$VERSION_ID"
    if [ "$VERSION_CODENAME" != "" ]; then
        DISTRO="$ID-$VERSION_CODENAME"
    fi
fi
current_dir="$PWD"
echo $DISTRO > .distro_zab.txt
apt update; apt install sudo git rpm -y
# Clone linux-on-ibm-z to keep it current
git clone https://github.com/linux-on-ibm-z/scripts.git /tmp/linux-on-ibm-z
# Build Debian and RPM packages
sed -i '/build-kong/a \    bazel build //build:kong --config release\n    bazel build --config release :kong_deb\n    bazel build --config release :kong_el8 --action_env=RPM_SIGNING_KEY_FILE --action_env=NFPM_RPM_PASSPHRASE' /tmp/linux-on-ibm-z-scripts/Kong/${version}/build_kong.sh
sed -i '/kong.diff/a \    git apply ${CURDIR}/patches/nfpm.diff' /tmp/linux-on-ibm-z-scripts/Kong/${version}/build_kong.sh 
bash /tmp/linux-on-ibm-z-scripts/Kong/${version}/build_kong.sh -y
# Copy generated Debian and RPM packages
mv ${current_dir}/kong/bazel-out/s390x-opt/bin/pkg/kong.s390x.deb ${current_dir}/kong-${version}-linux-s390x.deb
mv ${current_dir}/kong/bazel-out/s390x-opt/bin/pkg/kong.el8.s390x.rpm ${current_dir}/kong-${version}-linux-s390x.rpm
cd ${current_dir} && tar cfz kong-${version}-linux-s390x.tar.gz -C ${current_dir} kong-${version}-linux-s390x.deb kong-${version}-linux-s390x.rpm
exit 0
