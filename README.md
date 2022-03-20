# extract-envoy

Extracts `envoy.exe` from the Envoy Proxy Windows container. `envoy.exe` can be found as an artifact of the build.

## How it works
1. Downloads static `docker.exe` and `dockerd.exe` for Windows
2. Generates a `daemon.json` config for `dockerd`
3. Starts the Docker daemon, `dockerd`
3. Pulls the Envoy Windows iamge
4. Creates a container of the Envoy image
5. Copies `envoy.exe` out of the container
6. Deletes the container
6. Uploads `envoy.exe` as a build artifact
