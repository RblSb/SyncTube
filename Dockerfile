FROM frolvlad/alpine-glibc
WORKDIR /usr/src/app

RUN apk add nodejs npm git; \
    npm install --global lix; \
    lix install haxe 4.1.5 --global

COPY res ./res
COPY src ./src
COPY user ./user
COPY build-*.hxml .
COPY package*.json .
COPY default-config.json .

RUN npm ci; \
    haxelib install all --always; \
    haxe build-all.hxml

EXPOSE 4200

CMD npm start
