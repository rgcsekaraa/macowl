# Simple shortcuts for macowl. Run `make help` to see them.

.PHONY: help build dmg compile icon run clean

help:
	@echo "macowl make targets:"
	@echo "  make build    - build and install to /Applications, then launch"
	@echo "  make dmg      - build a distributable DMG into ./dist"
	@echo "  make compile  - just compile main.swift to check it builds"
	@echo "  make icon     - render the icon to /tmp/macowl.iconset and open it"
	@echo "  make run      - same as build"
	@echo "  make clean    - remove build and dist output"

build:
	./build.sh

run: build

dmg:
	./build-dmg.sh

compile:
	swiftc -O -o /tmp/macowl main.swift
	@echo "OK, compiles."

icon:
	swift makeicon.swift /tmp/macowl.iconset
	open /tmp/macowl.iconset

clean:
	rm -rf build dist
	@echo "Cleaned build and dist."
