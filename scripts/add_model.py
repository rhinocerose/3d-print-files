#!/usr/bin/env python3
"""
Linux/macOS version of scripts/Add-Model.ps1 (standard library only, Python 3.8+).

Downloads a model from Printables or MakerWorld into a folder of this repo, unzips it,
deletes the zip, records the source in scripts/readme-sources.json and regenerates the READMEs.

Printables: downloaded directly (no account needed). By default only the "model files" pack
is fetched, into "<slug>-model_files" - the same layout as the existing folders.
--all-files also fetches the print files (gcode/3mf) and other files packs.

MakerWorld requires a logged-in account to download. The first time a MakerWorld link comes
up, the script asks for your Bambu Lab / MakerWorld email and password (and the emailed or
2FA code if your account uses one), saves the token in scripts/.makerworld-token
(git-ignored) and reuses it for every MakerWorld link after that. It then downloads into
"<Model+Name>/":
  STL-CAD/                 the STL/CAD model files, if the designer uploaded them
  3MF/<profile name>.3mf   every print profile
$MAKERWORLD_TOKEN overrides the saved token. Other options:
  --file <path>  use a zip/3mf you already downloaded (no login needed)
  skip login     press Enter at the email prompt; the model page then opens in your
                 browser and the file you download is picked up from your Downloads folder

Usage:
  python3 scripts/add_model.py [URL ...] [--list FILE] [--folder DIR] [--name NAME] [--file PATH]
                               [--all-files] [--force] [--no-readme]

--list FILE reads one URL per line. A line can name its own folder after the URL
("<url>  storage/8020"); otherwise --folder is used. Blank lines and lines starting with #
are ignored. A failed model is reported and the rest of the list still runs.
Examples:
  python3 scripts/add_model.py https://www.printables.com/model/359285-klamma-locking-cable-clip --folder cable-management
  cd storage/8020 && python3 ../../scripts/add_model.py https://makerworld.com/en/models/2133463-cable-organizer
  python3 scripts/add_model.py --list new-models.txt --folder unsorted
  python3 scripts/add_model.py --match bub          (find the page for models with no link)
  python3 scripts/add_model.py --fill-pages bub     (saved page + Instructions/ for existing models)
"""
import argparse
import base64
import datetime
import getpass
import html
import json
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


# ---------------------------------------------------------------- MakerWorld login
# MakerWorld accounts are Bambu Lab accounts. The script logs in once through the Bambu Lab
# account API (the one Bambu Studio uses), saves the token in scripts/.makerworld-token
# (git-ignored) and reuses it for every MakerWorld link - in this run and later ones - until
# MakerWorld rejects it, at which point it asks you to log in again.
_mw = {'token': None, 'skip': False}
BAMBU_API = 'https://api.bambulab.com/v1/user-service/user'


def bambu_post(url, body):
    try:
        return ur.http_json(url, body)
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read().decode('utf-8')).get('error')
        except Exception:
            err = None
        raise RuntimeError(err or str(e))


def bambu_login(account, password):
    """Return an access token, asking for an emailed or 2FA code when the account needs one."""
    r = bambu_post(BAMBU_API + '/login', {'account': account, 'password': password, 'apiError': ''})
    if r.get('accessToken'):
        return r['accessToken']
    if r.get('loginType') == 'verifyCode':
        bambu_post(BAMBU_API + '/sendemail/code', {'email': account, 'type': 'codeLogin'})
        code = ask('  Bambu Lab emailed a verification code to %s. Code: ' % account).strip()
        return bambu_post(BAMBU_API + '/login', {'account': account, 'code': code}).get('accessToken')
    if r.get('loginType') == 'tfa':
        code = ask('  Two-factor code from your authenticator app: ').strip()
        req = urllib.request.Request('https://bambulab.com/api/sign-in/tfa',
                                     data=json.dumps({'tfaKey': r.get('tfaKey'), 'tfaCode': code}).encode('utf-8'),
                                     headers={'User-Agent': ur.UA, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=60) as resp:
            for c in resp.headers.get_all('Set-Cookie') or []:
                m = re.match(r'\s*token=([^;]+)', c)
                if m:
                    return m.group(1)
            try:
                return json.loads(resp.read().decode('utf-8')).get('accessToken')
            except ValueError:
                return None
    raise RuntimeError('unexpected login response: %s' % r)


def ask(prompt):
    try:
        return input(prompt)
    except EOFError:   # no terminal to ask (e.g. input piped in) - treat as "skip"
        print()
        return ''


def makerworld_token(renew=False):
    if renew:
        _mw['token'] = None   # the current one was rejected
        if _mw['skip']:
            return None
    else:
        if _mw['token']:
            return _mw['token']
        if _mw['skip']:
            return None
        tok = (os.environ.get('MAKERWORLD_TOKEN') or '').strip()
        if not tok and os.path.exists(TOKEN_FILE):
            with open(TOKEN_FILE, encoding='utf-8') as f:
                tok = f.read().strip()
        if tok:
            _mw['token'] = tok
            return tok
    print()
    print('MakerWorld login - your Bambu Lab / MakerWorld account. Needed once; the token is saved in')
    print('scripts/.makerworld-token for next time. Press Enter without an email to skip (you then')
    print('download each MakerWorld model yourself in the browser).')
    for _ in range(3):
        acct = ask('  Email: ').strip()
        if not acct:
            _mw['skip'] = True
            return None
        pw = getpass.getpass('  Password: ')
        try:
            tok = bambu_login(acct, pw)
            if not tok:
                raise RuntimeError('the login did not return a token')
            with open(TOKEN_FILE, 'w', encoding='utf-8') as f:
                f.write(tok)
            try:
                os.chmod(TOKEN_FILE, 0o600)
            except OSError:
                pass
            print('  logged in, token saved.\n')
            _mw['token'] = tok
            return tok
        except (RuntimeError, urllib.error.URLError) as e:
            print('WARNING: Login failed: %s' % e, file=sys.stderr)
        finally:
            pw = None
    raise RuntimeError('MakerWorld login failed 3 times.')


def mw_api(path):
    """Call a logged-in MakerWorld API; log in again once if the saved token was rejected."""
    for attempt in range(2):
        tok = makerworld_token(renew=attempt > 0)
        if not tok:
            raise RuntimeError('not logged in to MakerWorld')
        try:
            return ur.http_json('https://makerworld.com' + path, headers={'Authorization': 'Bearer ' + tok, 'Cookie': 'token=' + tok})
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', 'replace')
            if attempt == 0 and (e.code == 401 or (e.code == 403 and re.search(r'log ?in', body, re.I))):
                print('  the saved MakerWorld token was rejected (expired?) - please log in again')
                continue
            raise RuntimeError('MakerWorld: %s %s' % (e.code, body[:300]))


def mw_link(r):
    for c in (r, r.get('data') if isinstance(r, dict) else None):
        if isinstance(c, dict) and c.get('url'):
            return c['url'], c.get('name')
    raise RuntimeError("MakerWorld didn't return a download link: %s" % str(r)[:300])


# ---------------------------------------------------------------- saved model page + instructions
# Both sites build their pages with JavaScript (and block automated browsers), so a "saved page"
# is rebuilt from the same data the site shows: one self-contained HTML file with every image
# embedded, so it works offline. Attachments (PDF manuals, assembly guides, BOMs...) go in
# <model folder>/Instructions/.
PAGE_NAME = 'model-page.html'
INSTRUCTIONS_DIR = 'Instructions'
MIME = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif',
        '.webp': 'image/webp', '.svg': 'image/svg+xml', '.bmp': 'image/bmp'}
PAGE_CSS = """
:root { --bg:#ffffff; --fg:#1f2328; --muted:#59636e; --line:#d1d9e0; --card:#f6f8fa; --link:#0969da; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#9198a1; --line:#3d444d; --card:#151b23; --link:#4493f8; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
main { max-width:960px; margin:0 auto; padding:24px 16px 64px; }
a { color:var(--link); }
h1 { font-size:1.9rem; line-height:1.25; margin:0 0 8px; }
h2 { font-size:1.3rem; margin:40px 0 12px; padding-bottom:6px; border-bottom:1px solid var(--line); }
.meta, .saved, .muted { color:var(--muted); }
.saved { font-size:.85rem; }
.gallery { display:grid; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:10px; margin-top:20px; }
.gallery img { width:100%; aspect-ratio:4/3; object-fit:cover; border-radius:8px; background:var(--card); cursor:zoom-in; }
.gallery img.big { grid-column:1/-1; aspect-ratio:auto; object-fit:contain; cursor:zoom-out; }
article img, .guide img { max-width:100%; height:auto; border-radius:6px; }
.profiles { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:12px; }
.profile { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:12px; }
.profile img { width:100%; aspect-ratio:4/3; object-fit:cover; border-radius:6px; }
.profile b { display:block; margin-top:6px; }
.tags span { display:inline-block; background:var(--card); border:1px solid var(--line); border-radius:999px; padding:1px 10px; margin:2px; font-size:.85rem; }
.comment { border-top:1px solid var(--line); padding:12px 0 4px; }
.comment .who { font-weight:600; }
.comment .when, .comment .likes { color:var(--muted); font-size:.85rem; margin-left:8px; }
.comment .stars { color:#bf8700; margin-left:8px; }
.comment p { margin:6px 0; white-space:pre-wrap; overflow-wrap:anywhere; }
.comment .pics img { height:140px; max-width:100%; object-fit:cover; border-radius:6px; margin:4px 6px 0 0; }
.replies { margin-left:20px; padding-left:14px; border-left:3px solid var(--line); }
.replies .comment:first-child { border-top:0; }
@media print { :root { --bg:#fff; --fg:#000; --card:#f6f8fa; --line:#d1d9e0; --muted:#59636e; --link:#0969da; }
  .gallery img, .profile, .guide img, .comment .pics { break-inside:avoid; } h2 { break-after:avoid; } }
"""
PAGE_JS = "document.querySelectorAll('.gallery img').forEach(function(i){i.onclick=function(){i.classList.toggle('big')}})"


def _fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': ur.UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read(), r.headers.get_content_type()


def data_uri(data, name_or_url, ctype=None):
    if not ctype or not ctype.startswith('image/'):
        ctype = MIME.get(ur.ext_of(urllib.parse.urlparse(name_or_url).path).lower(), 'image/jpeg')
    return 'data:%s;base64,%s' % (ctype, base64.b64encode(data).decode('ascii'))


class Embedder:
    """Downloads images once and returns them as data: URIs (None if a download fails)."""
    def __init__(self, resize=None):
        self.resize, self.cache = resize, {}

    def __call__(self, url):
        if not url:
            return None
        if url not in self.cache:
            fetch = self.resize(url) if self.resize else url
            try:
                data, ctype = _fetch(fetch)
                self.cache[url] = data_uri(data, url, ctype)
            except Exception as e:
                print('WARNING:   image %s: %s' % (url, e), file=sys.stderr)
                self.cache[url] = None
        return self.cache[url]


def clean_html(h, embed):
    """Site description HTML -> offline HTML: no scripts, iframes become links, images embedded."""
    h = re.sub(r'(?is)<script\b.*?</script>', '', h or '')
    h = re.sub(r'(?is)<iframe\b[^>]*?\bsrc="([^"]*)"[^>]*>.*?</iframe>',
               lambda m: '<p><a href="%s">%s</a></p>' % (m.group(1), m.group(1)), h)
    h = re.sub(r'(?i)\s(?:on\w+|srcset|loading)="[^"]*"', '', h)
    def img(m):
        return m.group(1) + (embed(html.unescape(m.group(2))) or m.group(2)) + m.group(3)
    return re.sub(r'(?i)(<img\b[^>]*?\bsrc=")([^"]+)(")', img, h)


def download_attachments(items, target):
    """items: [(file name, url)] -> saved in <target>/Instructions/. Returns [(name, rel path)]."""
    saved, used = [], set()
    for name, url in items:
        fn = safe_name(name or urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit('/', 1)[-1])) or 'attachment'
        base, n = fn, 2
        while fn.lower() in used:
            fn = '%s (%d)%s' % (ur.stem_of(base), n, ur.ext_of(base)); n += 1
        try:
            sub = os.path.join(target, INSTRUCTIONS_DIR)
            os.makedirs(sub, exist_ok=True)
            save_url(url() if callable(url) else url, os.path.join(sub, fn))
            used.add(fn.lower())
            saved.append((fn, INSTRUCTIONS_DIR + '/' + fn))
        except Exception as e:
            print('WARNING:   attachment %s: %s' % (fn, e), file=sys.stderr)
    return saved


def write_page(target, p):
    """p: title, author, author_url, site, url, license, published, tags, summary, description,
    images, profiles [{title, details, cover}], guide [(name, data uri)], attachments [(name, rel)]."""
    e = html.escape
    out = ['<!doctype html>', '<html lang="en">', '<head>', '<meta charset="utf-8">',
           '<meta name="viewport" content="width=device-width, initial-scale=1">',
           '<title>%s</title>' % e(p['title']), '<style>%s</style>' % PAGE_CSS, '</head>', '<body>', '<main>',
           '<h1>%s</h1>' % e(p['title'])]
    meta = []
    if p.get('author'):
        meta.append('by ' + ('<a href="%s">%s</a>' % (e(p['author_url']), e(p['author'])) if p.get('author_url') else e(p['author'])))
    meta.append('<a href="%s">%s</a>' % (e(p['url']), e(p['site'])))
    if p.get('license'): meta.append(e(p['license']))
    if p.get('published'): meta.append('published ' + e(p['published']))
    out.append('<p class="meta">%s</p>' % ' &middot; '.join(meta))
    out.append('<p class="saved">Saved %s from <a href="%s">%s</a></p>' % (datetime.date.today().isoformat(), e(p['url']), e(p['url'])))
    imgs = [u for u in p.get('images') or [] if u]
    if imgs:
        out.append('<section class="gallery">%s</section>' % ''.join('<img src="%s" alt="">' % u for u in imgs))
    if p.get('summary'):
        out.append('<p>%s</p>' % e(p['summary']))
    if p.get('tags'):
        out.append('<p class="tags">%s</p>' % ''.join('<span>%s</span>' % e(t) for t in p['tags']))
    if p.get('attachments'):
        out.append('<h2>Instructions &amp; attachments</h2><ul>')
        out += ['<li><a href="%s">%s</a></li>' % (e(urllib.parse.quote(rel)), e(name)) for name, rel in p['attachments']]
        out.append('</ul>')
    if p.get('description'):
        out += ['<h2>Description</h2>', '<article>', p['description'], '</article>']
    if p.get('guide'):
        out.append('<h2>Assembly guide</h2><div class="guide">')
        out += ['<p><img src="%s" alt="%s"></p>' % (u, e(n)) for n, u in p['guide']]
        out.append('</div>')
    if p.get('profiles'):
        out.append('<h2>Print profiles (%d)</h2><div class="profiles">' % len(p['profiles']))
        for pr in p['profiles']:
            out.append('<div class="profile">%s<b>%s</b><span class="muted">%s</span></div>' % (
                '<img src="%s" alt="">' % pr['cover'] if pr.get('cover') else '', e(pr['title']), e(pr.get('details') or '')))
        out.append('</div>')
    if p.get('comments'):
        total = sum(1 + len(c.get('replies') or []) for c in p['comments'])
        out.append('<h2>Comments (%d)</h2><section class="comments">' % total)
        if len(p['comments']) >= MAX_COMMENTS:
            out.append('<p class="muted">The top %d comments, with their replies. The rest are on <a href="%s">%s</a>.</p>' % (
                MAX_COMMENTS, e(p['url']), e(p['site'])))
        out += [comment_html(c) for c in p['comments']]
        out.append('</section>')
    out += ['</main>', '<script>%s</script>' % PAGE_JS, '</body>', '</html>', '']
    path = os.path.join(target, PAGE_NAME)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out))
    print('  saved page: %s (%.1f MB%s)' % (PAGE_NAME, os.path.getsize(path) / 1e6,
                                          ', %d comments' % total if p.get('comments') else ''))
    if PDF['on']:
        html_to_pdf(path, os.path.join(target, PDF_NAME))


def comment_html(c):
    """c: author, date, text, likes, stars, images [data uri], replies [c]."""
    e = html.escape
    head = '<span class="who">%s</span>' % e(c.get('author') or '?')
    if c.get('stars'):
        head += '<span class="stars">%s</span>' % ('&#9733;' * int(c['stars']) + '&#9734;' * (5 - int(c['stars'])))
    if c.get('date'):
        head += '<span class="when">%s</span>' % e(c['date'])
    if c.get('likes'):
        head += '<span class="likes">&#9829; %d</span>' % c['likes']
    body = '<p>%s</p>' % e(c['text']) if c.get('text') else ''
    pics = [u for u in c.get('images') or [] if u]
    if pics:
        body += '<div class="pics">%s</div>' % ''.join('<img src="%s" alt="">' % u for u in pics)
    reps = ''
    if c.get('replies'):
        reps = '<div class="replies">%s</div>' % ''.join(comment_html(r) for r in c['replies'])
    return '<div class="comment">%s%s%s</div>' % (head, body, reps)


# ---------------------------------------------------------------- PDF copy of the saved page
# Printed by a Chromium-based browser in headless mode: Edge (always on Windows), Chrome or
# Chromium. Under WSL, Windows' own Edge is used when Linux has none.
PDF_NAME = 'model-page.pdf'
PDF = {'on': True, 'cmd': None, 'checked': False}
WIN_BROWSERS = ['/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
                '/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe',
                '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe']


def pdf_browser():
    """(exe, is_windows_exe) or None."""
    if not PDF['checked']:
        PDF['checked'] = True
        for name in ('chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable',
                     'microsoft-edge', 'microsoft-edge-stable', 'msedge', 'chrome'):
            exe = shutil.which(name)
            if exe:
                PDF['cmd'] = (exe, False)
                break
        else:
            exe = next((b for b in WIN_BROWSERS if os.path.isfile(b)), None)
            if exe and shutil.which('wslpath'):
                PDF['cmd'] = (exe, True)
        if not PDF['cmd']:
            print('WARNING: no Chrome / Chromium / Edge found, so no PDF is made. Install one '
                  '(e.g. "sudo apt install chromium-browser") to get %s.' % PDF_NAME, file=sys.stderr)
    return PDF['cmd']


# PDF can't hold WebP, so the browser would store every photo losslessly (several times bigger).
# The copy that gets printed first redraws each image as a JPEG, which goes into the PDF as is.
# Synchronous on purpose: Chromium loads data: images immediately, so this finishes before printing starts.
PRINT_JS = ("<script>(function(){var c=document.createElement('canvas'),x=c.getContext('2d');"
            "Array.prototype.forEach.call(document.images,function(i){try{var w=i.naturalWidth,h=i.naturalHeight;"
            "if(!w||/^data:image\\/jpeg/.test(i.src))return;c.width=w;c.height=h;x.fillStyle='#fff';"
            "x.fillRect(0,0,w,h);x.drawImage(i,0,0);i.src=c.toDataURL('image/jpeg',0.85);}catch(e){}});})();</script>")


def html_to_pdf(page, out):
    b = pdf_browser()
    if not b:
        return
    exe, win = b
    src = os.path.join(os.path.dirname(page), '.print-' + os.path.basename(page))
    with open(page, encoding='utf-8') as f:
        text = f.read()
    with open(src, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text.replace('</body>', PRINT_JS + '</body>', 1))
    try:
        _print_pdf(exe, win, src, out)
    finally:
        os.remove(src)


def _print_pdf(exe, win, src, out):
    if win:   # a Windows browser needs Windows paths
        src_w = subprocess.check_output(['wslpath', '-w', src], text=True).strip()
        out_arg = subprocess.check_output(['wslpath', '-w', os.path.dirname(out)], text=True).strip() + '\\' + os.path.basename(out)
        url = 'file:///' + urllib.parse.quote(src_w.replace('\\', '/'), safe='/:')
    else:
        out_arg, url = out, 'file://' + urllib.parse.quote(src)
    if os.path.exists(out):
        os.remove(out)
    try:
        subprocess.run([exe, '--headless', '--disable-gpu', '--no-pdf-header-footer', '--no-first-run',
                        '--virtual-time-budget=120000', '--print-to-pdf=' + out_arg, url],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
    except (OSError, subprocess.SubprocessError) as e:
        print('WARNING:   PDF: %s' % e, file=sys.stderr)
    if os.path.exists(out):
        print('  saved PDF: %s (%.1f MB)' % (PDF_NAME, os.path.getsize(out) / 1e6))
    else:
        print('WARNING:   PDF: the browser did not write %s' % PDF_NAME, file=sys.stderr)


# ---------------------------------------------------------------- user comments
# Only the top comments are kept (top-level ones; each keeps all its replies): MakerWorld's own
# "Top" order (comments and ratings), Printables' most-liked first.
MAX_COMMENTS = 50
COMMENTS = {'on': True}


def printables_comments(pid, embed):
    fields = 'id text created likesCount author { publicUsername } images { filePath }'
    q = ('query { comments(targetObjectId: "%s", targetType: print, limit: %d, offset: %%d, '
         'ordering: { orderBy: likes_count, sortOrder: descending }) '
         '{ %s replies { %s replies { %s } } } }' % (pid, MAX_COMMENTS, fields, fields, fields))

    def conv(c):
        return {'author': (c.get('author') or {}).get('publicUsername'), 'date': (c.get('created') or '')[:10],
                'text': (c.get('text') or '').strip(), 'likes': c.get('likesCount'),
                'images': [embed(printables_thumb(i.get('filePath'), '320x240')) for i in c.get('images') or []],
                # flatten deeper reply levels into one list under the comment
                'replies': [conv(r) for r in c.get('replies') or []]}

    out, seen, offset = [], set(), 0
    while len(out) < MAX_COMMENTS:
        batch = (ur.gql(q % offset) or {}).get('comments') or []
        new = [c for c in batch if c['id'] not in seen][:MAX_COMMENTS - len(out)]
        if not new:
            break
        for c in new:
            seen.add(c['id'])
            item = conv(c)
            item['replies'] = [r2 for r in item['replies'] for r2 in [dict(r, replies=[])] + r['replies']]
            out.append(item)
        offset += len(batch)
    return out


def makerworld_comments(mid, embed):
    base = 'https://makerworld.com/api/v1/comment-service/'

    def conv(c, name_key='user'):
        u = c.get(name_key) or {}
        at = (c.get('atUser') or {}).get('name')
        text = (c.get('content') or '').strip()
        return {'author': u.get('name'), 'date': (c.get('createTime') or '')[:10],
                'text': ('@%s ' % at if at else '') + text, 'likes': c.get('likeCount'),
                'images': [embed(i if isinstance(i, str) else i.get('url')) for i in c.get('images') or []]}

    out, offset = [], 0
    while len(out) < MAX_COMMENTS:
        r = ur.http_json(base + 'commentandrating?designId=%s&limit=20&offset=%d&msgId=0&msgType=0' % (mid, offset))
        hits = r.get('hits') or []
        if not hits:
            break
        for h in hits[:MAX_COMMENTS - len(out)]:
            if h.get('comment'):
                c = h['comment']
                item = conv(c)
                replies = c.get('commentReply') or []
                if (c.get('replyCount') or 0) > len(replies):   # only the first few replies come with the comment
                    replies, after = [], 0
                    while True:
                        rr = ur.http_json(base + 'comment/%s/reply?limit=20&after=%s&msgCommentReplyId=0' % (c['id'], after)).get('replies') or []
                        replies += rr
                        if len(rr) < 20:
                            break
                        after = rr[-1]['id']
                item['replies'] = [conv(x) for x in replies]
                out.append(item)
            elif h.get('ratingItem'):
                ri = h['ratingItem']
                item = conv(ri, 'creator')
                item['stars'] = ri.get('score')
                out.append(item)
        offset += len(hits)
        if offset >= (r.get('total') or 0):
            break
    return out


def mw_resize(width):
    return lambda u: u if '?' in u or 'bblmw.com' not in u else u + '?x-oss-process=image/resize,w_%d/format,webp' % width


def makerworld_extras(d, target, page=True):
    """Instructions/ (guide, BOM and other attachments) + the saved page for a MakerWorld design."""
    x = d.get('designExtension') or {}
    files = [(f.get('name'), f.get('url')) for k in ('design_guide', 'design_bom', 'design_other')
             for f in (x.get(k) or []) if f.get('url')]
    attachments = download_attachments(files, target)
    if not page:
        return
    try:
        embed = Embedder(mw_resize(1200))
        small = Embedder(mw_resize(480))
        guide = []
        for name, rel in attachments:
            if ur.ext_of(name).lower() in MIME:   # guide images are shown on the page too
                with open(os.path.join(target, *rel.split('/')), 'rb') as f:
                    guide.append((name, data_uri(f.read(), name)))
        profiles = []
        for i in d.get('instances') or []:
            bits = []
            if i.get('prediction'):
                bits.append('%dh %02dm' % (i['prediction'] // 3600, i['prediction'] % 3600 // 60))
            if i.get('weight'):
                bits.append('%g g' % i['weight'])
            if i.get('materialCnt'):
                bits.append('%d colour%s' % (i['materialCnt'], '' if i['materialCnt'] == 1 else 's'))
            if i.get('needAms'):
                bits.append('AMS')
            profiles.append({'title': i.get('title') or 'Profile %s' % i.get('id'), 'details': ' · '.join(bits),
                             'cover': small(i.get('cover'))})
        creator = d.get('designCreator') or {}
        # the cover is usually also the first gallery photo (under another URL), so only use it as a fallback
        pics = [p.get('url') for p in x.get('design_pictures') or []] or [d.get('coverUrl')]
        comments = []
        if COMMENTS['on']:
            try:
                comments = makerworld_comments(d['id'], Embedder(mw_resize(320)))
            except Exception as e:
                print('WARNING:   comments: %s' % e, file=sys.stderr)
        write_page(target, {
            'title': d.get('title'), 'author': creator.get('name'),
            'author_url': 'https://makerworld.com/en/@%s' % creator['handle'] if creator.get('handle') else None,
            'site': 'MakerWorld', 'url': 'https://makerworld.com/en/models/%s-%s' % (d['id'], d.get('slug')),
            'license': d.get('license'), 'published': (d.get('createTime') or '')[:10], 'tags': d.get('tags') or [],
            'images': [embed(u) for u in dict.fromkeys(u for u in pics if u)],
            'description': clean_html(d.get('summary'), embed), 'guide': guide, 'profiles': profiles,
            'attachments': attachments, 'comments': comments})
    except Exception as e:
        print('WARNING:   saved page: %s' % e, file=sys.stderr)


def printables_thumb(fp, size='1280x960'):
    m = re.match(r'^(.*)/([^/]+)\.(\w+)$', fp or '')
    return 'https://media.printables.com/%s/thumbs/inside/%s/%s/%s.webp' % (m.group(1), size, m.group(3), m.group(2)) if m else None


def printables_extras(p, target, link, page=True):
    """Instructions/ (the model's "other files": manuals, guides...) + the saved page for a Printables model."""
    files = [(f.get('name'), (lambda fid=f['id']: link(fid, 'other'))) for f in p.get('otherFiles') or []]
    attachments = download_attachments(files, target)
    if not page:
        return
    try:
        embed = Embedder()
        user = p.get('user') or {}
        comments = []
        if COMMENTS['on']:
            try:
                comments = printables_comments(p['id'], Embedder())
            except Exception as e:
                print('WARNING:   comments: %s' % e, file=sys.stderr)
        write_page(target, {
            'title': p.get('name'), 'author': user.get('publicUsername'),
            'author_url': 'https://www.printables.com/@%s' % user['handle'] if user.get('handle') else None,
            'site': 'Printables', 'url': 'https://www.printables.com/model/%s-%s' % (p['id'], p.get('slug')),
            'license': (p.get('license') or {}).get('name'), 'published': (p.get('datePublished') or '')[:10],
            'images': [embed(printables_thumb(i.get('filePath'))) for i in p.get('images') or []],
            'summary': p.get('summary'), 'description': clean_html(p.get('description'), embed),
            'attachments': attachments, 'comments': comments})
    except Exception as e:
        print('WARNING:   saved page: %s' % e, file=sys.stderr)


# ---------------------------------------------------------------- Cults3D (official API) and Thangs
# Cults3D's API needs your username and an API key (cults3d.com > your account > API). It gives
# the model's details, pictures and comments but not its files, so those you download in the
# browser (or pass with --file). Thangs has no public API: only the link is recorded and the
# file is picked up from your browser's downloads.
CULTS_KEY_FILE = os.path.join(ur.REPO, 'scripts', '.cults3d-key')
_cults = {'auth': None, 'asked': False}
CULTS_FIELDS = ('slug name(locale: EN) url(locale: EN) description(locale: EN) details(locale: EN) tags(locale: EN) '
                'publishedAt license { name } price(currency: USD) { cents } creator { nick url(locale: EN) } '
                'illustrationImageUrl illustrations { imageUrl(version: LARGE) } blueprints { fileName } '
                'comments { text publishedAt creator { nick } answers { text publishedAt creator { nick } } }')
CULTS_SEARCH_FIELDS = 'slug name(locale: EN) url(locale: EN) creator { nick } illustrationImageUrl'
CULTS_URL = r'cults3d\.com/(?:[a-z]{2}/)?3d-model/(?:[^/?#]+/)?([^/?#]+)'


def cults_auth(prompt=True):
    """'Basic ...' header value from CULTS3D_KEY / scripts/.cults3d-key ("username:apikey"), or None."""
    if _cults['auth'] or _cults['asked']:
        return _cults['auth']
    key = (os.environ.get('CULTS3D_KEY') or '').strip()
    if not key and os.path.exists(CULTS_KEY_FILE):
        with open(CULTS_KEY_FILE, encoding='utf-8-sig') as f:
            key = (f.read().strip().splitlines() or [''])[0].strip()
    if not key and prompt and sys.stdin.isatty():   # ask once per run
        _cults['asked'] = True
        print()
        print('Cults3D API key - create one at cults3d.com (your account > API). Saved in')
        print('scripts/.cults3d-key for next time. Press Enter to skip (the model is then recorded without details).')
        user = ask('  Cults3D username: ').strip()
        if user:
            key = '%s:%s' % (user, getpass.getpass('  API key: ').strip())
            with open(CULTS_KEY_FILE, 'w', encoding='utf-8') as f:
                f.write(key + '\n')
            try:
                os.chmod(CULTS_KEY_FILE, 0o600)
            except OSError:
                pass
    if key:
        _cults['auth'] = 'Basic ' + base64.b64encode(key.encode('utf-8')).decode('ascii')
    return _cults['auth']


def cults_gql(query):
    auth = cults_auth()
    if not auth:
        raise RuntimeError('no Cults3D API key (scripts/.cults3d-key)')
    req = urllib.request.Request('https://cults3d.com/graphql', data=json.dumps({'query': query}).encode('utf-8'),
                                 headers={'User-Agent': ur.UA, 'Content-Type': 'application/json', 'Authorization': auth})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.loads(r.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        raise RuntimeError('Cults3D API: %s%s' % (e.code, ' (check the username:key in scripts/.cults3d-key)' if e.code == 401 else ''))
    if d.get('errors'):
        raise RuntimeError('Cults3D API: %s' % d['errors'][0].get('message'))
    return d.get('data') or {}


def cults_creation(slug):
    c = cults_gql('{ creation(slug: %s) { %s } }' % (json.dumps(slug), CULTS_FIELDS)).get('creation')
    if not c:
        raise RuntimeError('Cults3D model %s was not found' % slug)
    return c


def cults_info(c):
    # README cover: the first still picture (the main one is sometimes an animated GIF)
    stills = [i.get('imageUrl') for i in c.get('illustrations') or [] if i.get('imageUrl') and not re.search(r'\.gif$', i['imageUrl'], re.I)]
    return {'source': 'cults3d', 'id': c['slug'], 'name': c.get('name'), 'author': (c.get('creator') or {}).get('nick'),
            'url': c.get('url') or 'https://cults3d.com/:%s' % c['slug'],
            'imageUrl': stills[0] if stills else c.get('illustrationImageUrl'), 'manual': True}


def cults_hits(query, limit=5):
    if not cults_auth(prompt=False):
        return []
    d = cults_gql('{ creationsSearchBatch(query: %s, limit: %d) { results { %s } } }' % (json.dumps(query), limit, CULTS_SEARCH_FIELDS))
    return (d.get('creationsSearchBatch') or {}).get('results') or []


def cults_extras(c, target, page=True):
    """Saved page for a Cults3D model (the API has no attachments or file links)."""
    if not page:
        return
    try:
        embed = Embedder()
        text = ''.join('<p style="white-space:pre-wrap">%s</p>' % html.escape(t.strip())
                       for t in (c.get('description'), c.get('details')) if t and t.strip())
        files = [b.get('fileName') for b in c.get('blueprints') or [] if b.get('fileName')]
        if files:
            text += '<h3>Files on Cults3D</h3><ul>%s</ul>' % ''.join('<li>%s</li>' % html.escape(f) for f in files)
        cents = ((c.get('price') or {}).get('cents')) or 0
        comments = []
        if COMMENTS['on']:
            def conv(x):
                return {'author': (x.get('creator') or {}).get('nick'), 'date': (x.get('publishedAt') or '')[:10],
                        'text': (x.get('text') or '').strip()}
            for x in (c.get('comments') or [])[:MAX_COMMENTS]:
                item = conv(x)
                item['replies'] = [conv(a) for a in x.get('answers') or []]
                comments.append(item)
        creator = c.get('creator') or {}
        write_page(target, {
            'title': c.get('name'), 'author': creator.get('nick'), 'author_url': creator.get('url'),
            'site': 'Cults3D', 'url': c.get('url'), 'license': (c.get('license') or {}).get('name'),
            'published': (c.get('publishedAt') or '')[:10], 'tags': c.get('tags') or [],
            'summary': 'Paid model ($%.2f)' % (cents / 100.0) if cents else None,
            'images': [embed(i.get('imageUrl')) for i in c.get('illustrations') or []] or [embed(c.get('illustrationImageUrl'))],
            'description': text, 'comments': comments})
    except Exception as e:
        print('WARNING:   saved page: %s' % e, file=sys.stderr)


def browser_download(args, page_url, site):
    """The file from --file, or the one you download in the browser (picked up from Downloads)."""
    if args.file:
        return os.path.abspath(args.file)
    since = time.time()
    print('  %s files can only be downloaded in your browser. Opening the model page -' % site)
    print('  download the files (zip or single file) and the script will pick them up.')
    webbrowser.open(page_url)
    return wait_for_download(downloads_folder(), since)


def unpack_download(src, target):
    os.makedirs(target, exist_ok=True)
    if ur.ext_of(src).lower() == '.zip':
        n = extract_model_zip(src, target)
        os.remove(src)
        print('  extracted %d files' % n)
    else:
        shutil.move(src, os.path.join(target, safe_name(re.sub(r'\s*\(\d+\)(?=\.\w+$)', '', os.path.basename(src)))))


def add_cults(slug, args, dest_root, page_url):
    c = None
    try:
        c = cults_creation(slug)
    except RuntimeError as e:
        print('WARNING:   %s - recording the link without details.' % e, file=sys.stderr)
    info = cults_info(c) if c else {'source': 'cults3d', 'id': slug, 'name': ur.pretty(slug),
                                     'url': page_url.split('?')[0], 'manual': True}
    print('Cults3D: %s by %s' % (info['name'], info.get('author') or '?'))
    target = os.path.join(dest_root, safe_name(args.name) if args.name else safe_name(slug))
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway." % target)
    unpack_download(browser_download(args, info['url'], 'Cults3D'), target)
    if c:
        cults_extras(c, target, page=not args.no_page)
    return info, target


def thangs_parse(u):
    """(id, name, designer) from a Thangs model URL."""
    m = re.search(r'thangs\.com/designer/([^/]+)/3d-model/([^/?#]+)', u, re.I)
    if m:
        slug = urllib.parse.unquote(m.group(2))
        mid = re.search(r'-(\d+)$', slug)
        name = re.sub(r'-\d+$', '', slug)
        return (mid.group(1) if mid else slug), ur.pretty(name.replace('-', ' ')), urllib.parse.unquote(m.group(1))
    m = re.search(r'thangs\.com/(?:m|model)/(\d+)', u, re.I)
    if m:
        return m.group(1), 'Thangs model %s' % m.group(1), None
    return None


def add_thangs(u, args, dest_root):
    mid, name, designer = thangs_parse(u)
    info = {'source': 'thangs', 'id': mid, 'name': name, 'author': designer, 'url': u.split('?')[0], 'manual': True}
    print('Thangs: %s%s (Thangs has no API, so no saved page)' % (name, ' by %s' % designer if designer else ''))
    src = browser_download(args, info['url'], 'Thangs')
    folder = safe_name(args.name) if args.name else safe_name(
        re.sub(r'\s*\(\d+\)$', '', ur.stem_of(os.path.basename(src))) if ur.ext_of(src).lower() == '.zip' else name)
    target = os.path.join(dest_root, folder)
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway (the downloaded file was left at %s)." % (target, src))
    unpack_download(src, target)
    return info, target


# ---------------------------------------------------------------- Thingiverse (official API)
# Needs an App Token (thingiverse.com/apps/create), saved in scripts/.thingiverse-token
# (THINGIVERSE_TOKEN overrides it). New downloads get the same layout as a Thingiverse zip:
# <Name>_<id>/files/... plus a README.txt whose first line the README script reads.
TV_TOKEN_FILE = os.path.join(ur.REPO, 'scripts', '.thingiverse-token')
TV_API = 'https://api.thingiverse.com'
TV_URL = r'thingiverse\.com/thing:(\d+)'
_tv = {'token': None, 'asked': False}


def tv_token(prompt=True):
    if _tv['token'] or _tv['asked']:
        return _tv['token']
    tok = (os.environ.get('THINGIVERSE_TOKEN') or '').strip()
    if not tok and os.path.exists(TV_TOKEN_FILE):
        with open(TV_TOKEN_FILE, encoding='utf-8-sig') as f:
            tok = (f.read().strip().splitlines() or [''])[0].strip()
    if not tok and prompt and sys.stdin.isatty():   # ask once per run
        _tv['asked'] = True
        print()
        print('Thingiverse App Token - create an app at thingiverse.com/apps/create and copy its App Token.')
        print('Saved in scripts/.thingiverse-token for next time. Press Enter to skip.')
        tok = getpass.getpass('  App Token: ').strip()
        if tok:
            with open(TV_TOKEN_FILE, 'w', encoding='utf-8') as f:
                f.write(tok + '\n')
            try:
                os.chmod(TV_TOKEN_FILE, 0o600)
            except OSError:
                pass
    _tv['token'] = tok or None
    return _tv['token']


def tv_headers():
    tok = tv_token()
    if not tok:
        raise RuntimeError('no Thingiverse App Token (scripts/.thingiverse-token)')
    return {'Authorization': 'Bearer ' + tok}


def tv_get(path):
    try:
        return ur.http_json(TV_API + path, headers=tv_headers())
    except urllib.error.HTTPError as e:
        raise RuntimeError('Thingiverse API: %s%s' % (e.code, ' (check scripts/.thingiverse-token)' if e.code == 401 else
                                                      ' (thing not found or private)' if e.code == 404 else ''))


def tv_image(img, size='large'):
    """URL of one of a Thingiverse image's 'display' sizes (large is 1024px)."""
    sizes = img.get('sizes') or []
    pick = next((s for s in sizes if s.get('type') == 'display' and s.get('size') == size), None) or \
        next((s for s in sizes if s.get('type') == 'display'), None)
    return (pick or {}).get('url') or img.get('url')


def tv_info(t):
    return {'source': 'thingiverse', 'id': str(t['id']), 'name': t.get('name'), 'author': (t.get('creator') or {}).get('name'),
            'url': t.get('public_url') or 'https://www.thingiverse.com/thing:%s' % t['id'],
            'imageUrl': t.get('preview_image') or t.get('thumbnail'), 'manual': True}


def tv_hits(query, limit=3):
    if not tv_token(prompt=False):
        return []
    words = query.split()   # every word has to match, so retry with the first few when a long title finds nothing
    for q in dict.fromkeys([' '.join(words), ' '.join(words[:3])]):
        if not q:
            continue
        r = tv_get('/search/%s?type=things&per_page=%d' % (urllib.parse.quote(q, safe=''), limit))
        hits = (r.get('hits') if isinstance(r, dict) else r) or []
        if hits:
            return hits[:limit]
    return []


def tv_comments(tid, embed):
    """The newest MAX_COMMENTS top-level comments (Thingiverse has no likes on comments), with all their replies."""
    allc = tv_get('/things/%s/comments' % tid)
    if not isinstance(allc, list):
        return []
    by_parent = {}
    for c in allc:
        if not c.get('is_deleted'):
            by_parent.setdefault(c.get('parent_id') or 0, []).append(c)

    def conv(c):
        pics = [a.get('url') or a.get('thumbnail') for a in c.get('attachments') or [] if isinstance(a, dict)]
        return {'author': (c.get('user') or {}).get('name'), 'date': (c.get('added') or '')[:10],
                'text': (c.get('body') or '').strip(), 'images': [embed(u) for u in pics if u]}

    def descendants(cid):   # replies of replies, flattened in date order
        out = []
        for r in by_parent.get(cid, []):
            out.append(r)
            out += descendants(r['id'])
        return out

    out = []
    for c in by_parent.get(0, [])[:MAX_COMMENTS]:
        item = conv(c)
        item['replies'] = [conv(r) for r in sorted(descendants(c['id']), key=lambda r: r.get('added') or '')]
        out.append(item)
    return out


def tv_extras(t, target, page=True):
    """Saved page for a Thingiverse thing (its files are the model; there are no separate attachments)."""
    if not page:
        return
    try:
        embed = Embedder()
        imgs = tv_get('/things/%s/images' % t['id'])
        text = ''.join(clean_html(t.get(k), embed) for k in ('description_html',) if t.get(k))
        if t.get('instructions_html'):
            text += '<h3>Print settings &amp; instructions</h3>' + clean_html(t['instructions_html'], embed)
        comments = []
        if COMMENTS['on']:
            try:
                comments = tv_comments(t['id'], Embedder())
            except Exception as e:
                print('WARNING:   comments: %s' % e, file=sys.stderr)
        creator = t.get('creator') or {}
        write_page(target, {
            'title': t.get('name'), 'author': creator.get('name'), 'author_url': creator.get('public_url'),
            'site': 'Thingiverse', 'url': t.get('public_url'), 'license': t.get('license'),
            'published': (t.get('added') or '')[:10], 'tags': [x.get('name') for x in t.get('tags') or [] if x.get('name')],
            'images': [embed(tv_image(i)) for i in imgs if isinstance(i, dict)] if isinstance(imgs, list) else [],
            'description': text, 'comments': comments})
    except Exception as e:
        print('WARNING:   saved page: %s' % e, file=sys.stderr)


def add_thingiverse(tid, args, dest_root):
    t = tv_get('/things/%s' % tid)
    info = tv_info(t)
    print('Thingiverse: %s by %s' % (t.get('name'), info.get('author')))
    folder = safe_name(args.name) if args.name else '%s_%s' % (re.sub(r'[^A-Za-z0-9]+', '_', t.get('name') or 'thing').strip('_'), tid)
    target = os.path.join(dest_root, folder)
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway." % target)
    if args.file:   # a zip from the Thingiverse site already has files/, images/ and README.txt
        unpack_download(os.path.abspath(args.file), target)
    else:
        files = tv_get('/things/%s/files' % tid)
        if not files:
            sys.exit('Thingiverse thing %s has no files.' % tid)
        os.makedirs(os.path.join(target, 'files'), exist_ok=True)
        for f in files:
            save_url(f.get('direct_url') or f['download_url'], os.path.join(target, 'files', safe_name(f['name'])), tv_headers())
        print('  downloaded %d files' % len(files))
    readme = os.path.join(target, 'README.txt')
    if not os.path.exists(readme):
        with open(readme, 'w', encoding='utf-8', newline='\n') as f:   # same first line as Thingiverse's own zips
            f.write('%s by %s on Thingiverse: %s\n\n' % (t.get('name'), info.get('author'), info['url']))
            if t.get('license'):
                f.write('License: %s\n' % t['license'])
    tv_extras(t, target, page=not args.no_page)
    return info, target


# ---------------------------------------------------------------- per-site handlers
DOWNLOAD_LINK = ('mutation GetDownloadLink($id: ID!, $printId: ID!, $fileType: DownloadFileTypeEnum!, $source: DownloadSourceEnum!) '
                 '{ getDownloadLink(id: $id, printId: $printId, fileType: $fileType, source: $source) '
                 '{ ok errors { field messages } output { link } } }')


PRINTABLES_FIELDS = ('id name slug user { publicUsername handle } image { filePath } downloadPacks { id fileType } stls { id name } '
                     'summary description datePublished license { name } images { filePath } otherFiles { id name }')


def printables_link(pid):
    def link(file_id, ftype):
        r = ur.gql(DOWNLOAD_LINK, {'id': str(file_id), 'printId': str(pid), 'fileType': ftype, 'source': 'model_detail'})['getDownloadLink']
        if not r.get('ok'):
            sys.exit('Printables refused the download: %s' % ', '.join(m for e in r.get('errors') or [] for m in e.get('messages') or []))
        return r['output']['link']
    return link


def add_printables(pid, tmp, args, dest_root):
    p = (ur.gql('query { print(id: "%s") { %s } }' % (pid, PRINTABLES_FIELDS)) or {}).get('print')
    if not p:
        sys.exit('Printables model %s was not found (removed or private?).' % pid)
    info = ur.printables_info(p)
    info['manual'] = True
    print('Printables: %s by %s' % (p['name'], info.get('author')))

    target = os.path.join(dest_root, safe_name(args.name) if args.name else '%s-model_files' % p['slug'])
    if os.path.exists(target) and not args.force:
        sys.exit("'%s' already exists. Use --force to download into it anyway." % target)
    os.makedirs(target, exist_ok=True)
    link = printables_link(pid)

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
    printables_extras(p, target, link, page=not args.no_page)
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

    if args.file:
        src = os.path.abspath(args.file)
    elif makerworld_token():
        # Logged in: <Model+Name>/STL-CAD/ (the model files, when the designer uploaded them)
        # and <Model+Name>/3MF/<profile name>.3mf for every print profile.
        target = os.path.join(dest_root, safe_name(args.name) if args.name else safe_name(re.sub(r'\s+', '+', d['title'])))
        if os.path.exists(target) and not args.force:
            sys.exit("'%s' already exists. Use --force to download into it anyway." % target)
        got, problems = 0, []
        instances = d.get('instances') or []
        if (d.get('designExtension') or {}).get('model_files'):
            try:
                url, fname = mw_link(mw_api('/api/v1/design-service/design/%s/model' % mid))
                fname = fname or urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit('/', 1)[-1])
                f = os.path.join(tmp, safe_name(fname))
                save_url(url, f)
                sub = os.path.join(target, 'STL-CAD')
                os.makedirs(sub, exist_ok=True)
                if ur.ext_of(f).lower() == '.zip':
                    print('  STL-CAD: extracted %d files' % extract_model_zip(f, sub))
                    os.remove(f)
                else:
                    shutil.move(f, os.path.join(sub, safe_name(fname)))
                got += 1
            except (RuntimeError, OSError, zipfile.BadZipFile, urllib.error.URLError) as e:
                problems.append('STL/CAD files: %s' % e)
        else:
            print('  this model has no STL/CAD files, only print profiles')

        used = set()
        for inst in instances:
            pname = inst.get('title') or 'Profile %s' % inst.get('id')
            try:
                url, _ = mw_link(mw_api('/api/v1/design-service/instance/%s/f3mf?type=download' % inst['id']))
                fn = safe_name(pname + '.3mf')
                if fn.lower() in used:
                    fn = safe_name('%s (%s).3mf' % (pname, inst['id']))
                sub = os.path.join(target, '3MF')
                os.makedirs(sub, exist_ok=True)
                save_url(url, os.path.join(sub, fn))
                used.add(fn.lower())
                got += 1
            except (RuntimeError, OSError, urllib.error.URLError) as e:
                problems.append("profile '%s': %s" % (pname, e))
        for p in problems:
            print('WARNING:   ' + p, file=sys.stderr)
        if not got:
            if os.path.isdir(target) and not os.listdir(target):
                os.rmdir(target)
            sys.exit('nothing could be downloaded from MakerWorld model %s' % mid)
        print('  downloaded %d of %d print profiles' % (len(used), len(instances)))
        makerworld_extras(d, target, page=not args.no_page)
        return info, target
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
    makerworld_extras(d, target, page=not args.no_page)
    return info, target


def fill_pages(scopes, args):
    """Saved page + Instructions/ for models already in readme-sources.json (no model files are downloaded)."""
    cache = ur.load_cache()
    todo, skipped_files, done_already = [], 0, 0
    # a model is done when it has the last file this run would make (pages made before the PDF existed get redone)
    marker_name = INSTRUCTIONS_DIR if args.no_page else PDF_NAME if PDF['on'] and pdf_browser() else PAGE_NAME
    for key in ur.osort(cache, lambda k: k):
        info = cache[key]
        if info.get('source') not in ('printables', 'makerworld', 'cults3d', 'thingiverse') or not info.get('id'):
            continue
        full = os.path.join(ur.REPO, *key.split('/'))
        if not any(full == s or full.startswith(s + os.sep) for s in scopes) or not os.path.exists(full):
            continue
        if not os.path.isdir(full):   # a lone .zip/.3mf: no folder to put the page in
            skipped_files += 1
            continue
        if os.path.exists(os.path.join(full, marker_name)) and not args.force:
            done_already += 1
            continue
        todo.append((key, info, full))
    print('%d model folder(s) to fill in%s%s.' % (
        len(todo), ', %d already have %s (--force redoes them)' % (done_already, marker_name) if done_already else '',
        ', %d single-file models skipped' % skipped_files if skipped_files else ''))
    failed = []
    for n, (key, info, full) in enumerate(todo, 1):
        print('[%d/%d] %s' % (n, len(todo), key))
        try:
            if info['source'] == 'printables':
                p = (ur.gql('query { print(id: "%s") { %s } }' % (info['id'], PRINTABLES_FIELDS)) or {}).get('print')
                if not p:
                    raise RuntimeError('Printables model %s was not found (removed or private?)' % info['id'])
                printables_extras(p, full, printables_link(info['id']), page=not args.no_page)
            elif info['source'] == 'cults3d':
                cults_extras(cults_creation(info['id']), full, page=not args.no_page)
            elif info['source'] == 'thingiverse':
                tv_extras(tv_get('/things/%s' % info['id']), full, page=not args.no_page)
            else:
                d = ur.http_json('https://makerworld.com/api/v1/design-service/design/%s' % info['id'])
                if not d.get('title'):
                    raise RuntimeError('MakerWorld model %s was not found' % info['id'])
                makerworld_extras(d, full, page=not args.no_page)
        except (Exception, SystemExit) as e:
            msg = str(e.code if isinstance(e, SystemExit) else e)
            print('WARNING:   %s' % msg, file=sys.stderr)
            failed.append('%s - %s' % (key, msg))
    print('Filled in %d of %d model folders.' % (len(todo) - len(failed), len(todo)))
    if failed:
        print('Failed:')
        for f in failed:
            print('  ' + f)


# ---------------------------------------------------------------- --match: find the web page for models with no id
def read_3mf_meta(full):
    """Title / Designer / DesignModelId etc. from the first .3mf of a model (MakerWorld and Bambu Studio write these)."""
    files = [full] if os.path.isfile(full) else ur.all_files(full)
    for f in files:
        if ur.ext_of(f).lower() != '.3mf':
            continue
        try:
            with zipfile.ZipFile(f) as z:
                name = next((n for n in z.namelist() if n.lower() == '3d/3dmodel.model'), None)
                if not name:
                    continue
                with z.open(name) as fh:
                    head = fh.read(200000).decode('utf-8', 'replace')
            md = {k: html.unescape(html.unescape(v)).strip()
                  for k, v in re.findall(r'<metadata name="([^"]+)">([^<]*)</metadata>', head)}
            if md.get('Title') or md.get('DesignModelId'):
                return md
        except (OSError, zipfile.BadZipFile, KeyError):
            continue
    return {}


def mw_info(h):
    """Cache entry from a MakerWorld search hit or design."""
    return {'source': 'makerworld', 'id': str(h['id']), 'name': h.get('title'),
            'author': (h.get('designCreator') or {}).get('name'),
            'url': 'https://makerworld.com/en/models/%s-%s' % (h['id'], h.get('slug')),
            'imageUrl': ur.makerworld_cover(h.get('cover') or h.get('coverUrl')), 'manual': True}


def mw_hits(query):
    time.sleep(0.4)
    r = ur.http_json('https://makerworld.com/api/v1/search-service/select/design2?keyword=%s&limit=20' % ur.escape_data(query))
    return r.get('hits') or []


def printables_hits(query, limit=5):
    """Printables needs every word to match, so retry with the first few words when a long title finds nothing."""
    words = re.sub(r'["\\]', ' ', query).split()
    for q in dict.fromkeys([' '.join(words), ' '.join(words[:3])]):
        if not q:
            continue
        d = ur.gql('query { searchPrints2(query: "%s", limit: %d) { items { %s } } }' % (q, limit, ur.PRINT_FIELDS))
        items = ((d or {}).get('searchPrints2') or {}).get('items') or []
        if items:
            return items
    return []


def info_from_url(u, key):
    m = re.search(r'printables\.com/(?:[a-z]{2}/)?model/(\d+)', u, re.I)
    if m:
        info = ur.printables_by_id(m.group(1))
        if not info:
            raise RuntimeError('Printables model %s was not found' % m.group(1))
        info['manual'] = True
        return info
    m = re.search(r'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)', u, re.I)
    if m:
        d = ur.http_json('https://makerworld.com/api/v1/design-service/design/%s' % m.group(1))
        if not d.get('title'):
            raise RuntimeError('MakerWorld model %s was not found' % m.group(1))
        return mw_info(d)
    m = re.search(TV_URL, u, re.I)
    if m:
        try:
            return tv_info(tv_get('/things/%s' % m.group(1)))
        except RuntimeError as e:
            print('  (%s - saving the link only)' % e)
            return {'source': 'thingiverse', 'id': m.group(1), 'name': ur.pretty(ur.stem_of(os.path.basename(key))),
                    'url': 'https://www.thingiverse.com/thing:' + m.group(1), 'manual': True}
    m = re.search(CULTS_URL, u, re.I)
    if m:
        try:
            return cults_info(cults_creation(m.group(1)))
        except RuntimeError as e:
            print('  (%s - saving the link only)' % e)
            return {'source': 'cults3d', 'id': m.group(1), 'name': ur.pretty(m.group(1)), 'url': u.split('?')[0], 'manual': True}
    t = thangs_parse(u)
    if t:
        return {'source': 'thangs', 'id': t[0], 'name': t[1], 'author': t[2], 'url': u.split('?')[0], 'manual': True}
    raise RuntimeError('not a Printables, MakerWorld, Thingiverse, Cults3D or Thangs model URL')


LINK_RE = re.compile(r'(?:https?://)?(?:www\.)?(?:thingiverse\.com/thing:\d+|printables\.com/(?:[a-z]{2}/)?model/\d+[^\s"\'<>)\]]*|'
                     r'makerworld\.com/(?:[a-z]{2}/)?models/\d+[^\s"\'<>)\]]*|cults3d\.com/(?:[a-z]{2}/)?3d-model/[^\s"\'<>)\]]+|'
                     r'thangs\.com/designer/[^/\s]+/3d-model/[^\s"\'<>)\]]+)', re.I)
TEXT_FILE = re.compile(r'\.(txt|md|html?|url)$', re.I)


def file_links(full):
    """(exact, others) from the model's own files (folder or .zip):
    exact  - (url, why) for a file that names the model itself: a Thingiverse README.txt
             ("... on Thingiverse: <url>") or Printables' page PDF ("<id>-<slug>-<uuid>.pdf");
    others - [(url, file name)] for any other model links found in text files (often related models)."""
    entries = []   # (name, reader)
    if os.path.isdir(full):
        for f in ur.all_files(full):
            if os.path.basename(f).lower().startswith('model-page.'):
                continue   # pages this script saved
            entries.append((f[len(full) + 1:], lambda f=f: open(f, 'rb').read() if os.path.getsize(f) < 3_000_000 else b''))
    elif ur.ext_of(full).lower() == '.zip':
        try:
            z = zipfile.ZipFile(full)
            entries = [(n, lambda n=n: z.read(n) if z.getinfo(n).file_size < 3_000_000 else b'') for n in z.namelist()]
        except (OSError, zipfile.BadZipFile):
            pass
    exact, others = None, []
    for name, read in entries:
        base = name.replace('\\', '/').rsplit('/', 1)[-1]
        m = re.match(r'^(\d+)-[a-z0-9-]+-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$', base, re.I)
        if m and not exact:
            exact = ('https://www.printables.com/model/%s' % m.group(1), "Printables' page PDF " + base)
            continue
        if not TEXT_FILE.search(base):
            continue
        try:
            text = read().decode('utf-8', 'replace')
        except Exception:
            continue
        if base.lower() == 'readme.txt' and not exact:
            m = re.search(r' on Thingiverse:\s*(https?://\S*thingiverse\.com/thing:\d+)', text, re.I)
            if m:
                exact = (m.group(1), 'Thingiverse README.txt')
                continue
        for u in LINK_RE.findall(text):
            u = u if u.lower().startswith('http') else 'https://' + u
            if u.lower() not in (x[0].lower() for x in others):
                others.append((u, base))
    return exact, others


def match_models(scopes, args):
    cache = ur.load_cache()
    todo = []
    for key in ur.osort(cache, lambda k: k):
        info = cache[key]
        if info.get('id') or info.get('source') not in ('makerworld', 'printables', 'unknown'):
            continue
        if info.get('noMatch') and not args.force:
            continue
        full = os.path.join(ur.REPO, *key.split('/'))
        if any(full == s or full.startswith(s + os.sep) for s in scopes) and os.path.exists(full):
            todo.append(key)
    interactive = sys.stdin.isatty() and not args.auto_only
    print('%d model(s) without a web page to match.%s' % (
        len(todo), '' if interactive else " Only exact matches (from the model's own files) are saved in this mode."))
    if interactive:
        print('For each one: type a number to pick it, paste the model URL, type other words to search again,\n'
              'Enter to skip, x if it is not online (never asked again), or q to stop.')
    matched = 0

    def save(key, info, count=True):
        nonlocal matched
        cache[key] = info
        ur.save_cache(cache)
        matched += count

    for n, key in enumerate(todo, 1):
        full = os.path.join(ur.REPO, *key.split('/'))
        md = read_3mf_meta(full)
        print('\n[%d/%d] %s' % (n, len(todo), key))
        try:
            query = md.get('Title') or ur.pretty(ur.stem_of(os.path.basename(full)) if os.path.isfile(full) else os.path.basename(full))
            if md:
                print('  3MF says: "%s"%s' % (md.get('Title', '?'), ' by %s' % md['Designer'] if md.get('Designer') else ''))
            named, linked = file_links(full)
            if named:
                try:
                    info = info_from_url(named[0], key)
                    save(key, info)
                    print('  matched (exact, from %s): %s  %s' % (named[1], info.get('name'), info['url']))
                    continue
                except Exception as e:   # e.g. the model was removed from the site: fall back to searching
                    print('  %s names %s, but: %s' % (named[1], named[0], e))
            mw = mw_hits(query) if query else []
            mid = md.get('DesignModelId')
            exact = next((h for h in mw if mid and (h.get('modelId') == mid or '/model/%s/' % mid in (h.get('cover') or ''))), None)
            if exact:
                info = mw_info(exact)
                save(key, info)
                print('  matched (exact, from the 3MF): %s by %s  %s' % (info['name'], info['author'], info['url']))
                continue
            if not interactive:
                print('  no exact match')
                continue
            while True:
                uid = md.get('DesignerUserId')
                same = [h for h in mw if uid and str((h.get('designCreator') or {}).get('uid')) == uid]
                cands = [(mw_info(h), ' (same designer)') for h in same[:5]]
                cands += [(mw_info(h), '') for h in mw if h not in same][:max(0, 5 - len(cands))]
                try:
                    cands += [(dict(ur.printables_info(p), manual=True), '') for p in printables_hits(query)]
                except Exception as e:
                    print('  (Printables search failed: %s)' % e)
                try:
                    cands += [(cults_info(h), '') for h in cults_hits(query, 3)]
                except Exception as e:
                    print('  (Cults3D search failed: %s)' % e)
                try:
                    cands += [(tv_info(h), '') for h in tv_hits(query, 3)]
                except Exception as e:
                    print('  (Thingiverse search failed: %s)' % e)
                if not md:   # a Bambu 3MF almost always comes from MakerWorld; otherwise show Printables first
                    cands = [c for c in cands if c[0]['source'] == 'printables'] + [c for c in cands if c[0]['source'] != 'printables']
                # same title as the 3MF / folder name: likely the one, so marked and listed first
                want = ur.norm(query)
                cands = [(c, note + ' (exact title)' if want and ur.norm(c.get('name')) == want else note) for c, note in cands]
                cands = [x for x in cands if 'exact title' in x[1]] + [x for x in cands if 'exact title' not in x[1]]
                # links found in the model's own files (related models, the designer's other work...) come first
                for u, fname in reversed(linked[:5]):
                    try:
                        cands.insert(0, (info_from_url(u, key), ' (linked in %s)' % fname))
                    except Exception:
                        pass
                linked = []   # only on the first round, not after a new search
                seen_urls = set()
                cands = [x for x in cands if not (x[0]['url'] in seen_urls or seen_urls.add(x[0]['url']))]
                if not cands:
                    print('  no search results for "%s"' % query)
                for i, (c, note) in enumerate(cands, 1):
                    print('  %d) %s - by %s [%s]%s\n     %s' % (i, c['name'], c.get('author') or '?', ur.SITE_NAME[c['source']], note, c['url']))
                a = ask('  > ').strip()
                if not a:
                    break
                if a.lower() == 'q':
                    raise KeyboardInterrupt
                if a.lower() == 'x':
                    save(key, {'source': 'unknown', 'manual': True, 'noMatch': True}, count=False)
                    print('  marked as not online')
                    break
                if a.isdigit() and 1 <= int(a) <= len(cands):
                    save(key, cands[int(a) - 1][0])
                    print('  saved: %s' % cands[int(a) - 1][0]['url'])
                    break
                if re.match(r'https?://', a, re.I):
                    try:
                        info = info_from_url(a, key)
                        save(key, info)
                        print('  saved: %s - %s' % (info.get('name'), info['url']))
                        break
                    except Exception as e:
                        print('  %s' % e)
                        continue
                query = a
                mw = mw_hits(query)
        except KeyboardInterrupt:
            print('\nStopped.')
            break
        except Exception as e:
            print('WARNING:   %s' % e, file=sys.stderr)
    print('\nMatched %d model(s).' % matched)
    if matched:
        print('Add their saved pages with:  add_model.py --fill-pages %s' % ' '.join(
            ur.rel(s) or '.' for s in scopes))
        if not args.no_readme:
            print('Updating READMEs ...')
            ur.main([])


def resolve_dest(folder):
    d = os.path.realpath(os.path.expanduser(folder)).rstrip(os.sep)   # realpath, like REPO
    if not d.startswith(ur.REPO + os.sep):
        sys.exit("Folder '%s' must be a category folder inside the repo (%s)." % (d, ur.REPO))
    return d


def read_url_list(path, default_folder):
    """'<url>' or '<url> <folder>' per line; blank lines and # comments are skipped."""
    jobs = []
    if not os.path.isfile(path):
        sys.exit("URL list '%s' not found (looked in %s)." % (path, os.getcwd()))
    with open(path, 'rb') as f:
        raw = f.read()
    # Windows PowerShell's ">" / Out-File write UTF-16, so honour a UTF-16 byte-order mark.
    text = raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8-sig', errors='replace')
    for line in text.splitlines():
        t = re.sub(r'(^|\s)#.*$', '', line).strip()
        if not t:
            continue
        parts = re.split(r'\s+', t, maxsplit=1)
        jobs.append((parts[0], parts[1].strip() if len(parts) > 1 else default_folder))
    if not jobs:
        sys.exit("URL list '%s' has no URLs in it (%d bytes; blank lines and # comments are skipped)." % (path, len(raw)))
    return jobs


def main():
    ap = argparse.ArgumentParser(description='Download a Printables / MakerWorld model into this repo and update the READMEs.')
    ap.add_argument('url', nargs='*', help='Printables or MakerWorld model URL(s)')
    ap.add_argument('--list', metavar='FILE',
                    help='text file with one URL per line, optionally followed by a folder for that model; '
                         'blank lines and # comments are ignored')
    ap.add_argument('--folder', default='.', help='repo folder to put the model in (default: current directory)')
    ap.add_argument('--name', help="override the model folder's name (single URL only)")
    ap.add_argument('--file', help='MakerWorld: a zip/3mf you already downloaded (single URL only)')
    ap.add_argument('--all-files', action='store_true', help='Printables: also fetch the print files and other files packs')
    ap.add_argument('--force', action='store_true', help='download into the model folder even if it already exists')
    ap.add_argument('--no-readme', action='store_true', help="don't regenerate the READMEs afterwards")
    ap.add_argument('--no-page', action='store_true', help="don't save the model's page (%s / .pdf); attachments are still downloaded" % PAGE_NAME)
    ap.add_argument('--no-pdf', action='store_true', help="save the page as HTML only, without %s" % PDF_NAME)
    ap.add_argument('--no-comments', action='store_true', help="leave user comments out of the saved page")
    ap.add_argument('--fill-pages', action='store_true',
                    help='add %s and Instructions/ to models already in the repo (only those under the given '
                         'folders, or --folder / the current directory); model files are not downloaded' % PAGE_NAME)
    ap.add_argument('--match', action='store_true',
                    help='find the Printables / MakerWorld page for models that have no link yet (under the given '
                         'folders, or --folder / the current directory); exact matches from 3MF files are saved '
                         'automatically, for the rest you pick from search results')
    ap.add_argument('--auto-only', action='store_true', help='--match: only save exact matches, ask nothing')
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)   # keep progress and warnings in order when piped
    PDF['on'] = not args.no_pdf
    COMMENTS['on'] = not args.no_comments

    if args.fill_pages or args.match:
        scopes = [os.path.realpath(os.path.expanduser(f)).rstrip(os.sep) for f in (args.url or [args.folder])]
        for s in scopes:
            if s != ur.REPO and not s.startswith(ur.REPO + os.sep):
                sys.exit("Folder '%s' is not inside the repo (%s)." % (s, ur.REPO))
        if args.match:
            match_models(scopes, args)
        else:
            fill_pages(scopes, args)
        return

    jobs = []
    for u in args.url:   # a file name instead of a URL is read as a URL list, same as --list
        if not re.match(r'https?://', u, re.I) and os.path.isfile(u):
            jobs += read_url_list(u, args.folder)
        else:
            jobs.append((u, args.folder))
    if args.list:
        jobs += read_url_list(args.list, args.folder)
    if not jobs:
        ap.error('no model URLs given - pass one or more URLs, or a URL list file (--list FILE)')
    if (args.name or args.file) and len(jobs) > 1:
        sys.exit('--name and --file can only be used with a single URL.')
    jobs = [(u, resolve_dest(f)) for u, f in jobs]   # fail early on a bad folder

    added, failed = [], []
    # Log in to MakerWorld up front (once) when the list has MakerWorld links, so the run can go unattended.
    if not args.file and any(re.search(r'makerworld\.com/', u, re.I) for u, _ in jobs):
        try:
            makerworld_token()
        except RuntimeError as e:
            print('WARNING: %s MakerWorld models will open in the browser instead.' % e, file=sys.stderr)
            _mw['skip'] = True
    if any(re.search(CULTS_URL, u, re.I) for u, _ in jobs):
        cults_auth()   # ask for the API key up front too, if it isn't saved yet
    if any(re.search(TV_URL, u, re.I) for u, _ in jobs) and not args.file:
        tv_token()
    tmp = tempfile.mkdtemp(prefix='add-model-')
    try:
        for n, (u, dest_root) in enumerate(jobs, 1):
            if len(jobs) > 1:
                print('[%d/%d] %s' % (n, len(jobs), u))
            try:
                m = re.search(r'printables\.com/(?:[a-z]{2}/)?model/(\d+)', u, re.I)
                if m:
                    info, target = add_printables(m.group(1), tmp, args, dest_root)
                else:
                    m = re.search(r'makerworld\.com/(?:[a-z]{2}/)?models/(\d+)', u, re.I)
                    mc = re.search(CULTS_URL, u, re.I)
                    mt = re.search(TV_URL, u, re.I)
                    if m:
                        info, target = add_makerworld(m.group(1), tmp, args, dest_root, u)
                    elif mt:
                        info, target = add_thingiverse(mt.group(1), args, dest_root)
                    elif mc:
                        info, target = add_cults(mc.group(1), args, dest_root, u)
                    elif thangs_parse(u):
                        info, target = add_thangs(u, args, dest_root)
                    else:
                        sys.exit('not a Printables, MakerWorld, Thingiverse, Cults3D or Thangs model URL')
                key = ur.rel(target)
                cache = ur.load_cache()
                cache[key] = info
                ur.save_cache(cache)
                added.append(key)
                print('  added ' + key)
            except (Exception, SystemExit) as e:
                if len(jobs) == 1:
                    raise
                msg = str(e.code if isinstance(e, SystemExit) else e)
                print('WARNING: %s failed: %s' % (u, msg), file=sys.stderr)
                failed.append('%s - %s' % (u, msg))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if len(jobs) > 1:
        print('Added %d of %d models.' % (len(added), len(jobs)))
        if failed:
            print('Failed:')
            for f in failed:
                print('  ' + f)

    if added and not args.no_readme:
        print('Updating READMEs ...')
        ur.main([])


if __name__ == '__main__':
    main()
