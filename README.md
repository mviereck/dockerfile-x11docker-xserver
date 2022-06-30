# X servers in container for use with x11docker

This Dockerfile provides a set of X servers that can be used by [x11docker](https://github.com/mviereck/x11docker).
The resulting image `x11docker/xserver` can be used automatically to run the supported X servers in a container.
This allows to isolate the X servers from host and to reduce x11docker dependencies on host.

Pull the image from docker hub with `docker pull x11docker/xserver`.

Or build image yourself with: `x11docker --build x11docker/xserver`
The build takes a while because nxagent is built from source.

This image supports all x11docker X server options and also contains several tools to reduce x11docker dependencies on host.
The image includes X servers and Wayland compositors `kwin_wayland`, `nxagent`, `Xephyr`, `Xorg`, `Xvfb`, `weston`, `Xwayland` and `xpra`.

Supported x11docker options (formerly host only) for use with image `x11docker/xserver`:
 - `--kwin`
 - `--nxagent`
 - `--weston`
 - `--weston-xwayland`
 - `--xephyr`
 - `--xorg`
 - `--xpra`
 - `--xpra-xwayland`
 - `--xvfb`
 - `--xwayland`

New options that depend on image `x11docker/xserver` and `xpra` on host:
 - `--xpra2`
 - `--xpra2-xwayland`
 
`--xpra2` and `--xpra2-xwayland` run X server and xpra server in container, but xpra client on host. 
This should provide the best possible combination of security and performance for `xpra`.

## GPU support
### Open source MESA drivers
The image contains the free open source MESA drivers. No setup is needed if you use MESA drivers on host.
### NVIDIA driver
If you have closed source NVIDIA driver installed on host, image `x11docker/xserver` needs the same driver version inside for hardware acceleration.
However, this only makes sense if your driver version is >=`470.x` as older ones do not support the accelerated X server setups of this image.

You have two possibilities:
#### Automated install on every container startup
Provide an NVIDIA driver installer file at `~/.local/share/x11docker`. x11docker will install the driver on every startup of `x11docker/xserver`.
This will slow down container startup. Compare [x11docker wiki: Automated install of NVIDIA driver during container startup](https://github.com/mviereck/x11docker/wiki/NVIDIA-driver-support-for-docker-container#automated-install-of-nvidia-driver-during-container-startup).
#### Build `x11docker/xserver` based on `x11docker/nvidia-base`
 - Create an image `x11docker/nvidia-base`. A script for this is provided at [x11docker wiki: NVIDIA driver base image](https://github.com/mviereck/x11docker/wiki/NVIDIA-driver-support-for-docker-container#nvidia-driver-base-image).
 - In Dockerfile for `x11docker/xserver` change `FROM debian:bullseye` to `FROM x11docker/nvidia-base` and build image `x11docker/xserver` with this Dockerfile.
 
Note that this image will only work with the NVIDIA driver version of your host and is not portable.

![x11docker logo](https://github.com/mviereck/x11docker/blob/screenshots/x11docker-512x512.png)
