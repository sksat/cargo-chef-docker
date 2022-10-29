#!/bin/bash
set -eux

function download_crate() {
	CRATE="$1"
	VERSION="$2"

	mkdir download || exit 1
	cd download || exit 1
	curl -L https://crates.io/api/v1/crates/${CRATE}/${VERSION}/download | gzip -d | tar -xf -
	mv "${CRATE}-${VERSION}" ..
	cd .. || exit 1
	rmdir download
}

# install crate without cargo install
function install_without_install() {
	CRATE="$1"
	VERSION="$2"
	BUILD_OPT="--release --locked"
	if [ $# -ge 3 ] && [ -n "$3" ]; then
		BUILD_OPT="${BUILD_OPT} --target=$3"
	fi

	download_crate "$CRATE" "$VERSION"
	cd "${CRATE}-${VERSION}" || exit 1
	cargo build ${BUILD_OPT}
	cp "target/release/${CRATE}" "$CARGO_HOME/bin"
	cd .. || exit 1
	rm -rf "${CRATE}-${VERSION}"
}

install_without_install "$1" "${2#v}"
