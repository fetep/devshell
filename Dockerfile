FROM fedora:39
MAINTAINER petef@databits.net

COPY ./ /build
RUN /build/bin/build.sh && rm -rf /build

ENV USERNAME=petef

ENTRYPOINT ["/sbin/init.devshell"]
