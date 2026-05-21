FROM node:22-alpine

WORKDIR /usr/src/app

ENV DOCKERIZE_VERSION=v0.6.1

RUN apk add --no-cache --virtual .build-deps wget \
    && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && apk del .build-deps \
    && chown -R node:node /usr/src/app

USER node

COPY --chown=node:node package*.json ./
RUN npm ci --omit=dev

COPY --chown=node:node . .

EXPOSE 3000
