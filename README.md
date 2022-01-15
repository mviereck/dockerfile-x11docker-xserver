# X servers in container for use with x11docker

This Dockerfile provides a set of X servers that can be used by [x11docker](https://github.com/mviereck/x11docker).
The resulting image `x11docker/xserver` can be used automatically to run the supported X servers in a container.
This allows to isolate the X servers from host and to reduce x11docker dependencies on host.

Build image with: `x11docker --build x11docker/xserver`

Currently supported x11docker options for use with image `x11docker/xserver`:
 - `--xpra`
 - `--xephyr`
 - `--weston-xwayland`
 - `--xvfb`
 - `--xwayland`
 - `--weston`

Additional options that depend on image `x11docker/xserver`:
 - `--xpra2`
 - `--xpra2-xwayland`
 
`--xpra2` and `--xpra2-xwayland` run X server and xpra server in container, but xpra client on host. 
This should provide the best possible combination of security and performance for `xpra`.
