# This Dockerfile is optimized for production. If you want to run it locally in development,
# use the Dockerfile.dev instead.

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.0
ARG DEBIAN_VERSION=bookworm-20260518
# 1.18.4-erlang-27.0-debian-bullseye-20260518
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy runtime config files before build
COPY config/config.exs config/${MIX_ENV}.exs config/runtime.exs ./config/

# compile dependencies
RUN mix deps.compile

# copy source code
COPY lib lib
COPY priv priv

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the OTP app
COPY config/runtime.exs config/

# removes COPY of config files and only adds at runtime
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libssl3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR "/app"

# set the user to nobody
USER nobody

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/grateful_set_crew ./

ENV HOME=/app

CMD ["/app/bin/grateful_set_crew", "start"]
