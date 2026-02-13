FROM postgres:17-bookworm

RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    . /etc/os-release && \
    echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
      > /etc/apt/sources.list.d/timescaledb.list && \
    curl -L https://packagecloud.io/timescale/timescaledb/gpgkey -o /tmp/timescale.key && \
    gpg --dearmor < /tmp/timescale.key > /etc/apt/trusted.gpg.d/timescale.gpg && \
    rm /tmp/timescale.key && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      timescaledb-2-postgresql-17 \
      postgresql-17-partman \
      postgresql-17-pgvector && \
    apt-get purge -y curl gnupg && \
    apt-get autoremove -y && \
    rm -f /etc/apt/sources.list.d/timescaledb.list /etc/apt/trusted.gpg.d/timescale.gpg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*
