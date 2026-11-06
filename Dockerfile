FROM --platform=${BUILDPLATFORM} alpine/curl AS download

ARG CALIBRE_RELEASE="9.18.0"
ARG CALIBRE_RELEASE_SHA256_X86_64="da638166fb3dd204be77cf0f871a40d803536b3e5948969c5233b8e4f1e1dbe6"
ARG CALIBRE_RELEASE_SHA256_ARM64="7f29f1786dcfc5b6f3b6d29b245998a6701501169fbd4c853f17c35d3a635e91"
ARG CALIBRE_RELEASE_SHA512_X86_64="3ebb6cb35d0f990e17e13b24bbe3dc62069dce47c72ac4624539c91e9c956ea2635215d0614153db17aab69e377a8b59d28fc30665732d62d34f27751dc04041"
ARG CALIBRE_RELEASE_SHA512_ARM64="531c519ddfb0eb00186acd84c31aeb9c63526f5ec96ff880621c6a45b3459d4599c859d0e00b2da5fec1f5340d0828ad98f0b2c212f5dc015ad2ebeff8467111"
ARG TARGETPLATFORM

RUN --mount=type=cache,target=/cache \
    if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        ARCH=x86_64; SHA256_CHECKSUM="${CALIBRE_RELEASE_SHA256_X86_64}"; SHA512_CHECKSUM="${CALIBRE_RELEASE_SHA512_X86_64}"; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        ARCH=arm64; SHA256_CHECKSUM="${CALIBRE_RELEASE_SHA256_ARM64}"; SHA512_CHECKSUM="${CALIBRE_RELEASE_SHA512_ARM64}"; \
    else echo "Unsupported target platform: ${TARGETPLATFORM}"; false; fi \
    && URL="https://github.com/kovidgoyal/calibre/releases/download/v${CALIBRE_RELEASE}/calibre-${CALIBRE_RELEASE}-${ARCH}.txz" \
    && TARBALL="/cache/calibre-${CALIBRE_RELEASE}-${ARCH}.txz" \
    && verify() { \
        printf '%s  %s\n' "$SHA256_CHECKSUM" "$TARBALL" | sha256sum -c - \
        && printf '%s  %s\n' "$SHA512_CHECKSUM" "$TARBALL" | sha512sum -c -; \
    } \
    && if [ -f "$TARBALL" ] && verify; then \
        echo "using cached $TARBALL"; \
    else \
        rm -f "$TARBALL" \
        && echo "fetching $URL" \
        && curl -fL -o "$TARBALL.part" "$URL" \
        && mv "$TARBALL.part" "$TARBALL" \
        && verify; \
    fi \
    && mkdir -p /opt/calibre \
    && tar xvf "$TARBALL" -C /opt/calibre

FROM debian:trixie-slim AS runtime

LABEL name="Calibre Server"
LABEL maintainer="Robert Loomans <robert@loomans.org>"
LABEL description="A minimal Calibre docker image that runs calibre-server"
LABEL url="https://github.com/rloomans/docker-calibre-server"
LABEL source="https://github.com/rloomans/docker-calibre-server.git"
LABEL org.opencontainers.image.title="Calibre Server"
LABEL org.opencontainers.image.authors="Robert Loomans <robert@loomans.org>"
LABEL org.opencontainers.image.source="https://github.com/rloomans/docker-calibre-server"
LABEL org.opencontainers.image.description="A minimal Calibre docker image that runs calibre-server"

ARG APT_HTTP_PROXY

RUN export DEBIAN_FRONTEND="noninteractive" \
    && if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        hicolor-icon-theme \
        iproute2 \
        libasound2 \
        libdeflate0 \
        libegl1 \
        libfontconfig \
        libglx0 \
        libnss3 \
        libopengl0 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxkbfile1 \
        libxrandr2 \
        libxrandr2 \
        libxtst6 \
        xdg-utils \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN ln -s /bin/true /usr/local/bin/xdg-desktop-menu \
    && ln -s /bin/true /usr/local/bin/xdg-mime

RUN groupadd -g 1234 appgroup && \
    useradd -m -u 1234 -g appgroup --home-dir /app appuser

RUN mkdir /library \
    && touch /library/metadata.db \
    && mkdir /config \
    && touch /config/server-users.sqlite \
    && chown -R appuser:appgroup /config

VOLUME /library
VOLUME /config

COPY --from=download /opt/calibre /opt/calibre

RUN /opt/calibre/calibre_postinstall --make-errors-fatal

COPY start-calibre-server.sh /

EXPOSE 8080

WORKDIR /app

USER appuser:appgroup

CMD [ "/start-calibre-server.sh" ]

