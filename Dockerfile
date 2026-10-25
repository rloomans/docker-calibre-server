FROM --platform=${BUILDPLATFORM} alpine/curl AS download

ARG CALIBRE_RELEASE="9.17.0"
ARG CALIBRE_RELEASE_SHA256_X86_64="953e4512a6482848cd803c88b6d942e6afca65dc3b67c7d1353ae048d616de53"
ARG CALIBRE_RELEASE_SHA256_ARM64="3c72bb26196f8339cfb0914224d824ccbaccbb635f0df9c3a55540ae316199bd"
ARG CALIBRE_RELEASE_SHA512_X86_64="9faf38f6bb0593598208fbde1be247d698a98d9f16e130ca6507049a02b1d9b65f7d10eeca15f5073d0372f7bb2d45d6c63d39a37f1b13a3cbaf81918e715711"
ARG CALIBRE_RELEASE_SHA512_ARM64="4cf033e6b4cd511c7b8db0d1d8e63f245a07416dbc3a96ebb95ec88d78aebeb6d2b91638ef56650eeb1129bd87ef49132a8d36ea179896dfc24b0680e0bcd5fb"
ARG TARGETPLATFORM

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        ARCH=x86_64; SHA256_CHECKSUM="${CALIBRE_RELEASE_SHA256_X86_64}"; SHA512_CHECKSUM="${CALIBRE_RELEASE_SHA512_X86_64}"; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        ARCH=arm64; SHA256_CHECKSUM="${CALIBRE_RELEASE_SHA256_ARM64}"; SHA512_CHECKSUM="${CALIBRE_RELEASE_SHA512_ARM64}"; \
    else echo "Unsupported target platform: ${TARGETPLATFORM}"; false; fi \
    && URL="https://github.com/kovidgoyal/calibre/releases/download/v${CALIBRE_RELEASE}/calibre-${CALIBRE_RELEASE}-${ARCH}.txz" \
    && echo "fetching $URL" \
    && curl -o /tmp/calibre-tarball.txz -L "$URL" \
    && printf '%s  %s\n' "$SHA256_CHECKSUM" /tmp/calibre-tarball.txz | sha256sum -c - \
    && printf '%s  %s\n' "$SHA512_CHECKSUM" /tmp/calibre-tarball.txz | sha512sum -c - \
    && mkdir -p /opt/calibre \
    && tar xvf /tmp/calibre-tarball.txz -C /opt/calibre \
    && rm -rf /tmp/*

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

