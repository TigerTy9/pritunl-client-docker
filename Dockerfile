FROM debian:bookworm

# 1. Install downloader and system dependencies in one layer
RUN apt-get update && apt-get install -y \
    wget \
    wireguard-tools \
    iproute2 \
    openresolv \
    procps && \
    rm -rf /var/lib/apt/lists/*

# 2. Download the specific Pritunl client version
RUN wget https://github.com/pritunl/pritunl-client-electron/releases/download/1.3.4566.62/pritunl-client-electron_1.3.4566.62-0debian1.bookworm_amd64.deb

# 3. Install the local .deb and clean up the installer file
RUN apt-get update && \
    apt-get install -y ./pritunl-client-electron_1.3.4566.62-0debian1.bookworm_amd64.deb && \
    rm *.deb && \
    rm -rf /var/lib/apt/lists/*

COPY start_pritunl.sh start_pritunl.sh
RUN chmod +x start_pritunl.sh

# Using the exec form for the command is better practice
CMD ["/bin/sh", "-c", "pritunl-client-service & ./start_pritunl.sh"]
