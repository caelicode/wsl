# Troubleshooting

## DNS Resolution Fails

**Symptom:** `ping github.com` or `curl` commands fail with "Could not resolve host".

**Fix:** Check what's in `/etc/resolv.conf`:

```bash
cat /etc/resolv.conf
```

WSL auto-generates this file on each boot. If it's empty or has wrong nameservers, try restarting WSL from PowerShell:

```powershell
wsl --shutdown
```

Then relaunch. If the problem persists, set DNS manually:

```bash
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

## DNS Breaks After VPN Connect/Disconnect

**Symptom:** DNS worked before connecting to VPN, now it doesn't.

**Fix:** Restart WSL so it picks up the new DNS settings:

```powershell
wsl --shutdown
```

Then relaunch. If that doesn't work, set DNS manually as above.

## Proxy Not Detected

**Symptom:** `curl` fails behind corporate proxy even though Windows apps work fine.

**Check proxy settings:**

```bash
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

## Dropped Into Root Shell

**Symptom:** Shell says `root@...` instead of `caelicode@...`.

**Fix:** Check `/etc/wsl.conf` has the default user:

```ini
[user]
default = caelicode
```

Then restart WSL: `wsl --shutdown` from PowerShell, and relaunch.

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
