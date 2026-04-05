FROM curlimages/curl:8.18.0 AS downloader

# Add ttyd binary
ARG TTYD_VERSION="latest"
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
    x86_64) TTYD_ARCH="x86_64" ;; \
    aarch64) TTYD_ARCH="aarch64" ;; \
    armv7l) TTYD_ARCH="arm" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -L -o /tmp/ttyd "https://github.com/tsl0922/ttyd/releases/${TTYD_VERSION}/download/ttyd.${TTYD_ARCH}" && \
    chmod +x /tmp/ttyd

# Add JQ binary

# Add nats-cli binary
ARG NATS_CLI_VERSION="0.3.0"
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
    x86_64) NATS_ARCH="amd64" ;; \
    aarch64) NATS_ARCH="arm64" ;; \
    armv7l) NATS_ARCH="arm7" ;; \
    armv6l) NATS_ARCH="arm6" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -L -o /tmp/nats.zip "https://github.com/nats-io/natscli/releases/download/v${NATS_CLI_VERSION}/nats-${NATS_CLI_VERSION}-linux-${NATS_ARCH}.zip" && \
    unzip /tmp/nats.zip -d /tmp/ && \
    mv "/tmp/nats-${NATS_CLI_VERSION}-linux-${NATS_ARCH}/nats" /tmp/nats && \
    chmod +x /tmp/nats

FROM alpine:3.19 AS final

# Install rlwrap and bash
RUN apk add --no-cache rlwrap bash

# Copy binaries from downloader stage
COPY --from=downloader /tmp/ttyd /usr/local/bin/ttyd
COPY --from=downloader /tmp/nats /usr/local/bin/nats
COPY nats-eval.sh /usr/local/bin/nats-eval.sh

# Set NATS_URL environment variable
ENV NATS_URL="nats://localhost:4222"

RUN chmod +x /usr/local/bin/nats-eval.sh

# Expose ttyd port
EXPOSE 7681

# Run ttyd with nats eval shell
CMD ["ttyd", "--port", "7681", "--writable", "nats-eval.sh"]
