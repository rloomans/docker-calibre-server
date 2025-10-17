FROM --platform=${BUILDPLATFORM} alpine/curl AS download

ARG CALIBRE_RELEASE="8.13.0"
ARG TARGETPLATFORM

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then ARCH=x86_64; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then ARCH=arm64; \
    else echo "Unsupported target platform: ${TARGETPLATFORM}"; false; fi \
    && URL="https://github.com/kovidgoyal/calibre/releases/download/v${CALIBRE_RELEASE}/calibre-${CALIBRE_RELEASE}-${ARCH}.txz" \
    && echo "fetching $URL" \
    && curl -o /tmp/calibre-tarball.txz -L "$URL" \
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

