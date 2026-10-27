# syntax=docker/dockerfile:1.7
# Build the MeowX standalone core from a pinned meowC commit.
# The upstream OpenWrt package applies the same two patches used here.

ARG GO_IMAGE=golang:1.26-bookworm
FROM ${GO_IMAGE} AS builder

ARG MEOWC_REPO=https://github.com/mmwx-group/meowC.git
ARG MEOWC_COMMIT=1928f639aaa43dfe7fcedc85b6e06e406d86a22c
ARG MEOWX_VERSION=0.3.9
ARG BUILD_TIME=unknown
ARG TARGETOS=linux
ARG TARGETARCH

ENV CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    GOFLAGS=-buildvcs=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git patch \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY patches/ /patches/

RUN git clone --filter=blob:none ${MEOWC_REPO} meowC \
    && cd meowC \
    && git checkout --detach ${MEOWC_COMMIT} \
    && patch -p1 --forward < /patches/001-standalone-inbound.patch \
    && patch -p1 --forward < /patches/002-panel-account.patch

WORKDIR /src/meowC/core/Clash.Meta

RUN go mod download \
    && go build -trimpath \
        -tags 'with_gvisor,no_easytier,no_tailscale,no_zerotier' \
        -ldflags "-s -w -X github.com/metacubex/mihomo/constant.Version=meowx-${MEOWX_VERSION} -X github.com/metacubex/mihomo/constant.BuildTime=${BUILD_TIME}" \
        -o /out/meowx-core .

FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata \
    && mkdir -p /root/.config/mihomo

COPY --from=builder /out/meowx-core /usr/local/bin/meowx-core
COPY entrypoint.sh /entrypoint.sh

RUN chmod 0755 /usr/local/bin/meowx-core /entrypoint.sh

ENV TZ=Asia/Shanghai

VOLUME ["/root/.config/mihomo"]
EXPOSE 7890 7891 7892 9090
STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-d", "/root/.config/mihomo"]
