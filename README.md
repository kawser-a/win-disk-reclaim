# win-disk-reclaim

Free up space on a full Windows `C:` drive **safely**, without clicking through thousands of folders by hand.

The core of this repo is `Review-DiskSpace.ps1`, an interactive PowerShell script that finds the biggest files and folders, shows them largest first, and asks you what to do with each one. Nothing is deleted unless you choose it, and deleted items go to the Recycle Bin so you can undo mistakes.

The rest of this README is a field guide: which folders are usually safe to delete, which ones to clean another way, and the built-in Windows commands that reclaim space the script can't touch.

---

## Contents

- [Quick start](#quick-start)
- [How the script works](#how-the-script-works)
- [Options](#options)
- [Safety features](#safety-features)
- [Where the space usually goes](#where-the-space-usually-goes)
- [What's safe to delete](#whats-safe-to-delete)
- [Built-in Windows cleanup commands](#built-in-windows-cleanup-commands)
- [Developer caches](#developer-caches)
- [WSL, Docker and browsers](#wsl-docker-and-browsers)
- [Recommended order](#recommended-order)
- [Troubleshooting](#troubleshooting)
- [Disclaimer](#disclaimer)

---

## Quick start

**Requirements:** Windows 10 or 11, Windows PowerShell 5.1 (built in) or PowerShell 7.

1. Download `Review-DiskSpace.ps1` (or clone this repo):
   ```powershell
   git clone https://github.com/kawser-a/win-disk-reclaim.git
   cd win-disk-reclaim
   ```
2. Open PowerShell **as administrator**: Start → type `PowerShell` → right-click → **Run as administrator**.
3. Go to the folder containing the script, for example:
   ```powershell
   cd $HOME\Downloads\win-disk-reclaim
   ```
4. Run it on the whole drive:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path C:\ -Top 30 -MinSizeMB 100
   ```
5. When you're finished, **empty the Recycle Bin**. Space is not actually freed until you do.

> Running without admin rights also works, but some system folders can't be measured, so their sizes will be understated.

---

## How the script works

The script scans a folder, measures every item inside it, and lists the largest first:

```
Largest items in C:\Users\you\AppData\Local:
  1. DIR     21.33 GB  Google
  2. DIR      4.46 GB  npm-cache
  3. DIR      1.68 GB  ms-playwright
  ...

[2/30] C:\Users\you\AppData\Local\npm-cache
        Size: 4.46 GB   Last modified: 2025-06-25   Type: Folder
[K]eep  [D]elete to Recycle Bin  [O]pen in Explorer  [E]nter folder  [Q]uit:
```

Then it goes through the items one by one. At each prompt, type a letter and press **Enter**:

| Key | Action |
|-----|--------|
| **K** | Keep it and move to the next item (pressing Enter alone also keeps) |
| **D** | Send it to the Recycle Bin (asks `y/n` to confirm) |
| **O** | Open it in File Explorer so you can see what's inside |
| **E** | Enter the folder and review *its* contents the same way |
| **Q** | Quit the script |

**Navigating:** there is no "back" key. When you finish the last item in a folder (by pressing **K** or **D**), the script automatically returns to the folder above. To skip the rest of a long list, press **Q** and run the script again on another path.

**Each D deletes only the one item named in the current prompt.** Nothing else is touched.

---

## Options

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `-Path` | your user folder | Where to start scanning |
| `-Top` | `20` | How many of the largest items to show per folder |
| `-MinSizeMB` | `50` | Hide items smaller than this |

Examples:

```powershell
# Whole C: drive, top 30 items over 100 MB
powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path C:\ -Top 30 -MinSizeMB 100

# Jump straight to the usual worst offender
powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path $env:LOCALAPPDATA -Top 30 -MinSizeMB 20

# Just your Downloads folder
powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1 -Path $HOME\Downloads
```

---

## Safety features

- **Recycle Bin, not permanent delete.** Changed your mind? Open the Recycle Bin, right-click the item, choose **Restore**.
- **Confirmation on every delete.** `D` always asks `y/n` first.
- **Protected locations.** These can be browsed but never deleted by the script:
  - `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData` and everything inside them
  - `C:\System Volume Information`, `C:\$Recycle.Bin`, `C:\Recovery`, `C:\Boot`
  - `pagefile.sys`, `hiberfil.sys`, `swapfile.sys`
  - `C:\Users`, your profile folder itself, `AppData`, `AppData\Local`, `AppData\Roaming`, `AppData\LocalLow` (their *contents* can be reviewed)
- **Log file.** Every deletion is recorded in `cleanup-log.txt` next to the script, with date, size and path.
- **Locked files are skipped.** If an app is using a folder, the script reports "Could not delete" and moves on. Close the app and try again.

> Items too large for the Recycle Bin make Windows ask whether to delete them permanently. Read that dialog before clicking Yes.

---

## Where the space usually goes

On a typical developer or student laptop:

```
C:\
├── Users\<you>\                    ← usually the biggest; most reclaimable space is here
│   ├── AppData\Local\              ← caches, browser data, WSL, dev tools
│   ├── AppData\Roaming\            ← app settings and some caches
│   ├── Downloads\                  ← old installers, ISOs, zips
│   └── .cache, .conda, node_modules in old projects
├── Windows\                        ← don't touch by hand; use DISM / Disk Cleanup
├── Program Files\ (x86)\           ← uninstall apps from Settings instead
├── pagefile.sys                    ← leave alone
└── hiberfil.sys                    ← removable with powercfg -h off
```

Start with `C:\`, then press **E** on the largest folder each time:
**Users → \<you\> → AppData → Local**.

---

## What's safe to delete

### ✅ Safe to delete (D)
These are caches or leftovers that rebuild themselves or are never needed again.

| Folder (under `AppData\Local` unless noted) | What it is |
|---|---|
| `Temp` | Temporary files |
| `npm-cache` | npm download cache |
| `pip` | pip download cache |
| `Yarn\Cache`, `pnpm-cache` | Yarn / pnpm caches |
| `ms-playwright` | Playwright test browsers (`npx playwright install` restores them) |
| `CrashDumps` | Crash logs |
| `gpucache`, `D3DSCache` | GPU shader caches |
| `Microsoft\TypeScript` | VS Code's TypeScript type cache |
| `Raspberry Pi` | Raspberry Pi Imager's download cache |
| `*-updater` folders (e.g. `hyper-updater`) | Old update installers |
| `Arduino15\staging` | Downloaded Arduino board installers |
| Folders of apps you've already uninstalled | Leftovers |
| `%USERPROFILE%\.cache` | Model and tool caches (Hugging Face, torch, pip); redownloaded on demand |
| `node_modules` in old projects | `npm install` restores them |

### ⚠️ Clean *inside*, don't delete the whole folder
Press **E** and delete only the cache subfolders. Close the app first.

| Folder | Delete inside | Keep |
|---|---|---|
| `Roaming\Code` (VS Code) | `Cache`, `CachedData`, `CachedExtensionVSIXs`, `workspaceStorage` | `User` (your settings) |
| `Roaming\discord` | `Cache`, `Code Cache` | everything else |
| `Local\Google\Chrome\User Data` | `OptGuideOnDeviceModel` (Chrome's on-device AI model, often 2–4 GB) | `Default`, `Profile N` |
| `Local\Google\Chrome\User Data\Default` | `Cache`, `Code Cache`, `Service Worker` | everything else |
| `Local\Arduino15` | `staging` | `packages` if you still use those boards |

### ⛔ Keep (K)
Deleting these breaks apps or loses data.

| Folder | Why |
|---|---|
| `Local\Google`, `Local\BraveSoftware`, `Local\Microsoft\Edge` (whole folder) | Your browser profile: bookmarks, passwords, history, logins |
| `Local\Packages` | Microsoft Store app data, including **WSL Linux disks** |
| `Local\Programs` | Installed apps (VS Code, Python…); uninstall from Settings instead |
| `Local\Microsoft`, `Local\Microsoft\WinGet` | Windows components and apps installed with `winget` |
| `Roaming\npm` | Your global npm packages |
| `Roaming\nvm` | Your Node.js versions; remove old ones with `nvm uninstall <version>` |
| `ConnectedDevicesPlatform`, `Microsoft\Windows`, `FontCache` | Windows components |
| Anything you don't recognize | Press **O** to look first. When in doubt, keep it. |

---

## Built-in Windows cleanup commands

Run these in **PowerShell as administrator**.

### Disk Cleanup (system files)
```powershell
cleanmgr
```
Pick `C:` → click **Clean up system files** → pick `C:` again, then tick:
- Windows Update Cleanup
- Delivery Optimization Files
- Temporary files
- Previous Windows installation(s) (`Windows.old`, if present; often 10+ GB)

This also removes leftover folders like `C:\$WinREAgent`.

### Shrink WinSxS (Windows component store)
`C:\Windows\WinSxS` often looks huge (10–20 GB). **Never delete from it manually.** Let Windows clean it:

```powershell
# See how much can be reclaimed
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore

# Remove superseded update files (safe; takes 5–15 min, may pause at 10% or 20%)
Dism.exe /Online /Cleanup-Image /StartComponentCleanup
```

Optional, more aggressive: adding `/ResetBase` frees more space, but you can **no longer uninstall** currently installed updates.
```powershell
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

### Turn off hibernation (frees `hiberfil.sys`, several GB)
Only if you never use Hibernate. This also disables Fast Startup.
```powershell
powercfg -h off
# undo:
powercfg -h on
```

### Clear the Temp folder
```powershell
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
```
Files in use are skipped automatically.

### Storage Sense (automatic, ongoing)
**Settings → System → Storage → Storage Sense → On.** It empties Temp and the Recycle Bin on a schedule, so the drive doesn't fill up again.

### Uninstall unused apps
**Settings → Apps → Installed apps → Sort by: Size.** Uninstalling properly is always better than deleting a program's folder.

---

## Developer caches

All of these are safe; the tools redownload what they need.

```powershell
npm cache clean --force        # npm
pip cache purge                # pip
yarn cache clean               # Yarn
pnpm store prune               # pnpm
dotnet nuget locals all --clear  # NuGet
conda clean --all              # Conda / Anaconda
```

Find and remove `node_modules` in old projects (review the list before deleting):
```powershell
# List node_modules folders under a projects directory
Get-ChildItem -Path D:\Projects -Directory -Recurse -Filter node_modules -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch 'node_modules.+node_modules' } |
    Select-Object FullName
```
Then point the script at that projects folder and delete the ones you don't need.

---

## WSL, Docker and browsers

### WSL (Ubuntu and other distros)
The Linux disk lives in `AppData\Local\Packages\<Distro>\LocalState\ext4.vhdx`. It grows but never shrinks on its own. **Don't delete it from Explorer.**

```powershell
# List installed distros
wsl -l -v

# Let Windows reclaim unused space automatically (WSL 2.0+)
wsl --shutdown
wsl --manage Ubuntu-24.04 --set-sparse true
```

Don't use a distro at all? Remove it properly. **This erases everything inside it**:
```powershell
wsl --unregister Ubuntu-24.04
```

### Docker Desktop
```powershell
docker system df                 # see what's using space
docker system prune              # remove stopped containers, unused networks, dangling images
docker system prune -a --volumes # also unused images and volumes (careful: deletes data in unused volumes)
```

### Browsers (Chrome, Edge, Brave)
Don't delete the browser's whole folder; that wipes bookmarks, passwords and logins. Instead:
1. Open `chrome://settings/clearBrowserData` (Edge: `edge://settings/clearBrowserData`, Brave: `brave://settings/clearBrowserData`).
2. Time range **All time**, tick only **Cached images and files** → Delete.
3. `chrome://settings/content/all` → sort by data stored → delete storage for large sites you don't need.
4. Close Chrome and delete `AppData\Local\Google\Chrome\User Data\OptGuideOnDeviceModel`.

If you really want a fresh browser profile, first export your bookmarks (**Ctrl+Shift+O → ⋮ → Export bookmarks**) and check that sync is on.

### Chat apps (Telegram, Spotify, Teams, Discord)
Use the app's own setting where possible:
- Telegram Desktop: **Settings → Advanced → Manage local storage**
- Spotify: **Settings → Storage → Clear cache**

---

## Recommended order

1. Run `Review-DiskSpace.ps1` on `C:\` and work through `Users\<you>` (especially `AppData\Local`).
2. Clear developer caches (`npm`, `pip`, …).
3. Uninstall unused apps from Settings.
4. Run `cleanmgr` → **Clean up system files**.
5. Run `Dism.exe /Online /Cleanup-Image /StartComponentCleanup`.
6. Optional: `powercfg -h off`, compact WSL, prune Docker.
7. **Empty the Recycle Bin.**
8. Turn on Storage Sense so it stays clean.
9. Still tight? Move Documents, Downloads and projects to another drive: right-click the folder → **Properties → Location → Move**.

---

## Troubleshooting

**"running scripts is disabled on this system"**
Run the script with `powershell -ExecutionPolicy Bypass -File .\Review-DiskSpace.ps1`. This bypasses the policy for that one run only.

**"Could not delete … being used by another process"**
The app that owns the folder is running. Close it (check the system tray) and run the script again, or press **K** and move on.

**I deleted something by mistake.**
Open the Recycle Bin, right-click the item → **Restore**. `cleanup-log.txt` lists everything the script deleted.

**Free space didn't change.**
Empty the Recycle Bin. Deleted items still take up space until it's emptied.

**The first scan is slow.**
Measuring `C:\` means adding up hundreds of thousands of files. Expect a few minutes for the whole drive; deeper folders scan faster.

**I want a visual overview first.**
[WizTree](https://diskanalyzer.com/) (free) shows the whole drive as a treemap in seconds. Use it to find the problem, and this script to clean it carefully.

---

## Disclaimer

This script only moves items you explicitly confirm to the Recycle Bin, and it refuses to touch core system locations. Still, you are responsible for what you delete. When you don't recognize a folder, press **O** to look inside, or keep it. Back up important files before any large cleanup.

## Contributing

Found a common space hog that isn't listed, or a folder that's mislabelled? Open an issue or a pull request.

## License

[MIT](LICENSE)
