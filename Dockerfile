FROM fedora:35
MAINTAINER petef@databits.net

COPY ./ /build
RUN /build/bin/build.sh

ENV DEVSHELL=1 USERNAME=petef

ENTRYPOINT ["/sbin/init.devshell"]
