FROM ubuntu:latest

RUN apt-get update -y
RUN apt-get install libfuse2 fuse -y
ADD entrypoint.sh /
# copy and unpack the binary file geesefs-linux.. from https://github.com/yandex-cloud/geesefs/releases
ADD geesefs-linux-* /bin
STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
