FROM debian:bookworm-slim AS base

ARG APT_HTTP_PROXY

RUN export DEBIAN_FRONTEND="noninteractive" && \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

FROM --platform=${BUILDPLATFORM} debian:bookworm-slim AS download

ARG CALIBRE_RELEASE="7.18.0"
ARG TARGETPLATFORM

RUN export DEBIAN_FRONTEND="noninteractive" && \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        xz-utils \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        ARCH=x86_64; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        ARCH=arm64; \
    else \
        echo "Unsupported target platform: ${TARGETPLATFORM}"; false; \
    fi && \
    URL="https://github.com/kovidgoyal/calibre/releases/download/v${CALIBRE_RELEASE}/calibre-${CALIBRE_RELEASE}-${ARCH}.txz" && \
    echo "fetching $URL" && \
    curl -o /tmp/calibre-tarball.txz -L "$URL" && \
    mkdir -p /opt/calibre && \
    tar xvf /tmp/calibre-tarball.txz -C /opt/calibre && \
    rm -rf /tmp/*

FROM base AS runtime

LABEL name="Calibre Server"
LABEL maintainer="Robert Loomans <robert@loomans.org>"
LABEL description="A minimal Calibre docker image that runs calibre-server"
LABEL url="https://github.com/rloomans/docker-calibre-server"
LABEL source="https://github.com/rloomans/docker-calibre-server.git"
LABEL org.opencontainers.image.title="Calibre Server"
LABEL org.opencontainers.image.authors="Robert Loomans <robert@loomans.org>"
LABEL org.opencontainers.image.source="https://github.com/rloomans/docker-calibre-server"
LABEL org.opencontainers.image.description="A minimal Calibre docker image that runs calibre-server"

RUN export DEBIAN_FRONTEND="noninteractive" && \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        hicolor-icon-theme \
        iproute2 \
        libegl1 \
        libdeflate0 \
        libfontconfig \
        libglx0 \
        libnss3 \
        libopengl0 \
        libxcomposite1 \
        libxkbcommon0 \
        libxkbfile1 \
        libxrandr2 \
        libxrandr2 \
        libxtst6 \
        libxdamage1 \
        xdg-utils && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/apt/apt.conf.d/apt-proxy.conf

COPY --from=download /opt/calibre /opt/calibre

RUN ln -s /bin/true /usr/local/bin/xdg-desktop-menu && \
    ln -s /bin/true /usr/local/bin/xdg-mime && \
    /opt/calibre/calibre_postinstall --make-errors-fatal && \
    mkdir /library && \
    touch /library/metadata.db

COPY start-calibre-server.sh .

EXPOSE 8080

CMD [ "/start-calibre-server.sh" ]
