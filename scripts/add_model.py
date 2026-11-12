#!/usr/bin/env python3
"""
Linux/macOS version of scripts/Add-Model.ps1 (standard library only, Python 3.8+).

Downloads a model from Printables or MakerWorld into a folder of this repo, unzips it,
deletes the zip, records the source in scripts/readme-sources.json and regenerates the READMEs.

Printables: downloaded directly (no account needed). By default only the "model files" pack
is fetched, into "<slug>-model_files" - the same layout as the existing folders.
--all-files also fetches the print files (gcode/3mf) and other files packs.

MakerWorld requires a logged-in account to download, so one of these is used:
  1. --file <path>  a zip/3mf you already downloaded from the model page
  2. a token        your MakerWorld "token" cookie in $MAKERWORLD_TOKEN or in
                    scripts/.makerworld-token (git-ignored); downloads directly
  3. otherwise      the model page opens in your browser; click Download and the script
                    picks the file up from your Downloads folder automatically

Usage:
  python3 scripts/add_model.py URL [URL ...] [--folder DIR] [--name NAME] [--file PATH]
                               [--all-files] [--force] [--no-readme]
Examples:
  python3 scripts/add_model.py https://www.printables.com/model/359285-klamma-locking-cable-clip --folder cable-management
  cd storage/8020 && python3 ../../scripts/add_model.py https://makerworld.com/en/models/2133463-cable-organizer
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import update_readmes as ur  # noqa: E402  (shared helpers: gql, http_json, download, cache I/O)

TOKEN_FILE = os.path.join(ur.REPO, 'scripts', '.makerworld-token')
MODEL_EXTS = re.compile(r'\.(zip|3mf|stl|step|stp|f3d|f3z|obj|scad|amf)$', re.I)
PARTIAL_EXTS = re.compile(r'\.(crdownload|part|partial|tmp|download)$', re.I)


def safe_name(s):
    return re.sub(r'[<>:"/\\|?*\x00-\x1f]', '_', s).strip().rstrip('. ')


def extract_model_zip(zpath, dest):
    """Extract a zip into dest. A single top-level folder inside the zip is flattened, and
    __MACOSX / .DS_Store junk is skipped."""
    with zipfile.ZipFile(zpath) as z:
        entries = [e for e in z.infolist() if not e.is_dir()]
        entries = [e for e in entries if not re.search(r'(^|/)__MACOSX/', e.filename.replace('\\', '/'))
                   and e.filename.replace('\\', '/').rsplit('/', 1)[-1] != '.DS_Store']
        names = [e.filename.replace('\\', '/') for e in entries]
        strip = ''
        if names and all('/' in n for n in names):
            tops = {n.split('/')[0] for n in names}
            if len(tops) == 1:
                strip = tops.pop() + '/'
        count = 0
        for e, n in zip(entries, names):
            n = n[len(strip):]
            parts = [p for p in n.split('/') if p]
            if '..' in parts or n.startswith('/') or re.match(r'^[A-Za-z]:', n):
                print('WARNING: skipping unsafe zip entry ' + n, file=sys.stderr)
                continue
            target = os.path.join(dest, *[safe_name(p) for p in parts])
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(e) as src, open(target, 'wb') as out:
                shutil.copyfileobj(src, out)
            count += 1
        return count


def save_url(url, out, headers=None):
    print('  downloading ' + os.path.basename(out))
    ur.download(url, out, headers)


def downloads_folder():
    try:
        p = subprocess.run(['xdg-user-dir', 'DOWNLOAD'], capture_output=True, text=True, timeout=5).stdout.strip()
        if p and os.path.isdir(p) and p != os.path.expanduser('~'):
            return p
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.expanduser('~/Downloads')


def wait_for_download(folder, since, timeout=900):
    """Wait for a new model file to finish downloading into folder."""
    print('  waiting for the download to appear in %s (Ctrl+C to cancel) ...' % folder)
    deadline = time.time() + timeout
    last, last_size = None, -1
    while time.time() < deadline:
        time.sleep(2)
        try:
            files = [os.path.join(folder, f) for f in os.listdir(folder)]
        except OSError:
            files = []
        new = []
        for f in files:
            try:
                st = os.stat(f)
            except OSError:
                continue
            if os.path.isfile(f) and max(st.st_mtime, st.st_ctime) > since:
                new.append((st.st_mtime, f, st.st_size))
        partial = [f for _, f, _ in new if PARTIAL_EXTS.search(f)]
        cands = sorted([n for n in new if MODEL_EXTS.search(n[1])], reverse=True)
        if cands and not partial:
            _, f, size = cands[0]
            if f == last and size == last_size and size > 0:
                return f
            last, last_size = f, size
    sys.exit('No download showed up in %s within %d minutes. Re-run with --file <path to the zip>.' % (folder, timeout // 60))


def makerworld_token():
    tok = os.environ.get('MAKERWORLD_TOKEN')
    if tok:
        return tok.strip()
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, encoding='utf-8') as f:
            return f.read().strip()
    return None


# ---------------------------------------------------------------- per-site handlers
DOWNLOAD_LINK = ('mutation GetDownloadLink($id: ID!, $printId: ID!, $fileType: DownloadFileTypeEnum!, $source: DownloadSourceEnum!) '
                 '{ getDownloadLink(id: $id, printId: $printId, fileType: $fileType, source: $source) '
                 '{ ok errors { field messages } output { link } } }')


def add_printables(pid, tmp, args, dest_root):
    fields = 'id name slug user { publicUsername } image { filePath } downloadPacks { id fileType } stls { id name }'
    p = (ur.gql('query { print(id: "%s") { %s } }' % (pid, fields)) or {}).get('print')
    if not p:
        sys.exit('Printables model %s was not found (removed or private?).' % pid)
    info = ur.printables_info(p)
    info['manual'] = True
    print('Printables: %s by %s' % (p['name'], info.get('author')))

    target = os.path.join(dest_root, safe_name(args.name) if args.name else '%s-model_files' % p['slug'])
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway." % target)
    os.makedirs(target, exist_ok=True)

    def link(file_id, ftype):
        r = ur.gql(DOWNLOAD_LINK, {'id': str(file_id), 'printId': str(pid), 'fileType': ftype, 'source': 'model_detail'})['getDownloadLink']
        if not r.get('ok'):
            sys.exit('Printables refused the download: %s' % ', '.join(m for e in r.get('errors') or [] for m in e.get('messages') or []))
        return r['output']['link']

    types = ['MODEL_FILES', 'PRINT_FILES', 'OTHER_FILES'] if args.all_files else ['MODEL_FILES']
    packs = [pk for t in types for pk in (p.get('downloadPacks') or []) if pk.get('fileType') == t]
    if packs:
        for pk in packs:
            url = link(pk['id'], 'pack')
            zpath = os.path.join(tmp, urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit('/', 1)[-1]))
            save_url(url, zpath)
            n = extract_model_zip(zpath, target)
            os.remove(zpath)
            print('  extracted %d files' % n)
    elif p.get('stls'):   # no packs: fetch the model files one by one
        for s in p['stls']:
            save_url(link(s['id'], 'stl'), os.path.join(target, safe_name(s['name'])))
    else:
        sys.exit('Printables model %s has no downloadable files.' % pid)
    return info, target


def add_makerworld(mid, tmp, args, dest_root, page_url):
    d = ur.http_json('https://makerworld.com/api/v1/design-service/design/%s' % mid)
    if not d.get('title'):
        sys.exit('MakerWorld model %s was not found.' % mid)
    info = {'source': 'makerworld', 'id': str(mid), 'name': d['title'],
            'author': (d.get('designCreator') or {}).get('name'),
            'url': 'https://makerworld.com/en/models/%s-%s' % (mid, d.get('slug')),
            'imageUrl': ur.makerworld_cover(d.get('coverUrl')), 'manual': True}
    print('MakerWorld: %s by %s' % (d['title'], info['author']))

    tok = makerworld_token()
    if args.file:
        src = os.path.abspath(args.file)
    elif tok:
        try:
            r = ur.http_json('https://makerworld.com/api/v1/design-service/design/%s/model' % mid,
                             headers={'Authorization': 'Bearer ' + tok, 'Cookie': 'token=' + tok})
        except urllib.error.HTTPError as e:
            sys.exit('MakerWorld download request failed (is the token still valid?): %s %s' % (e, e.read()[:300]))
        if not r.get('url'):
            sys.exit("MakerWorld didn't return a download link: %s" % r)
        fname = r.get('name') or urllib.parse.unquote(urllib.parse.urlparse(r['url']).path.rsplit('/', 1)[-1])
        src = os.path.join(tmp, safe_name(fname))
        save_url(r['url'], src)
    else:
        dl = downloads_folder()
        since = time.time()
        print('  MakerWorld needs you to be logged in to download. Opening the model page -')
        print("  click Download > 'STL/CAD files' (or the 3MF) and the script will pick it up.")
        webbrowser.open(page_url)
        src = wait_for_download(dl, since)

    fn = os.path.basename(src)
    is_zip = ur.ext_of(fn).lower() == '.zip'
    base = re.sub(r'\s*\(\d+\)$', '', ur.stem_of(fn))
    folder = safe_name(args.name) if args.name else safe_name(base) if is_zip else safe_name(re.sub(r'\s+', '+', d['title']))
    target = os.path.join(dest_root, folder)
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway (the downloaded file was left at %s)." % (target, src))
    os.makedirs(target, exist_ok=True)
    if is_zip:
        n = extract_model_zip(src, target)
        os.remove(src)
        print('  extracted %d files' % n)
    else:
        shutil.move(src, os.path.join(target, safe_name(re.sub(r'\s*\(\d+\)(?=\.\w+$)', '', fn))))
    return info, target


def main():
    ap = argparse.ArgumentParser(description='Download a Printables / MakerWorld model into this repo and update the READMEs.')
    ap.add_argument('url', nargs='+', help='Printables or MakerWorld model URL(s)')
    ap.add_argument('--folder', default='.', help='repo folder to put the model in (default: current directory)')
    ap.add_argument('--name', help="override the model folder's name (single URL only)")
    ap.add_argument('--file', help='MakerWorld: a zip/3mf you already downloaded (single URL only)')
    ap.add_argument('--all-files', action='store_true', help='Printables: also fetch the print files and other files packs')
    ap.add_argument('--force', action='store_true', help='download into the model folder even if it already exists')
    ap.add_argument('--no-readme', action='store_true', help="don't regenerate the READMEs afterwards")
    args = ap.parse_args()

    dest_root = os.path.abspath(args.folder).rstrip(os.sep)
    if not dest_root.startswith(ur.REPO + os.sep):
        sys.exit("Folder '%s' must be a category folder inside the repo (%s)." % (dest_root, ur.REPO))
    if (args.name or args.file) and len(args.url) > 1:
        sys.exit('--name and --file can only be used with a single URL.')

    added = []
    tmp = tempfile.mkdtemp(prefix='add-model-')
    try:
        for u in args.url:
            m = re.search(r'printables\.com/(?:[a-z]{2}/)?model/(\d+)', u, re.I)
            if m:
                info, target = add_printables(m.group(1), tmp, args, dest_root)
            else:
                m = re.search(r'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)', u, re.I)
                if not m:
                    print('WARNING: not a Printables or MakerWorld model URL, skipped: ' + u, file=sys.stderr)
                    continue
                info, target = add_makerworld(m.group(1), tmp, args, dest_root, u)
            key = ur.rel(target)
            cache = ur.load_cache()
            cache[key] = info
            ur.save_cache(cache)
            added.append(key)
            print('  added ' + key)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if added and not args.no_readme:
        print('Updating READMEs ...')
        ur.main([])


if __name__ == '__main__':
    main()
