#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/root"
PYTHON_BIN="python3"
VENV_DIR="$APP_DIR/.venv"
SERVICE_PORT="8080"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

apt-get update
apt-get install -y python3 python3-venv python3-pip apksigner || apt-get install -y python3 python3-venv python3-pip android-sdk-build-tools

APKSIGNER_PATH="$(command -v apksigner 2>/dev/null || true)"

if [ -z "$APKSIGNER_PATH" ]; then
  APKSIGNER_PATH="$(find /usr -name apksigner 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$APKSIGNER_PATH" ]; then
  echo "apksigner not found"
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install fastapi uvicorn httpx

cat > "$APP_DIR/.env" <<EOF
CS_API_URL="https://your-api.com"
VPS_AUTH_SECRET="your-auth-secret"
POLL_INTERVAL="30"
APKSIGNER_BIN="$APKSIGNER_PATH"
EOF

cat > /etc/systemd/system/safehaven-scanner.service <<EOF
[Unit]
Description=SafeHaven APK Scanner
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/uvicorn safehaven_scanner:app --host 0.0.0.0 --port $SERVICE_PORT --workers 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable safehaven-scanner
systemctl restart safehaven-scanner
systemctl status safehaven-scanner --no-pager