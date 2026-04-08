# Dockerized pritunl-client

This is a dockerized version of the pritunl-client. It is based on the official pritunl-client package and runs in a docker container.  

Current version uses [1.3.3883.60](https://github.com/pritunl/pritunl-client-electron/releases/tag/1.3.3883.60)

## Usage

Set the environment variable `PRITUNL_PROFILE` to your profile url and run the container and `USE_WIREGUARD` to true if you want wireguard support.
