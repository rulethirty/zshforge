#!/bin/sh
set -e

echo "==> Detecting package manager..."

detect_pkg_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo "unknown"
  fi
}

PKG_MANAGER="$(detect_pkg_manager)"

if [ "$PKG_MANAGER" = "unknown" ]; then
  echo "ERROR: No supported package manager found (brew, dnf, yum, pacman, apt, apk)."
  exit 1
fi

echo "=> Using $PKG_MANAGER"

echo "==> 1. Installing dependencies..."

case "$PKG_MANAGER" in
brew)
  brew update
  brew install zsh git curl ca-certificates
  ;;
dnf)
  dnf check-update || true
  dnf install -y zsh git curl ca-certificates
  ;;
yum)
  yum check-update || true
  yum install -y zsh git curl ca-certificates
  ;;
pacman)
  pacman -Sy --noconfirm zsh git curl ca-certificates
  ;;
apt)
  apt-get update
  apt-get install -y zsh git curl ca-certificates
  ;;
apk)
  apk update
  apk add --no-cache zsh git git-http curl ca-bundle
  ;;
esac

ZSH_PATH="$(command -v zsh)"
if [ -z "$ZSH_PATH" ]; then
  echo "ERROR: zsh was not found after installation."
  exit 1
fi

echo "==> 2. Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "=> Oh My Zsh already installed."
fi

echo "==> 3. Installing plugins..."
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

echo "==> 4. Enabling plugins in ~/.zshrc..."
if [ ! -f "$HOME/.zshrc" ]; then
  echo "ERROR: ~/.zshrc not found."
  exit 1
fi

if grep -q "^plugins=" "$HOME/.zshrc"; then
  if ! grep -q "zsh-syntax-highlighting" "$HOME/.zshrc"; then
    sed -i 's/^plugins=(\(.*\))/plugins=(git zsh-autosuggestions zsh-syntax-highlighting \1)/' "$HOME/.zshrc"
  fi
else
  if grep -q "^ZSH_THEME=" "$HOME/.zshrc"; then
    sed -i '/^ZSH_THEME=.*/a\plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc"
  else
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >>"$HOME/.zshrc"
  fi
fi

echo "==> 5. Setting Zsh as default shell..."
CURRENT_SHELL=$(grep "^$(whoami):" /etc/passwd | cut -d: -f7)
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
  if command -v chsh >/dev/null 2>&1; then
    chsh -s "$ZSH_PATH"
  else
    if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "$ZSH_PATH" >>/etc/shells
    fi
    awk -F: -v OFS=: -v user="$(whoami)" -v shell="$ZSH_PATH" \
      '$1 == user {$7 = shell} {print}' /etc/passwd >/tmp/passwd.new
    cat /tmp/passwd.new >/etc/passwd
    rm -f /tmp/passwd.new
  fi
  echo "=> Default shell changed to $ZSH_PATH."
else
  echo "=> Zsh is already the default shell."
fi

echo "==> ALL DONE! <=="
echo "Log out and log back in, or type 'zsh' to use your new shell."
