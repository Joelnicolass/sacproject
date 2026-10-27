# MpKit game server in a container (Fly.io, or any host that runs Docker images). The build context is the game's
# project folder; this file stays in the addon (fly.toml points at it). No export templates needed: the official
# headless Godot of GODOT_VERSION runs the project as is, as `godot --headless --path .` does on your PC, and a room
# server starts its matches the same way. The server connects out to the relay: no port to open.
#
#   docker build -f addons/mp_kit/deploy/fly/Dockerfile --build-arg GODOT_VERSION=4.7.2 -t my-game-server .
#   docker run -e MPKIT_RELAY_SECRET=... -e GAME_ARGS="--room-server" my-game-server
#
# GAME_ARGS: the kit's flags after `--` (--room-server or --dedicated, --transport=relay, --relay-url=...).
# The host secret only by the environment (MPKIT_RELAY_SECRET: `fly secrets`), never in an image or a file.

ARG GODOT_VERSION=4.7.2

FROM debian:bookworm-slim AS godot
ARG GODOT_VERSION
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /godot
# The official build, checked against the release's SHA512-SUMS.txt.
RUN set -eu; \
    arch="$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x86_64)"; \
    base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"; \
    file="Godot_v${GODOT_VERSION}-stable_linux.${arch}.zip"; \
    curl -fsSLO "$base/$file"; \
    curl -fsSLO "$base/SHA512-SUMS.txt"; \
    grep " $file\$" SHA512-SUMS.txt | sha512sum -c -; \
    unzip -q "$file"; \
    mv "Godot_v${GODOT_VERSION}-stable_linux.${arch}" /godot/godot; \
    chmod +x /godot/godot; \
    rm -f "$file" SHA512-SUMS.txt

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/game game \
    && install -d -o game -g game /app
COPY --from=godot /godot/godot /usr/local/bin/godot
WORKDIR /app
COPY --chown=game:game . /app
USER game
# Import once while building, so the server starts at once (and the same every time). Godot exits 0 even when the
# import fails, so the build checks what it must leave: the script class cache (the kit's class_name types).
RUN godot --headless --path /app --import \
    && test -f /app/.godot/global_script_class_cache.cfg \
    || { echo "the project did not import (see the errors above): no .godot/global_script_class_cache.cfg" >&2; exit 1; }
ENV GAME_ARGS="--room-server"
CMD ["sh", "-c", "exec godot --headless --path /app -- $GAME_ARGS"]
