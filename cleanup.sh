#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Starting system cleanup..."

### 1. Conda caches ###
if command -v conda &>/dev/null; then
  echo "--- Cleaning Conda caches"
  conda clean --yes --all
else
  echo "--- Skipping Conda (not installed)"
fi

### 2. Docker ###
if command -v docker &>/dev/null; then
  echo "--- Pruning Docker unused objects"
  docker system prune --all --volumes --force
else
  echo "--- Skipping Docker (not installed)"
fi

### 3. pip ###
if command -v pip &>/dev/null; then
  echo "--- Purging pip cache"
  pip cache purge
else
  echo "--- Skipping pip (not installed)"
fi

### 4. snap ###
if command -v snap &>/dev/null; then
  echo "--- Removing old snap revisions"
  snap list --all \
    | awk '/disabled/{print $1, $2}' \
    | xargs -r sudo snap remove
  echo "--- (Optional) Limiting future retention to 2 revisions"
  sudo snap set system refresh.retain=2 || true
else
  echo "--- Skipping snap (not installed)"
fi

### 5. APT ###
if command -v apt &>/dev/null; then
  echo "--- Cleaning APT caches and autopurging"
  sudo apt clean
  sudo apt autoremove --purge -y
else
  echo "--- Skipping APT (not a Debian/Ubuntu system)"
fi

### 6. User-level caches & thumbnails ###
echo "--- Clearing user cache & thumbnails"
rm -rf "$HOME/.cache/thumbnails/"*

### 7. Flatpak ###
if command -v flatpak &>/dev/null; then
  echo "--- Uninstalling unused Flatpak runtimes"
  flatpak uninstall --unused -y || true
else
  echo "--- Skipping Flatpak (not installed)"
fi

### 8. Systemd journal logs ###
if command -v journalctl &>/dev/null; then
  echo "--- Vacuuming journal logs older than 2 weeks"
  sudo journalctl --vacuum-time=2weeks
else
  echo "--- Skipping journalctl (not available)"
fi

### 9. Timeshift ###
if command -v timeshift &>/dev/null; then
  echo "--- Disabling Timeshift cron jobs"
  sudo rm -f /etc/cron.d/timeshift \
               /etc/cron.daily/timeshift \
               /etc/cron.hourly/timeshift || true

  echo "--- Deleting all Timeshift snapshots"
  sudo timeshift --list \
    | awk '/^[0-9]/{print $2}' \
    | xargs -r -I{} sudo timeshift --delete --snapshot "{}" || true

  echo "--- (Fallback) Wiping /timeshift/snapshots/**"
  sudo rm -rf /timeshift/snapshots/* || true

  echo "--- Unmounting & removing /timeshift"
  sudo umount /timeshift 2>/dev/null || true
  sudo rmdir /timeshift          2>/dev/null || true

  echo "--- Removing Timeshift config & logs"
  sudo rm -f /etc/timeshift.json /var/log/timeshift-*.log || true

  echo "--- Uninstalling Timeshift"
  if command -v apt &>/dev/null; then
    sudo apt purge --auto-remove -y timeshift || true
  elif command -v snap &>/dev/null; then
    sudo snap remove timeshift || true
  elif command -v dnf &>/dev/null; then
    sudo dnf remove -y timeshift || true
  fi
else
  echo "--- Skipping Timeshift (not installed)"
fi

### Finished ###
echo
echo "✅ Cleanup complete!  Run 'df -h' and 'docker system df' to verify freed space."
