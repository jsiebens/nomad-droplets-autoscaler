SHELL := bash
LDFLAGS := "-s -w"
.PHONY: all

.PHONY: test
test:
	go test ./...

.PHONY: build
build:
	go build -ldflags $(LDFLAGS)

.PHONY: dist
dist:
	mkdir -p dist
	GOOS=linux go build -ldflags $(LDFLAGS) -o dist/do-droplets
	GOOS=darwin go build -ldflags $(LDFLAGS) -o dist/do-droplets-darwin
	GOOS=linux GOARCH=arm GOARM=6 go build -ldflags $(LDFLAGS) -o dist/do-droplets-armhf
	GOOS=linux GOARCH=arm64 go build -ldflags $(LDFLAGS) -o dist/do-droplets-arm64
	GOOS=windows go build -ldflags $(LDFLAGS) -o dist/do-droplets.exe

.PHONY: hash
hash:
	for f in dist/do-droplets*; do shasum -a 256 $$f > $$f.sha256; done