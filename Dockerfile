FROM ubuntu

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt install -y fio \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY diskmark.sh /usr/bin/diskmark
VOLUME /disk
WORKDIR /disk

ENV TARGET "/disk"
ENV PROFILE "auto"
ENV DATA "random"
ENV LOOPS 5
ENV SIZE 1G
ENTRYPOINT [ "diskmark" ]
