#!/bin/bash

suffix=""
if [ $1 == "windows" ]; then
  suffix=".exe"
fi

GOOS=$1 GOARCH=$2 go build -ldflags "-s -w" -o "dist/do-droplets${suffix}"
zip -j dist/do-droplets_$1_$2.zip "dist/do-droplets${suffix}"
rm -rf "dist/do-droplets${suffix}"