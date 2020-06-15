FROM scratch
LABEL maintainer=christopher@horrell.ca
COPY node /bin/
ENTRYPOINT ["/bin/node"]
