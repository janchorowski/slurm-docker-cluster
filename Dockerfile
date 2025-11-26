# Multi-stage Dockerfile for Slurm runtime
# Stage 1: Build RPMs using the builder image
# Stage 2: Install RPMs in a clean runtime image

ARG SLURM_VERSION="25.05.3"

# ============================================================================
# Stage 1: Build RPMs
# ============================================================================
FROM rockylinux/rockylinux:9 AS builder

ARG SLURM_VERSION
ARG TARGETARCH

# Enable CRB and EPEL repositories for development packages
# Install RPM build tools and dependencies
RUN set -ex \
    && dnf makecache \
    && dnf -y update \
    && dnf -y install dnf-plugins-core epel-release \
    && dnf config-manager --set-enabled crb \
    && dnf makecache \
    && dnf -y install \
       autoconf \
       automake \
       bzip2 \
       freeipmi-devel \
       dbus-devel \
       gcc \
       gcc-c++ \
       git \
       gtk2-devel \
       hdf5-devel \
       http-parser-devel \
       hwloc-devel \
       json-c-devel \
       libcurl-devel \
       libyaml-devel \
       lua-devel \
       lz4-devel \
       make \
       man2html \
       mariadb-devel \
       munge \
       munge-devel \
       ncurses-devel \
       numactl-devel \
       openssl-devel \
       pam-devel \
       perl \
       python3 \
       python3-devel \
       readline-devel \
       rpm-build \
       rpmdevtools \
       rrdtool-devel \
       wget \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Setup RPM build environment
RUN rpmdev-setuptree

# Copy RPM macros
COPY rpmbuild/slurm.rpmmacros /root/.rpmmacros

# Download official Slurm release tarball and build RPMs with slurmrestd enabled
# Architecture mapping: Docker TARGETARCH (amd64, arm64) -> RPM arch (x86_64, aarch64)
RUN set -ex \
    && RPM_ARCH=$(case "${TARGETARCH}" in \
         amd64) echo "x86_64" ;; \
         arm64) echo "aarch64" ;; \
         *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
       esac) \
    && echo "Building Slurm RPMs for architecture: ${RPM_ARCH}" \
    && wget -O /root/rpmbuild/SOURCES/slurm-${SLURM_VERSION}.tar.bz2 \
       https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
    && cd /root/rpmbuild/SOURCES \
    && rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2 \
    && ls -lh /root/rpmbuild/RPMS/${RPM_ARCH}/

# ============================================================================
# Stage 2: Runtime image
# ============================================================================
FROM rockylinux/rockylinux:9

LABEL org.opencontainers.image.source="https://github.com/giovtorres/slurm-docker-cluster" \
      org.opencontainers.image.title="slurm-docker-cluster" \
      org.opencontainers.image.description="Slurm Docker cluster on Rocky Linux 9" \
      maintainer="Giovanni Torres"

ARG SLURM_VERSION
ARG TARGETARCH

# Enable CRB and EPEL repositories for runtime dependencies
RUN set -ex \
    && dnf makecache \
    && dnf -y update \
    && dnf -y install dnf-plugins-core epel-release \
    && dnf config-manager --set-enabled crb \
    && dnf makecache

# Install runtime dependencies only
RUN set -ex \
    && dnf -y install \
       bash-completion \
       bzip2 \
       gettext \
       hdf5 \
       http-parser \
       hwloc \
       json-c \
       jq \
       libaec \
       libyaml \
       lua \
       lz4 \
       mariadb \
       munge \
       numactl \
       perl \
       procps-ng \
       psmisc \
       python3 \
       readline \
       vim-enhanced \
       wget \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Install gosu for privilege dropping
ARG GOSU_VERSION=1.19

RUN set -ex \
    && echo "Installing gosu for architecture: ${TARGETARCH}" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-${TARGETARCH}" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-${TARGETARCH}.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

COPY --from=builder /root/rpmbuild/RPMS/*/*.rpm /tmp/rpms/

# Install Slurm RPMs
RUN set -ex \
    && dnf -y install /tmp/rpms/slurm-[0-9]*.rpm \
       /tmp/rpms/slurm-perlapi-*.rpm \
       /tmp/rpms/slurm-slurmctld-*.rpm \
       /tmp/rpms/slurm-slurmd-*.rpm \
       /tmp/rpms/slurm-slurmdbd-*.rpm \
       /tmp/rpms/slurm-slurmrestd-*.rpm \
       /tmp/rpms/slurm-contribs-*.rpm \
    && rm -rf /tmp/rpms \
    && dnf clean all

# Create slurm user and group
RUN set -x \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && groupadd -r --gid=991 slurmrest \
    && useradd -r -g slurmrest --uid=991 slurmrest

# Fix /etc permissions and create munge key
RUN set -x \
    && chmod 0755 /etc \
    && /sbin/create-munge-key

# Create slurm dirs with correct ownership
RUN set -x \
    && mkdir -m 0755 -p \
        /var/run/slurm \
        /var/spool/slurm \
        /var/lib/slurm \
        /var/log/slurm \
        /etc/slurm \
    && chown slurm:slurm \
        /var/run/slurm \
        /var/spool/slurm \
        /var/lib/slurm \
        /var/log/slurm \
        /etc/slurm

COPY --chown=slurm:slurm --chmod=0600 examples /root/examples

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
