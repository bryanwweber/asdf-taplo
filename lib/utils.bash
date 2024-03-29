#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/tamasfe/taplo"
TOOL_NAME="taplo"
TOOL_TEST="taplo --help"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	list_github_tags
}

download_release() {
	local version filename url os arch
	version="$1"
	filename="$2"
	os="$(uname | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m)"
	if [ "$os" == "darwin" ] && [ "$arch" == "arm64" ]; then
		arch="aarch64"
	fi

	url="$GH_REPO/releases/download/${version}/taplo-${os}-${arch}.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type version install_path os arch
	install_type="$1"
	version="$2"
	install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		local download_file="$ASDF_DOWNLOAD_PATH/$TOOL_NAME-$version"
		local install_file="$install_path/$TOOL_NAME"
		cp "$download_file" "$install_file"
		chmod +x "$install_file"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
