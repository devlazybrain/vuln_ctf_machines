#!/bin/bash
# =====================================================================
# build-all.sh — builds the 3 lab boxes with Vagrant + VirtualBox and
# exports portable .ova files into ./ova/
#
# Requirements on the host (Kali):  virtualbox  vagrant
#   sudo apt update && sudo apt install -y virtualbox vagrant
#
# Usage:   ./build-all.sh            # build all three
#          ./build-all.sh m2-webwork # build just one
# =====================================================================
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/ova"
mkdir -p "$OUT"

command -v vagrant   >/dev/null || { echo "ERROR: vagrant not installed";   exit 1; }
command -v VBoxManage>/dev/null || { echo "ERROR: VirtualBox not installed"; exit 1; }

build() {
  local dir="$1" vm="$2"
  echo
  echo "=================================================="
  echo "  Building $dir  ->  VM '$vm'"
  echo "=================================================="
  ( cd "$HERE/$dir" && vagrant up )

  echo "--- powering off $vm ---"
  VBoxManage controlvm "$vm" acpipowerbutton 2>/dev/null || true
  for _ in $(seq 1 30); do
    VBoxManage list runningvms | grep -q "\"$vm\"" || break
    sleep 2
  done
  VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
  sleep 2

  echo "--- exporting -> $OUT/$vm.ova ---"
  rm -f "$OUT/$vm.ova"
  VBoxManage export "$vm" -o "$OUT/$vm.ova" \
    --vsys 0 --product "$vm" --vendor "assessment-lab"

  echo "--- removing vagrant working VM (ova already saved) ---"
  ( cd "$HERE/$dir" && vagrant destroy -f ) || true
  echo "--- $vm.ova done ---"
}

if [ $# -gt 0 ]; then
  case "$1" in
    m1-recovery) build m1-recovery lab-m1-recovery ;;
    m2-webwork)  build m2-webwork  lab-m2-webwork  ;;
    m3-gauntlet) build m3-gauntlet lab-m3-gauntlet ;;
    *) echo "unknown target: $1 (use m1-recovery | m2-webwork | m3-gauntlet)"; exit 1 ;;
  esac
else
  build m1-recovery lab-m1-recovery
  build m2-webwork  lab-m2-webwork
  build m3-gauntlet lab-m3-gauntlet
fi

echo
echo "All done. OVA files are in: $OUT"
ls -lh "$OUT"
