# SSH Tunnel Setup

## Commands

### Phone Termux

```bash
# To Fedora
ssh -J tunnel@ssh.yongbeom.net -p 2222 yongbeom_kim@localhost \
  -t 'tmux -u new-session -A -s hydragen -c ~/Documents/Personal/Dev/hydragen-v2'

# To MacOS
ssh -J tunnel@ssh.yongbeom.net -p 2223 bytedance@localhost \
  -t 'tmux -u new-session -A -s claude-mcp -c ~/Dev/bytedance/claude-mcp'
```

### Fedora
```bash
# Do not sleep
# Note: you can't close the lid
systemd-inhibit --what=idle --who="reverse-ssh" --why="Keep SSH tunnel alive" sleep infinity
```

### MacOS
```bash
caffeinate -i
```

## On the VPS

### 1. User + Keys

```bash
# Create user
sudo adduser tunnel
# Copy keys (both phone and laptop)
# ...
```

### 2. sshd Config

```bash
sudo nano /etc/ssh/sshd_config
```

Add to `AllowUsers`:

```text
AllowUsers ... tunnel
```

Add at bottom:

```text
Match User tunnel
    AllowTcpForwarding yes
    PermitOpen localhost:2222 localhost:2223
    X11Forwarding no
    AllowAgentForwarding no
    PermitTTY no
    ForceCommand /bin/false
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

## On Laptop (Fedora) (port 2222)

### 1. sshd Config

```bash
sudo vim ~/.ssh/authorized_keys
# Add public key of phone termux
```

```bash
sudo systemctl enable --now sshd
sudo systemctl status sshd --no-pager
```

### 2. Autossh

Command:

```bash
autossh -M 0 -N -T \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -R 2222:localhost:22 tunnel@ssh.yongbeom.net
```

### 3. Create User Service

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/reverse-ssh.service
```

Service file contents:

```ini
[Unit]
Description=Reverse SSH Tunnel to VPS
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/autossh -M 0 -N -T \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -R 2222:localhost:22 tunnel@ssh.yongbeom.net
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable reverse-ssh
systemctl --user start reverse-ssh
systemctl --user status reverse-ssh --no-pager
sudo loginctl enable-linger yongbeom_kim
```

## On Laptop (MacOS) (port 2223)

### 1. Enable Remote Login

```bash
sudo systemsetup -setremotelogin on
sudo dseditgroup -o edit -a $(whoami) -t user com.apple.access_ssh
```

### 2. Public Keys

- Public key from phone on MacOS `~/.ssh/authorized_keys`
- Public key from MacOS on VPS `~tunnel/.ssh/authorized_keys`

### 3. Test MacOS SSH

```bash
ssh tunnel@ssh.yongbeom.net
# Expected:
# PTY allocation request failed on channel 0
# Connection to ssh.yongbeom.net closed.
```

### 4. Test Phone --> VPS --> MacOS SSH

On MacOS:

```bash
autossh -M 0 -N -T \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -R 2223:localhost:22 tunnel@ssh.yongbeom.net
```

On phone:

```bash
ssh -J tunnel@ssh.yongbeom.net -p 2223 your_mac_username@localhost
```

### 5. Create LaunchDaemon

```bash
sudo vim /Library/LaunchDaemons/com.yongbeom.reverse-ssh-mac.plist
sudo chown root:wheel /Library/LaunchDaemons/com.yongbeom.reverse-ssh-mac.plist
sudo chmod 644 /Library/LaunchDaemons/com.yongbeom.reverse-ssh-mac.plist
sudo launchctl unload /Library/LaunchDaemons/com.yongbeom.reverse-ssh-mac.plist
sudo launchctl load /Library/LaunchDaemons/com.yongbeom.reverse-ssh-mac.plist
```

Plist contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>com.yongbeom.reverse-ssh-mac</string>

  <key>UserName</key>
  <string>your_mac_username</string>

  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/autossh</string>
    <string>-M</string><string>0</string>
    <string>-N</string>
    <string>-T</string>
    <string>-o</string><string>ExitOnForwardFailure=yes</string>
    <string>-o</string><string>ServerAliveInterval=30</string>
    <string>-o</string><string>ServerAliveCountMax=3</string>
    <string>-R</string><string>2223:localhost:22</string>
    <string>-i</string>
    <string>/Users/your_mac_username/.ssh/id_ed25519</string>
    <string>tunnel@ssh.yongbeom.net</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/tmp/reverse-ssh-mac.log</string>

  <key>StandardErrorPath</key>
  <string>/tmp/reverse-ssh-mac.err</string>

</dict>
</plist>
```

### 6. Verify LaunchDaemon

```bash
sudo launchctl list | grep reverse
sudo launchctl print system/com.yongbeom.reverse-ssh-mac
```
