FROM ghcr.io/cloudnative-pg/postgresql:17.2

USER root

RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg && \
    . /etc/os-release && \
    echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
      > /etc/apt/sources.list.d/timescaledb.list && \
    curl -Lsf https://packagecloud.io/timescale/timescaledb/gpgkey \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/timescale.gpg && \
    apt-get update && \
    apt-get install -y --no-install-recommends timescaledb-2-postgresql-17 && \
    apt-get purge -y curl gnupg && \
    apt-get autoremove -y && \
    rm -f /etc/apt/sources.list.d/timescaledb.list /etc/apt/trusted.gpg.d/timescale.gpg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

USER 26
