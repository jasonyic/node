FROM golang:1.17-alpine AS build-env

# Set up dependencies
ENV PACKAGES make git libc-dev bash gcc linux-headers eudev-dev curl ca-certificates

# Set working directory for the build
WORKDIR /go/src/github.com/bnb-chain/node

# Add source files
COPY . .

# Install minimum necessary dependencies, build Cosmos SDK, remove packages
RUN apk add --no-cache $PACKAGES && \
    make build && \
    make install

# # Final image
FROM alpine:3.16.0

ENV DATA_DIR=/data
ENV PACKAGES ca-certificates~=20211220 jq~=1.6 \
  bash~=5.1.16-r2 bind-tools~=9.16.29-r0 tini~=0.19.0 \
  grep~=3.7 curl==7.83.1-r2 sed~=4.8-r0

# Install dependencies
RUN apk add --no-cache $PACKAGES \
  && rm -rf /var/cache/apk/*

ARG USER=bnbchain
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEFAULT_CONFIG=/configs
ENV HOME=/data

RUN addgroup -g ${USER_GID} ${USER} \
  && adduser -u ${USER_UID} -G ${USER} --shell /sbin/nologin --no-create-home -D ${USER} \
  && addgroup ${USER} tty \
  && sed -i -e "s/bin\/sh/bin\/bash/" /etc/passwd  \
  && echo "[ ! -z \"\$TERM\" -a -r /etc/motd ] && cat /etc/motd" >> /etc/bash/bashrc

RUN mkdir -p ${HOME} ${DEFAULT_CONFIG} ${DATA_DIR}

WORKDIR ${HOME}

# Copy over binaries from the build-env
COPY --from=build-env /go/bin/bnbchaind /usr/bin/bnbchaind
COPY --from=build-env /go/bin/bnbcli /usr/bin/bnbcli
COPY --from=build-env /go/bin/bnbcli /usr/bin/tbnbcli
COPY --from=build-env /go/bin/bnbcli /usr/bin/lightd

COPY ./asset/ ${DEFAULT_CONFIG}/

RUN chown -R ${USER_UID}:${USER_GID} ${HOME} ${DATA_DIR}

USER ${USER}:${USER}

# Mainnet: p2p (27146), rpc (27147) prometheus(28660), 
EXPOSE 27146 27147

# Testnet: p2p (27146), rpc (27147) prometheus(28660), 
EXPOSE 26656 26657

# prometheus(28660), 
EXPOSE 28660

ENTRYPOINT ["tini", "--"]
CMD bnbchaind start --home ${HOME}

