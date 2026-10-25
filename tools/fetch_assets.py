"""Fetch original upstream packs, preserve licenses, stage selected game-ready files."""
from pathlib import Path
import concurrent.futures, hashlib, json, re, shutil, urllib.request, zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path('D:/GameDev/asset-downloads')
PACKS = ['space-station-kit', 'blaster-kit', 'sci-fi-sounds', 'interface-sounds', 'ui-pack-sci-fi']

def fetch(slug):
    page = 'https://kenney.nl/assets/' + slug
    html = urllib.request.urlopen(page, timeout=30).read().decode()
    urls = re.findall(r'href=[\"\']([^\"\']+\.zip)', html)
    if not urls: raise RuntimeError('No official archive for ' + slug)
    url = urls[-1]
    target = CACHE / url.rsplit('/', 1)[1]
    if not target.exists():
        with urllib.request.urlopen(url, timeout=90) as src, target.open('wb') as dst:
            shutil.copyfileobj(src, dst)
    dest = CACHE / slug
    dest.mkdir(exist_ok=True)
    with zipfile.ZipFile(target) as archive:
        for member in archive.infolist():
            resolved = (dest / member.filename).resolve()
            if not resolved.is_relative_to(dest.resolve()): raise RuntimeError('Unsafe archive entry')
        archive.extractall(dest)
    licenses = [p for p in dest.rglob('*') if p.is_file() and 'license' in p.name.lower()]
    if not licenses: raise RuntimeError('No license inside ' + slug)
    notices = ROOT / 'third_party' / slug
    notices.mkdir(parents=True, exist_ok=True)
    for i, p in enumerate(licenses): shutil.copy2(p, notices / (str(i) + '-' + p.name))
    print(slug, 'licenses:', [p.read_text(errors='replace')[:250] for p in licenses], flush=True)
    entry = dict(id=slug, author='Kenney', source=page, download=url,
                 license='CC0-1.0', sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                 original_archive=str(target), modifications='Selected meshes/materials and sounds adapted for industrial palette and gameplay; originals retained outside runtime.')
    return entry

if __name__ == '__main__':
    CACHE.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        entries = list(pool.map(fetch, PACKS))
    (ROOT / 'third_party/asset-register.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding='utf8')
    for slug in ('space-station-kit', 'blaster-kit'):
        dest = ROOT / 'assets/models' / slug
        dest.mkdir(exist_ok=True)
        for src in (CACHE / slug).rglob('*.glb'): shutil.copy2(src, dest / src.name)
    for slug in ('sci-fi-sounds', 'interface-sounds'):
        for src in (CACHE / slug).rglob('*.ogg'): shutil.copy2(src, ROOT / 'assets/audio' / src.name)
    ui = ROOT / 'assets/ui/kenney'
    ui.mkdir(exist_ok=True)
    sources = [p for p in (CACHE/'ui-pack-sci-fi').rglob('*.png') if 'Double' not in str(p)]
    for src in sources[:80]: shutil.copy2(src, ui / src.name)
    print('ASSET_PACKS_READY', flush=True)
