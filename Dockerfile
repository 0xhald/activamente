# Use the official Elixir image
FROM elixir:1.15-alpine

# Install build dependencies
RUN apk add --no-cache build-base npm git python3 curl

# Create app directory and user
RUN addgroup -g 1000 -S phoenix && \
    adduser -S -u 1000 -G phoenix phoenix

# Set working directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set environment
ENV MIX_ENV=prod

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

# Copy config files
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

# Copy assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

# Copy source code
COPY priv priv
COPY lib lib
COPY assets assets

# Build assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Build the release
RUN mix release

# Start a new build stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++

# Create user
RUN addgroup -g 1000 -S phoenix && \
    adduser -S -u 1000 -G phoenix phoenix

# Set working directory
WORKDIR /app

# Copy the release from previous stage
COPY --from=0 --chown=phoenix:phoenix /app/_build/prod/rel/activamente ./

# Create necessary directories
RUN mkdir -p /app/tmp

# Change ownership
RUN chown -R phoenix:phoenix /app

USER phoenix

# Expose port
EXPOSE 4000

# Set environment
ENV HOME=/app

# Start the application
CMD ["/app/bin/activamente", "start"]