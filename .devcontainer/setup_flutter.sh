#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y curl unzip xz-utils git

# Instala Flutter estable (Linux) para Codespaces
if [ ! -d "$HOME/flutter" ]; then
  cd $HOME
  # Puedes actualizar esta versión cuando quieras (estable)
  curl -L -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
  tar xf flutter.tar.xz
fi

echo 'export PATH="$PATH:$HOME/flutter/bin"' >> $HOME/.bashrc
export PATH="$PATH:$HOME/flutter/bin"

flutter doctor -v || true
flutter pub get || true
