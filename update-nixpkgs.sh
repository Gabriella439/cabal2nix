#! /usr/bin/env bash

set -eu -o pipefail

exit_trap()
{
  local lc="$BASH_COMMAND" rc=$?
  test $rc -eq 0 || echo "*** error $rc: $lc"
}

trap exit_trap EXIT

cd "$(dirname "$0")"
cabal2nix=$(git describe --dirty)

cd nixpkgs
git reset -q --hard
git clean -dxf -q
git pull -q
export NIX_PATH=nixpkgs=$PWD
cd ..

cd hackage
git pull -q
rm -f preferred-versions
for n in */preferred-versions; do
  cat >>preferred-versions "$n"
  echo >>preferred-versions
done
DIR=$HOME/.cabal/packages/hackage.haskell.org
TAR=$DIR/00-index.tar
TARGZ=$TAR.gz
mkdir -p "$DIR"
rm -f "$TAR" "$TARGZ"
git archive --format=tar -o "$TAR" HEAD
gzip -k "$TAR"
hackage=$(git rev-parse --verify HEAD)
cd ..

cabal -v0 new-build hackage2nix
exe=( dist-newstyle/build/$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')/ghc-$(ghc --numeric-version)/cabal2nix-*/build/hackage2nix/hackage2nix )
$exe --nixpkgs="$PWD/nixpkgs" +RTS -M4G -RTS

cd nixpkgs
git add pkgs/development/haskell-modules
if [ -n "$(git status --porcelain)" ]; then
  cat <<EOF | git commit -q -F -
hackage-packages.nix: automatic Haskell package set update

This update was generated by hackage2nix $cabal2nix from Hackage revision
https://github.com/commercialhaskell/all-cabal-hashes/commit/$hackage.
EOF
  git push -q
fi
