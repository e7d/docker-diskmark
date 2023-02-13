FROM ubuntu

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt install -y fio \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY resources/diskmark.sh /usr/bin/diskmark
VOLUME /disk
WORKDIR /disk

ENV SIZE 1024
ENV LOOPS 5
ENV WRITEZERO 0
ENTRYPOINT [ "diskmark" ]
