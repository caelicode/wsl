# Troubleshooting

## DNS Resolution Fails

**Symptom:** `ping github.com` or `curl` commands fail with "Could not resolve host".

**Fix:** The DNS watcher may not have run yet. Trigger it manually:

```bash
sudo /opt/caelicode/scripts/dns-watch.sh
```

Check what's in `/etc/resolv.conf`:

```bash
cat /etc/resolv.conf
```

If it's empty or has wrong nameservers, the Windows DNS query may have failed. Set fallback manually:

```bash
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

## DNS Breaks After VPN Connect/Disconnect

**Symptom:** DNS worked before connecting to VPN, now it doesn't.

**Expected behavior:** The `dns-watch` timer polls every 5 seconds and should detect the change automatically. If it doesn't:

```bash
# Check the timer is active
systemctl status dns-watch.timer

# Restart it
sudo systemctl restart dns-watch.timer
```

## SSH Keys Not Available

**Symptom:** `ssh-add -l` says "Could not open a connection to your authentication agent" or shows no keys.

**Check the SSH bridge:**

```bash
systemctl status ssh-bridge.service
echo $SSH_AUTH_SOCK
```

**Requirements:**
- Windows OpenSSH Agent must be running (`Get-Service ssh-agent` in PowerShell)
- `npiperelay.exe` must be accessible (checked in common paths: Program Files, scoop, chocolatey)
- Your SSH keys must be added to the Windows agent (`ssh-add` in PowerShell)

## Proxy Not Detected

**Symptom:** `curl` fails behind corporate proxy even though Windows apps work fine.

**Check proxy settings:**

```bash
cat /etc/profile.d/caelicode-proxy.sh
echo $http_proxy
```

**Manual proxy:**

```bash
export http_proxy=http://proxy.corp.example.com:8080
export https_proxy=$http_proxy
export no_proxy=localhost,127.0.0.1,.corp.example.com
```

**Corporate CA certificates:** If your proxy does TLS inspection, you need to import the corporate root CA:

```bash
# Copy the cert to the trust store
sudo cp your-corp-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

## Tool Not Found After Install

**Symptom:** `kubectl` or other tools show "command not found" even though the profile should include them.

**Check mise:**

```bash
mise list
mise doctor
```

**Ensure shims are in PATH:**

```bash
echo $PATH | tr ':' '\n' | grep mise
```

Expected: `/opt/mise/shims` and `/opt/mise/bin` should be in PATH.

**Reinstall tools:**

```bash
mise install
mise reshim
```

## First Login Doesn't Create User

**Symptom:** Dropped into root shell instead of user shell.

**The `run-once` service may have failed:**

```bash
systemctl status run-once.service
journalctl -u run-once.service
```

**Manual user creation:**

```bash
USERNAME="yourname"
useradd -ms /bin/bash "$USERNAME"
usermod -aG sudo "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME
```

Then set default user in `/etc/wsl.conf`:

```ini
[user]
default=yourname
```

Restart WSL: `wsl --shutdown` from PowerShell.

## Image Too Large

**Symptom:** The tar file is larger than expected.

The base image should be ~350MB, SRE ~800MB, dev ~1.2GB, data ~600MB. If significantly larger, the Docker build cache may have included unnecessary layers.

**Clean build:**

```bash
docker builder prune
./build.sh --profile sre --tag v0.1.0
```

## Health Check Fails

Run the verbose health check:

```bash
caelicode-health
```

Each check is independent — a failure in one area doesn't affect others. Address failures individually using the guidance above.
