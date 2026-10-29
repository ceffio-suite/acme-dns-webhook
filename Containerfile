# Build dependencies stage
#
# CROSS-COMPILED, NOT EMULATED: the build stage runs on the builder's own
# platform ($BUILDPLATFORM) and produces a binary for $TARGETARCH. Building
# natively under QEMU for arm64 took more than eighteen minutes here, for a
# programme that compiles in seconds — the emulation, not the code, was the cost.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build_deps

# TARGETOS / TARGETARCH are provided by BuildKit for each platform of a
# multi-architecture build.
ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache git

WORKDIR /workspace

# Copy dependency files and download modules
COPY go.mod go.sum ./
RUN go mod download

# Build stage
FROM build_deps AS build

# Copy source code
COPY . .

# Build static binary FOR THE TARGET, from the builder's own architecture.
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -o webhook -ldflags '-s -w -extldflags "-static"' .

# Runtime stage
FROM alpine:3.21

ARG OCI_SOURCE="https://github.com/git001/cert-manager-webhook-libdns"
ARG OCI_REVISION=""
ARG OCI_VERSION=""

LABEL org.opencontainers.image.source="${OCI_SOURCE}" \
      org.opencontainers.image.revision="${OCI_REVISION}" \
      org.opencontainers.image.version="${OCI_VERSION}"

RUN apk add --no-cache ca-certificates bash curl

COPY --from=build /workspace/webhook /usr/local/bin/webhook

# Run as non-root user
USER 1001

ENTRYPOINT ["webhook"]
