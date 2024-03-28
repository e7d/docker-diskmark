FROM ubuntu AS deps
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y fio \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM deps
COPY diskmark.sh /usr/bin/diskmark
VOLUME /disk
WORKDIR /disk
ENV TARGET "/disk"
ENV PROFILE "auto"
ENV IO "direct"
ENV DATA "random"
ENV SIZE 1G
ENV WARMUP 1
ENV RUNTIME 5s
ENTRYPOINT [ "diskmark" ]
