FROM scratch
LABEL maintainer=christopher@horrell.ca
LABEL org.opencontainers.image.source https://github.com/chorrell/docker-node-minimal
COPY node /bin/
ENTRYPOINT ["/bin/node"]
