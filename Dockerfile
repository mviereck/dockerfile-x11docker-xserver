# x11docker/xserver
# Internal use of x11docker to run X servers in container

FROM debian:stable-slim

RUN apt-get update
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    metacity \
    x11-utils \
    x11-xserver-utils \
    xauth \
    xclip \
    xfishtank \
    xinit \
    xserver-xephyr \
    xvfb

# xpra from winswitch repository
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget gnupg ca-certificates && \
    wget -q https://xpra.org/gpg.asc -O- | apt-key add - && \
    echo "deb http://winswitch.org/ bullseye main" > /etc/apt/sources.list.d/winswitch.list && \
    apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xpra python3-rencode && \
    apt-get remove -y wget gnupg ca-certificates && \
    apt-get autoremove -y && \
    apt-get clean

