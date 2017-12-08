FROM alpine:edge

LABEL nim.version=0.17.0 \
      maintainer=andre.burgaud@gmail.com

RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    apk add --no-cache musl musl-dev gcc nim nimble git mercurial

WORKDIR /workspace

CMD ["sh"]
