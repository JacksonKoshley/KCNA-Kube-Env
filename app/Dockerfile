# Multi-stage build: compile in a full Go image, ship only the binary.

# --- Stage 1: build ---
FROM golang:1.26-alpine AS build
WORKDIR /src
# Copy go.mod first so this layer is cached until dependencies change.
COPY go.mod ./
COPY main.go ./
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/demo-app .

# --- Stage 2: runtime ---
# distroless: no shell, no package manager, runs as a non-root user.
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /out/demo-app /demo-app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/demo-app"]
