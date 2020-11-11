FROM ubuntu:focal

# Add the haxe ppa to get a more recent version of haxe (ubuntu focal upstream only has 4.0.x flavor)
RUN apt-get update > /dev/null \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       software-properties-common \
    && add-apt-repository ppa:haxe/releases -y

RUN apt-get update > /dev/null \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       git-core \
       haxe \
       nodejs \
       npm \
       vim

RUN mkdir ~/haxelib && haxelib setup ~/haxelib

WORKDIR /code

ADD package*.json /code/
RUN npm install
ADD *.hxml /code/
RUN haxelib install --always all
ADD . /code
RUN haxe build-all.hxml
CMD ["node", "build/server.js"]
