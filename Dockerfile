# x11docker/xserver
# Internal use of x11docker to run X servers in container

FROM debian:stable-slim

RUN apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        nxagent \
        weston \
        x11-utils \
        x11-xserver-utils \
        xauth \
        xclip \
        xfishtank \
        xinit \
        xserver-xephyr \
        xvfb \
        xwayland

# xpra from xpra repository
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        ca-certificates && \
    wget -q https://xpra.org/gpg.asc -O- | apt-key add - && \
    echo "deb http://xpra.org/ bullseye main" > /etc/apt/sources.list.d/xpra.list && \
    apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xpra \
        python3-rencode && \
    apt-get remove -y \
        wget \
        gnupg \
        ca-certificates && \
    apt-get autoremove -y && \
    apt-get clean

# Disable usage of MIT-SHM with LD_PRELOAD 
# https://github.com/jessfraz/dockerfiles/issues/359#issuecomment-828714848
RUN echo "#include <X11/Xlib.h>"             >/docker_xnoshm.c && \
    echo "#include <sys/shm.h>"              >>/docker_xnoshm.c && \
    echo "#include <X11/extensions/XShm.h>"  >>/docker_xnoshm.c && \
    echo "\n\
Bool XShmQueryExtension(Display *display) {\n\
	return 0;\n\
}\n\
"                                            >> /docker_xnoshm.c && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        gcc \
        libc-dev \
        libxext-dev && \
    gcc /docker_xnoshm.c -shared -o /docker_xnoshm.so && \
    apt-get remove -y \
        gcc \
        libc-dev \
        libxext-dev && \
    apt-get autoremove -y && \
    apt-get clean
ENV LD_PRELOAD=/docker_xnoshm.so

# Window manager openbox with disabled context menu
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openbox && \
    sed -i /ShowMenu/d         /etc/xdg/openbox/rc.xml && \
    sed -i s/NLIMC/NLMC/       /etc/xdg/openbox/rc.xml

RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        dbus-x11
