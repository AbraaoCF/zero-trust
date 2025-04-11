FROM golang:1.22-alpine as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN apk add --no-cache gcc musl-dev
RUN go build -o main .

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/main /app/
COPY items.db /app/

EXPOSE 8888

CMD ["/app/main"]
