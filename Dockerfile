# syntax=docker/dockerfile:1
#
# Docker image for lean4web (https://github.com/leanprover-community/lean4web)
# Always built from a release tag, never from `main`.
#
#   docker build --build-arg LEAN4WEB_VERSION=v0.2.2 -t lean4web:v0.2.2 .

ARG LEAN4WEB_VERSION=v0.2.2
ARG NODE_VERSION=25

############################
# Stage 1: fetch source at the release tag
############################
FROM alpine/git:latest AS source
ARG LEAN4WEB_VERSION
RUN test -n "${LEAN4WEB_VERSION}" \
 && git clone --depth 1 --branch "${LEAN4WEB_VERSION}" --recurse-submodules \
      https://github.com/leanprover-community/lean4web.git /src \
 && rm -rf /src/.git

############################
# Stage 2: build the web client
############################
FROM node:${NODE_VERSION}-bookworm AS client
WORKDIR /app
COPY --from=source /src /app
RUN npm ci && npm run build:client

############################
# Stage 3: runtime (node server + Lean/elan + prebuilt Lean projects)
############################
FROM node:${NODE_VERSION}-bookworm-slim AS runtime
ARG LEAN4WEB_VERSION
# Set to "false" to drop the (large) Mathlib project from the image.
ARG WITH_MATHLIB=true

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*

# Run as a non-root user
RUN useradd --create-home --shell /bin/bash lean
USER lean
ENV ELAN_HOME=/home/lean/.elan \
    PATH=/home/lean/.elan/bin:$PATH

RUN curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      | sh -s -- -y --no-modify-path --default-toolchain none

WORKDIR /app
COPY --from=source --chown=lean:lean /src /app

# Server runtime deps only
RUN npm ci --omit=dev --workspace server --include-workspace-root=false \
 && npm cache clean --force

# Build the bundled Lean projects (Projects/*/leanweb-build.sh)
RUN if [ "${WITH_MATHLIB}" != "true" ]; then rm -rf Projects/MathlibDemo; fi \
 && ./server/build.sh \
 && rm -rf /home/lean/.cache/mathlib

# Prebuilt client
COPY --from=client --chown=lean:lean /app/client/dist /app/client/dist

# Bubblewrap does not work inside an unprivileged container; the container
# itself is the sandbox.
ENV NODE_ENV=production \
    PORT=8080 \
    NO_BWRAP=true \
    PROJECTS_BASE_PATH=Projects \
    LEAN4WEB_VERSION=${LEAN4WEB_VERSION}

LABEL org.opencontainers.image.title="lean4web" \
      org.opencontainers.image.version="${LEAN4WEB_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0"

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD curl -fsS http://localhost:8080/ >/dev/null || exit 1

CMD ["node", "server/index.mjs"]
