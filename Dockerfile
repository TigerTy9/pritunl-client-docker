FROM debian:bookworm

RUN apt-get update && apt-get install -y wget
RUN wget https://github.com/pritunl/pritunl-client-electron/releases/download/1.3.3883.60/pritunl-client-electron_1.3.3883.60-0debian1.bookworm_amd64.deb
RUN apt-get install -y ./pritunl-client-electron_1.3.3883.60-0debian1.bookworm_amd64.deb
RUN apt-get update && apt-get install -y wireguard-tools iproute2

COPY start_pritunl.sh start_pritunl.sh
RUN chmod +x start_pritunl.sh
CMD pritunl-client-service & ./start_pritunl.sh
