# x11docker/xserver
#
# Internal use of x11docker to run X servers in container
# Used automatically by x11docker if image is available locally.
# Can be configured with option --xc.
#
# Build image with: x11docker --build x11docker/xserver
# The build will take a while because nxagent is compiled from source.
#
# x11docker on github: https://github.com/mviereck/x11docker

#########################
FROM debian:bullseye

# cleanup script for use after apt-get
RUN echo '#! /bin/sh\n\
env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y\n\
apt-get clean\n\
find /var/lib/apt/lists -type f -delete\n\
find /var/cache -type f -delete\n\
find /var/log -type f -delete\n\
exit 0\n\
' > /apt_cleanup && chmod +x /apt_cleanup

# build patched nxagent from source. Allows to run with /tmp/.X11-unix not to be owned by root.
# https://github.com/ArcticaProject/nx-libs/issues/1034
RUN echo "deb-src http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list && \
    apt-get update && \
    installpackages="dpkg-dev devscripts $(apt-get build-dep --dry-run nxagent | grep "Inst " | awk '{print $2}')" && \
    apt-get install -y --no-install-recommends $installpackages && \
    mkdir /nxbuild && \
    cd /nxbuild && \
    apt-get source nxagent && \
    cd nx-libs-3.5.99.26 && \
    sed -i 's/# define XtransFailSoft NO/# define XtransFailSoft YES/' nx-X11/config/cf/X11.rules && \
    debuild -b -uc -us && \
    cd /nxbuild && \
    cp nxagent_3.*.deb / && \
    rm -R /nxbuild && \
    apt-get remove -y --purge $installpackages && \
    /apt_cleanup

#########################
FROM debian:bullseye
COPY --from=0 /nxagent_3.5.99.26-2_amd64.deb /
COPY --from=0 /apt_cleanup /

# X servers and tools
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        /nxagent_3.5.99.26-2_amd64.deb \
        weston \
        x11-utils \
        x11-xserver-utils \
        xauth \
        xclip \
        xfishtank \
        xinit \
        xserver-xephyr \
        xvfb \
        xwayland && \
    /apt_cleanup

# Window manager openbox with disabled context menu
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openbox && \
    sed -i /ShowMenu/d         /etc/xdg/openbox/rc.xml && \
    sed -i s/NLIMC/NLMC/       /etc/xdg/openbox/rc.xml && \
    /apt_cleanup

# xpra from xpra repository
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        ca-certificates && \
    wget -q https://xpra.org/gpg.asc -O- | apt-key add - && \
    echo "deb http://xpra.org/ bullseye main" > /etc/apt/sources.list.d/xpra.list && \
    apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xpra  \
        ibus \
        python3-rencode && \
    apt-get remove --purge -y \
        wget \
        gnupg \
        ca-certificates && \
    /apt_cleanup

COPY XlibNoSHM.so /XlibNoSHM.so


#RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#        xkbset xkbind xkb-data x11-xkb-utils gir1.2-xkl-1.0 libxkbcommon0 libxkbcommon-x11-0 libxcb-xkb1

#RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#        kwin-wayland kwin-wayland-backend-x11 kwin-wayland-backend-wayland
