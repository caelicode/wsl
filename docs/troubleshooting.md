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

CaeliCode detects the Windows **WinHTTP** proxy on the first shell of
each boot (when `proxy.detect_enabled` is `true` in
`/etc/caelicode/config.yaml`) and writes it to
`/etc/profile.d/caelicode-proxy.sh`.

**Check what was detected:**

```bash
cat /etc/profile.d/caelicode-proxy.sh
echo $http_proxy
```

**Re-run detection after changing Windows proxy settings:**

```bash
sudo /opt/caelicode/current/scripts/proxy-detect.sh
```

Note: many corporate machines configure a *per-user* (WinINET) proxy
that `netsh winhttp` does not see. Import it once on the Windows side:

```powershell
netsh winhttp import proxy source=ie
```

**Manual proxy** (if detection doesn't fit your environment):

```bash
export http_proxy=http://proxy.corp.example.com:8080
export https_proxy=$http_proxy
export no_proxy=localhost,127.0.0.1,.corp.example.com
```

**Corporate CA certificates:** with `proxy.merge_ca_certs: true`,
Windows root CAs are merged into the Linux trust store automatically.
To add one manually:

```bash
sudo cp your-corp-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

## SSH Agent Bridge Not Working

**Symptom:** `ssh-add -l` says "Could not open a connection to your
authentication agent" or lists no keys.

The bridge needs three things:

1. **npiperelay.exe on Windows** — install once:
   ```powershell
   go install github.com/jstarks/npiperelay@latest   # or scoop install npiperelay
   copy "$env:USERPROFILE\go\bin\npiperelay.exe" C:\tools\
   ```
2. **The Windows OpenSSH agent running** (PowerShell as admin):
   ```powershell
   Set-Service ssh-agent -StartupType Automatic
   Start-Service ssh-agent
   ssh-add   # load your keys into the Windows agent
   ```
3. **`ssh.agent_forwarding: true`** in `/etc/caelicode/config.yaml`
   (the default).

The bridge starts on the first shell of each boot. After installing
npiperelay, open a new shell (or run
`/opt/caelicode/current/scripts/caelicode-runtime-init`) and check:

```bash
caelicode-health   # SSH Agent section
```

## Update Notice Won't Go Away / Updates Seem Stuck

**Symptom:** the login banner keeps offering the same update.

Run the updater verbosely and read the output:

```bash
caelicode-update
```

If it reports a checksum failure, retry later (a corrupted download)
— the updater never applies unverified payloads. If your prompt says
the update needs a re-import, run `caelicode-update --full` for the
guide. To see the state the notice is based on:

```bash
cat /var/lib/caelicode/update-state.json
```

An update that went wrong can always be reverted:

```bash
caelicode-update --rollback
```

## Shell Hangs on Launch (Blinking Cursor)

**Symptom:** `wsl -d caelicode-sre` shows a blinking cursor and never produces a prompt.

**Root cause:** WSL inherits the Windows working directory (e.g. `/mnt/c/Windows/System32`) and appends Windows PATH directories by default. Tools like starship and zsh's completion system scan these directories over the slow 9P mount, causing multi-second delays or apparent hangs.

**CaeliCode prevents this by default** via three mechanisms:
1. `appendWindowsPath = false` in `/etc/wsl.conf` (prevents Windows PATH pollution)
2. a `cd ~` guard in `.zshrc` that applies **only** when the shell starts inside `C:\Windows` (project directories under `/mnt` are left alone, so `wsl --cd` and VS Code terminals keep their working directory)
3. `scan_timeout = 500` in starship.toml (prevents starship from blocking on slow directories)

**If you still experience hangs**, try:

```powershell
# Fully restart WSL (changes to wsl.conf require this)
wsl --shutdown
# Wait a few seconds, then relaunch
wsl -d caelicode-sre
```

If that doesn't help, test with a bare shell to isolate whether `.zshrc` is the problem:

```powershell
wsl -d caelicode-sre -- /bin/bash --noprofile --norc
```

If the bare shell works but zsh hangs, the issue is in `.zshrc` — check starship and mise initialization.

## `code .` Not Working

**Symptom:** `code .` says "command not found" or "VS Code not found on the Windows side."

CaeliCode ships a `code` wrapper that finds VS Code on Windows without needing `appendWindowsPath=true`. If it's not working:

**"command not found"** — the wrapper isn't symlinked into PATH. Run:

```bash
sudo ln -sf /opt/caelicode/current/scripts/code /usr/local/bin/code
```

If the script itself is missing, update first: `caelicode-update`

**"VS Code not found"** — the wrapper couldn't locate VS Code. Verify it's installed on Windows and check the detected path:

```bash
# Check what path the wrapper resolves
/mnt/c/Windows/System32/cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r'
```

If your Windows display name differs from your profile folder name (e.g. you renamed your Windows account), make sure the wrapper uses `%USERPROFILE%` — update to v0.9.1+ which handles this correctly.

**Clear the cached path** if VS Code was moved or reinstalled:

```bash
rm -f ~/.cache/caelicode-vscode-path
code .
```

## Other Windows Tools Not Found (docker.exe, explorer.exe, etc.)

**By design:** CaeliCode disables `appendWindowsPath` in `/etc/wsl.conf` to prevent shell startup slowness and mise shim hangs. VS Code has a built-in wrapper (see above), but other Windows tools need to be added manually:

```bash
# Example: add docker.exe to PATH
export PATH="$PATH:/mnt/c/Program Files/Docker/Docker/resources/bin"

# Persist in ~/.zshrc
echo 'export PATH="$PATH:/mnt/c/Program Files/Docker/Docker/resources/bin"' >> ~/.zshrc
```

## Tool Not Found After Install

**Symptom:** `kubectl` or other tools show "command not found" even though the profile should include them.

**Check mise:**

```bash
mise list
```

**Ensure mise bin is in PATH:**

```bash
echo $PATH | tr ':' '\n' | grep mise
```

Expected: `/opt/mise/bin` should be in PATH. Note: CaeliCode uses direct symlinks into `/opt/mise/bin/` instead of mise shims (shims hang in WSL due to network timeouts).

**Re-sync tools and symlinks** (this is what the updater does too):

```bash
sudo caelicode-update --version   # confirm your version
caelicode-update                  # re-runs mise install + relinks /opt/mise/bin
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

Approximate sizes: base ~0.4GB download (~1.1GB on disk), sre ~1.2GB
(~3.5GB), dev ~1.5GB (~4.5GB), data ~0.6GB (~1.8GB). If a local build
is dramatically larger, the Docker build cache may have accumulated
stale layers:

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
