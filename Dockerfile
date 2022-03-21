# syntax=docker.io/docker/dockerfile:1.4.0
FROM scratch
LABEL maintainer=christopher@horrell.ca
LABEL org.opencontainers.image.source https://github.com/chorrell/docker-node-minimal
COPY --link node /bin/
ENTRYPOINT ["/bin/node"]
