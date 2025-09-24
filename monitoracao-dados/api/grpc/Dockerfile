FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY api/grpc/grpc-monitor.go ./

COPY api/grpc/proto/ ./api/grpc/proto/

COPY ../../metrics/ ./metrics/

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o grpc-monitor .

FROM alpine:latest

RUN apk --no-cache add ca-certificates

RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/grpc-monitor .
COPY --from=builder /app/api/grpc/proto/ ./api/grpc/proto/

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 50051

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:50051/ || exit 1

CMD ["./grpc-monitor"]