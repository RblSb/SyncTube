FROM haxe:4.3-alpine3.22

RUN apk add nodejs npm git

USER 0
RUN addgroup -g 1000 app && adduser -u 1000 -G app -s /bin/sh -D app && mkdir /app
WORKDIR /app

COPY res ./res
COPY src ./src
COPY user ./user
COPY build-*.hxml ./
COPY package*.json ./
COPY default-config.json ./

RUN chown -R app:app /app

USER 1000
RUN npm ci;
RUN haxelib setup /app \
    && haxelib install all --always && \
    haxe build-all.hxml

ENTRYPOINT [ "npm", "start" ]

