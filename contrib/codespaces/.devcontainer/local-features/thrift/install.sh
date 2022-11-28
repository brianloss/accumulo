#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

THRIFT_VERSION="${VERSION:-"0.17.0"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

USERHOME="/home/$USERNAME"
if [ "$USERNAME" = "root" ]; then
    USERHOME="/root"
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install Apache Thrift dependencies
check_packages build-essential automake pkg-config bison flex libtool libboost-all-dev libevent-dev libssl-dev

# Install Apache Thrift
echo "Downloading Thrift..."
curl -sSL https://dlcdn.apache.org/thrift/${THRIFT_VERSION}/thrift-${THRIFT_VERSION}.tar.gz -o /tmp/thrift-${THRIFT_VERSION}.tar.gz || \
curl -sSL http://archive.apache.org/dist/thrift/${THRIFT_VERSION}/thrift-${THRIFT_VERSION}.tar.gz -o /tmp/thrift-${THRIFT_VERSION}.tar.gz
mkdir -p /tmp/thrift-${THRIFT_VERSION}
tar xzf /tmp/thrift-${THRIFT_VERSION}.tar.gz -C /tmp/thrift-${THRIFT_VERSION} --strip-components=1
cd /tmp/thrift-${THRIFT_VERSION}
./bootstrap.sh
./configure --enable-libs=no
make
make install
cd /
rm -rf /tmp/thrift-${THRIFT_VERSION} /tmp/thrift-${THRIFT_VERSION}.tar.gz

# Clean up
apt-get -y autoremove
rm -rf /var/lib/apt/lists/*

echo -e "\nDone!"
