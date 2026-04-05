# Pi

Docker compose files for services running on my Raspberry Pi 5

Things to set up:
- Tailscale:
  - `curl -fsSL https://tailscale.com/install.sh | sh`
  - `sudo tailscale up --ssh --operator=krishnan`
- SSH to GitHub:
  - `ssh-keygen -t ed25519 -C "krishnans2006@gmail.com"`
  - `cat ~/.ssh/id_ed25519.pub`
  - `ssh -T git@github.com`
- https://sdr-enthusiasts.gitbook.io/ads-b/setting-up-the-host-system/running-docker-install
- Set up storage:
  - `sudo fdisk /dev/nvme0n1` to match: `/dev/nvme0n1p1  2048 1000214527 1000212480 476.9G Linux filesystem`
  - `sudo mkfs.ext4 /dev/nvme0n1p1`
  - `sudo blkid` to get the UUID of `/dev/nvme0n1p1`
  - `sudo nano /etc/fstab` to add `UUID=XXX /data ext4 defaults,noatime 0 2`
- Add Jellyfin user:
  - `sudo useradd -m jellyfin`
  - `id jellyfin` to get UID and GID, which goes in `jellyfin/compose.yaml`
