#!/usr/bin/env bash

set -euo pipefail

array=()
while IFS=  read -r -d $'\0'; do
    array+=("$REPLY")
done < <(find . -name "*.yaml" -not -path "./.github/*" -print0)

for f in "${array[@]}"; do
  echo "---" "${f}"

  # Check that every name-version-epoch is defined in Makefile
  name=$(yq '.package.name' "${f}")
  version=$(yq '.package.version' "${f}")
  epoch=$(yq '.package.epoch' "${f}")
  want="build-package,${name},${version}-r${epoch}"

  if ! grep -q "${want}" Makefile; then
    echo "missing ${want} in Makefile"
    exit 1
  fi

  # Don't specify packages.wolfi.dev/os as a repository, and remove it from the keyring.
  # Packages from the bootstrap repo should be allowed, but otherwise packages
  # should be fetched locally and the local repository should be appended at
  # build time.
  if grep -q packages.wolfi.dev/os "${f}"; then
    yq -i 'del(.environment.contents.repositories)' "${f}"
    yq -i 'del(.environment.contents.keyring)' "${f}"
  fi
done

# Ensure advisory data and secfixes data are in sync.
echo "

Looking for files with out-of-sync advisory and secfixes data...
"
wolfictl advisory sync-secfixes --warn *.yaml

# And if we make it this far...
echo "All data is in sync!"
