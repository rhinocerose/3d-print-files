# Scripts

Each tool comes in a Windows version (PowerShell 5.1+, built into Windows) and a Linux/macOS
version (Python 3.8+, standard library only, nothing to install). They read and write the
same files and produce byte-identical output, so you can switch between machines freely.

| Task | Windows | Linux / macOS |
|---|---|---|
| Add a model from a URL | `scripts\Add-Model.ps1` | `scripts/add_model.py` |
| Rebuild all READMEs | `scripts\Update-Readmes.ps1` | `scripts/update_readmes.py` |

## Add a model

Downloads the model into a folder, unzips it, deletes the zip, records the source
(name, author, link, cover image) in `readme-sources.json` and rebuilds the READMEs.

Windows (from the folder the model should go in):

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\Add-Model.ps1 https://www.printables.com/model/359285-klamma-locking-cable-clip
```

or from anywhere, naming the folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Add-Model.ps1 <url> -Folder cable-management
```

Linux / macOS:

```bash
python3 scripts/add_model.py <url> --folder cable-management
```

Several URLs can be given at once. Options (Windows / Linux):

| Option | What it does |
|---|---|
| `-Folder` / `--folder` | Repo folder to put the model in (created if missing). Default: current directory |
| `-Name` / `--name` | Use this name for the model's folder instead of the default |
| `-AllFiles` / `--all-files` | Printables: also download the print-files (gcode/3mf) and other-files packs |
| `-File` / `--file` | MakerWorld: use a zip/3mf you already downloaded |
| `-Force` / `--force` | Download into the model folder even if it already exists |
| `-NoReadme` / `--no-readme` | Skip rebuilding the READMEs |

**Printables** works without an account. The folder is named `<slug>-model_files`, like the
existing ones.

**MakerWorld** only allows downloads when you're logged in, so the script does one of these:

1. **Default:** opens the model page in your browser. Click *Download* there and the script
   picks the file up from your Downloads folder by itself, then continues.
2. **`-File` / `--file`:** use a file you already downloaded.
3. **Token (fully automatic, optional):** put your MakerWorld login token in
   `scripts/.makerworld-token` (git-ignored) or the `MAKERWORLD_TOKEN` environment variable.
   To find it: in your browser, logged in to makerworld.com, open the developer tools →
   Application/Storage → Cookies → `https://makerworld.com` → copy the value of `token`. It
   expires periodically. Treat it like a password.

The folder is named after the downloaded zip (e.g. `Cable+Organizer`), like the existing ones.

## Rebuild the READMEs

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Update-Readmes.ps1
```

```bash
python3 scripts/update_readmes.py
```

Options: `-Refresh` / `--refresh` looks every non-manual build up online again, `-Offline` /
`--offline` uses only the cache and local files, `-ListOnly` / `--list-only` just lists the builds.

Settings (which folders get their own README) are at the top of both scripts. Change them in both.
To fix a wrong or missing link, edit the build's entry in `readme-sources.json`, add
`"manual": true`, and rerun.
