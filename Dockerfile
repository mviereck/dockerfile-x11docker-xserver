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

FROM debian:trixie AS buildstage

#########################

RUN echo "deb-src http://deb.debian.org/debian trixie main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
      build-essential \
      gcc \
      devscripts

# build patched nxagent from source. Allows to run with /tmp/.X11-unix not to be owned by root.
# https://github.com/ArcticaProject/nx-libs/issues/1034
RUN apt-get build-dep -y nxagent && \
    mkdir /nxbuild && \
    cd /nxbuild && \
    apt-get source nxagent && \
    cd nx-libs-3.5.99.27 && \
    sed -i 's/# define XtransFailSoft NO/# define XtransFailSoft YES/' nx-X11/config/cf/X11.rules && \
    debuild -b -uc -us

# build xwayland-satellite
RUN apt-get install -y \
      clang \
      cargo \
      libxcb-cursor-dev \
      git && \
    cd / && \
    git clone https://github.com/Supreeeme/xwayland-satellite.git && \
    cd xwayland-satellite && \
    cargo build

# build fake MIT-SHM library
COPY XlibNoSHM.c /XlibNoSHM.c
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            libc6-dev \
            libx11-dev && \
    gcc -shared -o /XlibNoSHM.so /XlibNoSHM.c

# build bindkey for --clipboard=superaltv
COPY bindkey.c /bindkey.c
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            libevdev-dev \
            libinput-dev && \
    gcc -I/usr/include/libevdev-1.0 -I/usr/include/libevdev-1.0/libevdev -o /bindkey /bindkey.c -levdev


#########################

FROM debian:trixie
ENV DIST=trixie
COPY --from=buildstage /nxbuild/nxagent_3.*.deb /nxagent.deb
COPY --from=buildstage /xwayland-satellite/target/debug/xwayland-satellite /usr/bin/xwayland-satellite
COPY --from=buildstage /XlibNoSHM.so /XlibNoSHM.so
COPY --from=buildstage /bindkey /usr/local/bin/bindkey

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
        weston \
        xserver-xephyr \
        xserver-xorg \
        xserver-xorg-legacy \
        xvfb \
        xwayland && \
    apt-get install -y \
        libdecor-0-0 \
        libdecor-0-plugin-1-cairo \
        libxcb1 \
        libxcb-cursor0 && \
    /apt_cleanup

# MESA
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libglx-mesa0 \
        mesa-utils \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        mesa-vulkan-drivers && \
    /apt_cleanup

# xpra from xpra repository
#RUN curl https://xpra.org/get-xpra.sh | bash && \
#    /apt_cleanup
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        wget && \
    wget -O "/usr/share/keyrings/xpra.asc" https://xpra.org/xpra.asc &&  \
    wget -O "/etc/apt/sources.list.d/xpra.sources" https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/$DIST/xpra.sources && \
    apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xpra \
        xpra-audio \
        xpra-audio-server \
        xpra-codecs-extras \
        xpra-codecs-nvidia \
        xpra-x11 \
        ibus \
        python3-rencode && \
    apt-get remove --purge -y \
        wget \
        ca-certificates && \
    /apt_cleanup

# Window manager openbox with disabled context menu
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openbox && \
    sed -i /ShowMenu/d         /etc/xdg/openbox/rc.xml && \
    sed -i s/NLIMC/NLMC/       /etc/xdg/openbox/rc.xml && \
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
        x11-apps \
        x11-utils \
        x11-xkb-utils \
        x11-xserver-utils \
        xauth \
        xbindkeys \
        xclip \
        xdotool \
        xinit \
        xcvt && \
    /apt_cleanup

# xfishtank
RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      wget && \
    wget http://ftp.debian.org/debian/pool/main/x/xfishtank/xfishtank_3.2.2-1_amd64.deb && \
    apt-get install -y ./xfishtank_3.2.2-1_amd64.deb && \
    rm ./xfishtank_3.2.2-1_amd64.deb && \
    apt-get remove -y wget && \
    /apt_cleanup

# configure Xorg wrapper
RUN echo 'allowed_users=anybody' >/etc/X11/Xwrapper.config && \
    echo 'needs_root_rights=yes' >>/etc/X11/Xwrapper.config

# wrapper to run weston either on console or within DISPLAY or WAYLAND_DISPLAY
# note: includes setuid for agetty to allow it for unprivileged users
#RUN echo '#! /bin/bash \n\
#case "$DISPLAY$WAYLAND_DISPLAY" in \n\
#  "") \n\
#    [ -e /dev/tty$XDG_VTNR ] && [ -n "$XDG_VTNR" ] || { \n\
#      echo "ERROR: No display and no tty found. XDG_VTNR is empty." >&2 \n\
#      exit 1 \n\
#    } \n\
#    /usr/bin/weston $@ \n\
#    #exec agetty --login-options "-v -- $* --log=/x11docker/compositor.log " --autologin $(id -un) --login-program /usr/bin/weston-launch --noclear tty$XDG_VTNR \n\
#  ;; \n\
#  *) \n\
#    exec /usr/bin/weston "$@" \n\
#  ;; \n\
#esac \n\
#' >/usr/local/bin/weston && \
#    chmod +x /usr/local/bin/weston && \
#    ln /usr/local/bin/weston /usr/local/bin/weston-launch

RUN chown root:input /usr/local/bin/bindkey && \
    chmod +g /usr/local/bin/bindkey

# HOME
RUN mkdir -p /home/container && chmod 777 /home/container
ENV HOME=/home/container

LABEL version='2.4'
LABEL options='--nxagent --weston --weston-xwayland --xephyr --xpra --xpra-xwayland --xpra2 --xpra2-xwayland --xorg --xvfb --xwayland --satellite'
LABEL tools='bindkey catatonit cvt glxinfo iceauth setxkbmap socat \
             vainfo vdpauinfo virgl wl-copy wl-paste wmctrl \
             xauth xbindkeys xclip xdotool xdpyinfo xdriinfo xev \
             xeyes xfishtank xhost xinit xkbcomp xkill xlsclients xmessage \
             xmodmap xprop xrandr xrefresh xset xsetroot xvinfo xwininfo'
LABEL options_console='--weston --weston-xwayland --xorg'
LABEL gpu='MESA'
LABEL windowmanager='openbox'

ENTRYPOINT ["/usr/bin/catatonit", "--"]
