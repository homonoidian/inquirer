FROM crystallang/crystal:latest-alpine

WORKDIR /build
COPY . .
RUN [ "shards", "install", "--ignore-crystal-version" ]

ENV KEMAL_ENV=production
CMD [ "shards", "build", "--release", "--static", "--no-debug", "--production" ]
