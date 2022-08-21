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

FROM debian:bullseye AS nxbuild

#########################

# build patched nxagent from source. Allows to run with /tmp/.X11-unix not to be owned by root.
# https://github.com/ArcticaProject/nx-libs/issues/1034
RUN echo "deb-src http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y build-essential devscripts && \
    apt-get build-dep -y nxagent && \
    mkdir /nxbuild && \
    cd /nxbuild && \
    apt-get source nxagent && \
    cd nx-libs-3.5.99.26 && \
    sed -i 's/# define XtransFailSoft NO/# define XtransFailSoft YES/' nx-X11/config/cf/X11.rules && \
    debuild -b -uc -us

FROM debian:bullseye
COPY --from=nxbuild /nxbuild/nxagent_3.*.deb /nxagent.deb

# cleanup script for use after apt-get
RUN echo '#! /bin/sh\n\
env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y\n\
apt-get clean\n\
find /var/lib/apt/lists -type f -delete\n\
find /var/cache -type f -delete\n\
find /var/log -type f -delete\n\
exit 0\n\
' > /apt_cleanup && chmod +x /apt_cleanup

# install nxagent
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        /nxagent.deb && \
    /apt_cleanup

# X servers
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        kwin-wayland \
        kwin-wayland-backend-drm \
        kwin-wayland-backend-wayland \
        kwin-wayland-backend-x11 \
        weston \
        xserver-xephyr \
        xserver-xorg \
        xserver-xorg-legacy \
        xvfb \
        xwayland && \
    /apt_cleanup

# xpra from xpra repository
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        ca-certificates && \
    wget -q http://xpra.org/gpg.asc -O xpra-gpg.asc && \
    apt-key add xpra-gpg.asc && \
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

# Window manager openbox with disabled context menu
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openbox && \
    sed -i /ShowMenu/d         /etc/xdg/openbox/rc.xml && \
    sed -i s/NLIMC/NLMC/       /etc/xdg/openbox/rc.xml && \
    /apt_cleanup

# compile fake MIT-SHM library
COPY XlibNoSHM.c /XlibNoSHM.c
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            gcc \
            libc6-dev \
            libx11-dev && \
    gcc -shared -o /XlibNoSHM.so /XlibNoSHM.c && \
    apt-get remove --purge -y \
        gcc \
        libc6-dev \
        libx11-dev && \
    /apt_cleanup

# tools
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        catatonit \
        procps \
        psmisc \
        psutils \
        socat \
        vainfo \
        vdpauinfo \
        virgl-server \
        wl-clipboard \
        wmctrl \
        x11-utils \
        x11-xkb-utils \
        x11-xserver-utils \
        xauth \
        xbindkeys \
        xclip \
        xdotool \
        xfishtank \
        xinit && \
    /apt_cleanup

# configure Xorg wrapper
RUN echo 'allowed_users=anybody' >/etc/X11/Xwrapper.config && \
    echo 'needs_root_rights=yes' >>/etc/X11/Xwrapper.config

# wrapper to run weston either on console or within DISPLAY or WAYLAND_DISPLAY
# note: includes setuid for agetty to allow it for unprivileged users
RUN echo '#! /bin/bash \n\
case "$DISPLAY$WAYLAND_DISPLAY" in \n\
  "") \n\
    [ -e /dev/tty$XDG_VTNR ] && [ -n "$XDG_VTNR" ] || { \n\
      echo "ERROR: No display and no tty found. XDG_VTNR is empty." >&2 \n\
      exit 1 \n\
    } \n\
    exec agetty --login-options "-v -- $* --log=/x11docker/compositor.log " --autologin $(id -un) --login-program /usr/bin/weston-launch --noclear tty$XDG_VTNR \n\
  ;; \n\
  *) \n\
    exec /usr/bin/weston "$@" \n\
  ;; \n\
esac \n\
' >/usr/local/bin/weston && \
    chmod +x /usr/local/bin/weston && \
    ln /usr/local/bin/weston /usr/local/bin/weston-launch

# HOME
RUN mkdir -p /home/container && chmod 777 /home/container
ENV HOME=/home/container

LABEL version='1.10'
LABEL options='--kwin --nxagent --weston --weston-xwayland --xephyr --xpra --xpra-xwayland --xpra2 --xpra2-xwayland --xorg --xvfb --xwayland'
LABEL tools='catatonit cvt glxinfo iceauth setxkbmap socat \
             vainfo vdpauinfo virgl wl-copy wl-paste wmctrl \
             xauth xbindkeys xclip xdotool xdpyinfo xdriinfo xev \
             xfishtank xhost xinit xkbcomp xkill xlsclients xmessage \
             xmodmap xprop xrandr xrefresh xset xsetroot xvinfo xwininfo'
LABEL options_console='--kwin --weston --weston-xwayland --xorg'
LABEL gpu='MESA'
LABEL windowmanager='openbox'

ENTRYPOINT ["/usr/bin/catatonit", "--"]
