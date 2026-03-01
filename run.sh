#!/usr/bin/env bash
set -e

################
# CONFIG
################
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-idx"

TAILSCALE_AUTH_KEY="tskey-auth-kUirAqiNqR11CNTRL-cr555iT5RXFzRkSnx4WjWF4jZV9kRBCbW"

################
# CHECK
################
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ No qemu"; exit 1; }

################
# PREP
################
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
fi

############################
# BACKGROUND FILE CREATOR
############################
(
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo locnguyen.txt"
    sleep 300
  done
) &
FILE_PID=$!

#################
# TAILSCALE START
#################
echo "🌐 Cài đặt Tailscale..."

if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

sudo tailscale up \
  --authkey="$TAILSCALE_AUTH_KEY" \
  --hostname=win11-qemu \
  --accept-routes \
  --accept-dns \
  --reset

sleep 5

TS_IP=$(tailscale ip -4 | head -n1)

echo "====================================="
echo "🌐 TAILSCALE IP : $TS_IP"
echo "👉 RDP: $TS_IP:$RDP_PORT"
echo "👉 VNC: $TS_IP:5900"
echo "====================================="

#################
# RUN QEMU
#################

cleanup() {
  echo "🧹 Đang dọn dẹp..."
  kill "$FILE_PID" 2>/dev/null || true
  sudo tailscale down || true
}

trap cleanup EXIT

if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  CHẾ ĐỘ CÀI ĐẶT WINDOWS"
  echo "👉 Cài xong quay lại nhập: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Nhập 'xong': " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID"
      rm -f "$ISO_FILE"
      echo "✅ Hoàn tất – lần sau boot thẳng qcow2"
      exit 0
    fi
  done

else
  echo "✅ Windows đã cài – boot thường"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
