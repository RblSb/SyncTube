FROM docker.io/library/haxe:4.1 as builder

COPY . /tmp/synctube

WORKDIR /tmp/synctube

RUN haxelib --always install all

FROM docker.io/library/alpine:3.11.5 as runtime

ENV SYNCTUBE_PORT=4200
ENV PUID=10001
ENV PGID=10001

RUN mkdir -p /synctube

WORKDIR /synctube

COPY --from=builder /tmp/synctube/res ./res
COPY --from=builder /tmp/synctube/build ./build
COPY --from=builder /tmp/synctube/package.json .
COPY --from=builder /tmp/synctube/default-config.json .

RUN apk update && \
    apk add --no-cache \
        npm && \
    npm install && \
    mkdir -p /synctube/user && \
    chown -R $PUID:$PGUID /synctube/user

USER $PUID:$PGID
ENV HOME=/synctube/user

EXPOSE $SYNCTUBE_PORT

CMD npm start
