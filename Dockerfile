# AG-VAULT — multi-stage distroless build.
# Build:  docker build -t ag-vault .
# Run:    see docker-compose.yml
#
# SPDX-License-Identifier: AGPL-3.0

FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# static binary, no CGO (modernc sqlite is pure Go)
RUN CGO_ENABLED=0 go build \
    -trimpath \
    -ldflags="-s -w -X main.version=$(git describe --tags --always 2>/dev/null || echo dev)" \
    -o /out/agentvault ./cmd/agentvault

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/agentvault /agentvault
# data dir for the sqlite file (mount a volume here)
VOLUME /data
ENV AGENTVAULT_DB=/data/agentvault.db
EXPOSE 8321
USER nonroot
ENTRYPOINT ["/agentvault"]