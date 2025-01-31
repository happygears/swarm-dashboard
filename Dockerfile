FROM node:8-alpine AS base

RUN apk add --update tini curl \
  && rm -r /var/cache
ENTRYPOINT ["/sbin/tini", "--"]
WORKDIR /home/node/app

FROM base AS dependencies

ENV NODE_ENV=production

COPY package.json yarn.lock ./
RUN yarn install --production

# elm doesn't work under alpine 6 or 8
FROM node:10-buster-slim AS elm-build
WORKDIR /home/node/app
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  python

RUN npm install -g elm@0.18.0-exp5 --unsafe-perm=true --silent

COPY . .

RUN python2 elm-install.py elm-lang/core 5.1.1
RUN python2 elm-install.py elm-lang/html 2.0.0
RUN python2 elm-install.py elm-lang/navigation 2.1.0
RUN python2 elm-install.py elm-lang/svg 2.0.0
RUN python2 elm-install.py elm-lang/websocket 1.0.2
RUN python2 elm-install.py ryannhg/elm-date-format 2.1.2
RUN python2 elm-install.py elm-lang/virtual-dom 2.0.4
RUN python2 elm-install.py elm-lang/dom 1.1.1

# RUN elm package install -y;

RUN elm make Main.elm --yes --output=client/index.js

FROM base AS release

WORKDIR /home/node/app

COPY --from=dependencies /home/node/app/node_modules node_modules
COPY --from=elm-build /home/node/app/client/ client
COPY server server

HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl --fail http://localhost:$PORT/_health || exit 1

# Run under Tini
CMD ["node", "server/index.js"]
