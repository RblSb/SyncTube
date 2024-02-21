FROM haxe:4.3-alpine
WORKDIR /usr/src/app

RUN apk add nodejs npm git

COPY res ./res
COPY src ./src
COPY user ./user
COPY build-*.hxml ./
COPY package*.json ./
COPY default-config.json ./

RUN npm ci;
RUN haxelib install all --always
RUN haxe build-all.hxml

EXPOSE 4200

CMD npm start
