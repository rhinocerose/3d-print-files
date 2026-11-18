# Scripts

The Linux/macOS versions (Python 3.8+, standard library only, nothing to install) are the
maintained ones. The Windows versions (PowerShell 5.1+) read and write the same files and do
everything up to Cults3D/Thangs support, but new features are only added to the Python scripts.

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

Several URLs can be given at once, or put them in a text file and pass it with
`-List` / `--list`:

```text
# one URL per line; blank lines and # comments are ignored
https://www.printables.com/model/359285-klamma-locking-cable-clip
https://makerworld.com/en/models/2133463-cable-organizer   storage/8020
```

A folder after the URL puts that model there. Lines without one use `-Folder` / `--folder`
(or the current directory). If one model fails (already exists, removed, bad link), it's listed
at the end and the rest of the list still runs.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Add-Model.ps1 -List new-models.txt -Folder unsorted
```

```bash
python3 scripts/add_model.py --list new-models.txt --folder unsorted
```

Options (Windows / Linux):

| Option | What it does |
|---|---|
| `-List` / `--list` | Text file of URLs (see above) |
| `-Folder` / `--folder` | Repo folder to put the model in (created if missing). Default: current directory |
| `-Name` / `--name` | Use this name for the model's folder instead of the default |
| `-AllFiles` / `--all-files` | Printables: also download the print-files (gcode/3mf) and other-files packs |
| `-File` / `--file` | MakerWorld: use a zip/3mf you already downloaded instead of logging in |
| `-Force` / `--force` | Download into the model folder even if it already exists |
| `-NoReadme` / `--no-readme` | Skip rebuilding the READMEs |
| `-NoPage` / `--no-page` | Don't save `model-page.html` / `.pdf` (attachments are still downloaded) |
| `-NoPdf` / `--no-pdf` | Save the page as HTML only |
| `-NoComments` / `--no-comments` | Leave user comments and ratings out of the saved page |
| `-FillPages` / `--fill-pages` | Add the saved page and `Instructions/` to models already in the repo (see below) |
| `-Match` / `--match` | Find the web page for models in the repo that have no link yet (see below) |
| `-AutoOnly` / `--auto-only` | With `-Match`: only save exact matches, ask nothing |

**Saved page and instructions (both sites).** Every model folder also gets:

- `model-page.html`: an offline copy of the model's page, with title, author, license,
  photos, the full description, print profiles (MakerWorld), the assembly guide and the top 50
  user comments with their photos and replies. "Top" means MakerWorld's own Top order, which
  mixes in ratings shown with their stars, or the most-liked first on Printables. It's a
  single file with all images embedded, so it opens without internet. (The sites build their
  pages with JavaScript and block automated browsers, so the page is rebuilt from the same
  data the site shows instead of being saved from a browser.)
- `model-page.pdf`: the same page as a PDF, printed with Edge, Chrome or Chromium in headless
  mode. Windows always has Edge. On Linux, install `chromium` (or Chrome / Edge) if you don't
  have one. Under WSL, Windows' Edge is used. Without a browser you get the HTML only.
- `Instructions/`: any attachments the designer added, such as PDF manuals, build guides,
  assembly-guide images, BOMs, and Printables "other files".

To add these to models that are already in the repo, use `-FillPages` / `--fill-pages` with
the folders to look in (default: the current directory, so from the repo root it does
everything). It handles every Printables / MakerWorld / Thingiverse / Cults3D model in `readme-sources.json` under
those folders that doesn't have a `model-page.pdf` yet (or `model-page.html` with no PDF
browser), so pages made before the PDF and comments existed get redone. It downloads no model
files and needs no login.
Models stored as a single `.zip`/`.3mf` (no folder) are skipped. `-Force` / `--force` redoes
models that already have a page.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Add-Model.ps1 -FillPages tools\woodworking electrical
```

```bash
python3 scripts/add_model.py --fill-pages tools/woodworking electrical
```

## Match models that have no link

Some models in the repo show "Search MakerWorld" or "Source unknown" because the README script
couldn't find them by folder name. `-Match` / `--match` finds their pages. Like `-FillPages`, it
takes the folders to look in and defaults to the current directory.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Add-Model.ps1 -Match bub
```

```bash
python3 scripts/add_model.py --match bub
```

- **Exact matches are saved automatically**, from what the model's own files say about where
  they came from:
  - a 3MF downloaded from MakerWorld records which MakerWorld model it came from (the script
    searches MakerWorld for the 3MF's title and keeps the result only if its ID is the same);
  - Printables puts a PDF of the model page in every download, named `<model id>-<name>-….pdf`;
  - Thingiverse zips have a `README.txt` that starts "… on Thingiverse: <url>".

  This works for zips as well as folders, and for renamed files or retitled models. If the
  model named there has been removed from the site, it falls back to searching.
- **For the rest you pick.** It shows up to 5 MakerWorld and 5 Printables results, plus 3 each
  from Cults3D and Thingiverse once their keys are saved. The order is:
  1. links found in the model's own text files, marked "(linked in README.md)". These are often
     related models or the designer's other work, so they're never saved automatically;
  2. results with exactly the same title as the 3MF or folder name, marked "(exact title)";
  3. results from the same designer as the 3MF, marked "(same designer)";
  4. the rest.

  Then type:

  | Answer | What it does |
  |---|---|
  | a number | use that result |
  | a URL | use that Printables / MakerWorld / Thingiverse page |
  | other words | search again with those words |
  | Enter | skip it for now |
  | `x` | not online, never ask again (`-Force` / `--force` asks again) |
  | `q` | stop; everything chosen so far is kept |

Each answer is saved straight away as a manual entry in `readme-sources.json`, so later rebuilds
never change it. When it finishes, it rebuilds the READMEs (unless `-NoReadme`) and reminds you to
run `-FillPages` on the same folders to add the saved pages. `-AutoOnly` / `--auto-only`
saves only the exact matches and asks nothing, which is also what happens when there's no
terminal to ask in.

**Printables** works without an account. The folder is named `<slug>-model_files`, like the
existing ones.

**MakerWorld** only allows downloads when you're logged in. The first time a run includes a
MakerWorld link, the script asks in the terminal, before downloading anything, for your
Bambu Lab / MakerWorld email and password, plus the emailed code or 2FA code if your account
asks for one. It logs in through Bambu Lab's account API and saves the resulting token in
`scripts/.makerworld-token` (git-ignored, treat it like a password). Every MakerWorld link,
in this run and later ones, then uses that token. When it expires, the script asks you to log in again.
Your password is never stored.

Each MakerWorld model gets everything it offers, in subfolders of its folder:

```text
Strong+cable+clips/
  STL-CAD/                          the STL/CAD files (when the designer uploaded them)
  3MF/PLA 0.2mm layer.3mf           one 3MF per print profile
  3MF/PETG, 0.2mm layer.3mf
  ...
  Instructions/                     attachments (PDF manuals, assembly guide...)
  model-page.html                   offline copy of the model page
```

**Thingiverse** links work through Thingiverse's official API, which needs an App Token
(create an app at thingiverse.com/apps/create). The first Thingiverse link asks for it and saves
it in `scripts/.thingiverse-token` (git-ignored); `THINGIVERSE_TOKEN` overrides it. Everything
works: the files download into `<Name>_<id>/files/` with a `README.txt`, the same layout as a
zip from the Thingiverse site, and the saved page and PDF include the description, print
instructions, photos and comments. Thingiverse comments have no likes, so the top 50 are the 50
newest, each with all its replies. `--fill-pages` also covers the Thingiverse models already in
the repo.

**Cults3D** links work through Cults3D's official API, which needs your username and an API key
(cults3d.com > your account > API). The first Cults3D link asks for them and saves
`username:key` in `scripts/.cults3d-key` (git-ignored); `CULTS3D_KEY` overrides it. The API gives
the model's details, pictures and comments, so the saved page and PDF work, but **not its
files**, not even for models you've bought. So the model page opens in your browser and the
file you download there is picked up from your Downloads folder, or pass it with `--file`.
The folder is named after the model's Cults3D slug. Cults3D comments have no likes or photos,
and the top 50 are taken in the order the API returns them.

**Thangs** has no public API and blocks scripts, so a Thangs link only records the link, model
name and designer (read from the URL) and picks up the file you download in the browser (or
`--file`). There's no saved page or PDF.

`--match` also searches Thingiverse and Cults3D once their keys are saved, and accepts pasted
Thingiverse, Cults3D and Thangs URLs.

Other ways to do it: set the `MAKERWORLD_TOKEN` environment variable to use a token instead
of the saved one, use `-File` / `--file` for a file you already downloaded (no login), or press
Enter at the email prompt to skip logging in. In that case each model page opens in your
browser, and the file you download there is picked up from your Downloads folder.

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
