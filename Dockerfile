FROM --platform=${BUILDPLATFORM} alpine/curl AS download

ARG CALIBRE_RELEASE="9.19.0"
ARG CALIBRE_RELEASE_SHA256_X86_64="35c1cbda1a2548aceeb89cb0a4be47a36025b5dc102ac046f7eaf98ba46a452d"
ARG CALIBRE_RELEASE_SHA256_ARM64="8de5c5d3af3f28e0227e215a27e8d69c14c50a38cc3065b249996997df392a2f"
ARG CALIBRE_RELEASE_SHA512_X86_64="907e477a74f1292deaea822a1dc110fd420fcfc6d4e62746edbfd9749b15a87513fb4c8047f1e9dd39726a980fbe80de1cf74ce1868f7943268716840ab278e7"
ARG CALIBRE_RELEASE_SHA512_ARM64="a673f7c52a18d209b36ec0cc3112d0f2affc1f9d8dd801f7aceb2999ecf1029aae0dab5956ca968ba10891a39bf5281cb9b8d1d445e515bd85df7ed8be470343"
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

