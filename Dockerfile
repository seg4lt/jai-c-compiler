FROM ubuntu:22.04

RUN apt update

RUN DEBIAN_FRONTEND=noninteractive apt install -y gcc make python3 binutils tini

# RUN cp /libs/jai/bin/jai-linux /libs/jai/bin/jai

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["tail", "-f", "/dev/null"]
