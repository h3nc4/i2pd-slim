# Copyright (C) 2026  Henrique Almeida
# This file is part of i2pd Slim.
#
# i2pd Slim is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# i2pd Slim is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with i2pd Slim.  If not, see <https://www.gnu.org/licenses/>.

########################################
# Versions
ARG I2PD_VERSION="2.61.0"

################################################################################
# i2pd Builder
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS i2pd-builder
ARG I2PD_VERSION

# Install build dependencies
RUN apk add --no-cache \
  boost-dev \
  boost-static \
  build-base \
  gnupg \
  openssl-dev \
  openssl-libs-static \
  zlib-dev \
  zlib-static

WORKDIR /src

# Download and verify i2pd. SHA512SUMS lists the tag archive under this name,
# and the release signs it with the key that signs the tags.
ADD "https://github.com/PurpleI2P/i2pd/archive/refs/tags/${I2PD_VERSION}.tar.gz" "i2pd-${I2PD_VERSION}.tar.gz"
ADD "https://github.com/PurpleI2P/i2pd/releases/download/${I2PD_VERSION}/SHA512SUMS" SHA512SUMS
ADD "https://github.com/PurpleI2P/i2pd/releases/download/${I2PD_VERSION}/SHA512SUMS.asc" SHA512SUMS.asc
ADD "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x951928BB317024EFD053D73C66F6C87B98EBCFE2" r4sas_gpg_key.asc

# Import the release key, then check the signature and the archive's line
RUN gpg --batch --yes --import <"r4sas_gpg_key.asc" && \
  gpg --batch --yes --verify SHA512SUMS.asc SHA512SUMS && \
  grep " \*i2pd-${I2PD_VERSION}.tar.gz$" SHA512SUMS | sed 's/ \*/  /' | sha512sum -c
RUN tar -xzf "i2pd-${I2PD_VERSION}.tar.gz" --strip-components=1

# Compile static i2pd
RUN make -j"$(nproc)" LDFLAGS=-static USE_UPNP=no && \
  strip --strip-all i2pd

# Setup directories and folder permissions. tunnels.d is root-owned, so i2pd
# reads drop-ins there and cannot write them.
RUN mkdir -p /rootfs/var/lib/i2pd /rootfs/etc/i2pd/tunnels.d && \
  mv i2pd /rootfs/i2pd && \
  cp -R contrib/certificates /rootfs/certificates && \
  chown 65534:65534 /rootfs/var/lib/i2pd && \
  chmod 700 /rootfs/var/lib/i2pd

# The console keeps strictheaders, which refuses any Host but localhost and
# so a DNS rebinding page. SAM, BOB and I2CP stay off.
RUN printf '%s\n' \
  'log = stdout' \
  'loglevel = warn' \
  'tunconf = /etc/i2pd/tunnels.conf' \
  'tunnelsdir = /etc/i2pd/tunnels.d' \
  'certsdir = /certificates' \
  '[http]' 'address = 0.0.0.0' 'port = 7070' \
  '[httpproxy]' 'address = 0.0.0.0' 'port = 4444' \
  '[socksproxy]' 'address = 0.0.0.0' 'port = 4447' \
  '[sam]' 'enabled = false' \
  '[bob]' 'enabled = false' \
  '[i2cp]' 'enabled = false' \
  '[upnp]' 'enabled = false' \
  >/rootfs/etc/i2pd/i2pd.conf

################################################################################
# Final squashed image
FROM scratch AS final

COPY --from=i2pd-builder /rootfs/ /

USER 65534:65534

ENTRYPOINT ["/i2pd"]
CMD ["--datadir=/var/lib/i2pd", "--conf=/etc/i2pd/i2pd.conf"]

LABEL org.opencontainers.image.title="i2pd Slim" \
  org.opencontainers.image.description="A minimal, static i2pd router container built from scratch" \
  org.opencontainers.image.authors="Henrique Almeida <me@h3nc4.com>" \
  org.opencontainers.image.vendor="Henrique Almeida" \
  org.opencontainers.image.licenses="GPL-3.0-or-later" \
  org.opencontainers.image.source="https://github.com/h3nc4/i2pd-slim"
