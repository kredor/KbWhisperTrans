"""Download pinned model revisions from their publishers; no audio is uploaded."""
import os
import json
import hashlib
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['HF_HUB_DISABLE_XET'] = '1'

ROOT = Path(__file__).resolve().parent
MODELS = {
    'sv-small': ('KBLab/kb-whisper-small', '3564d61a42fc210ceaa55a22a96dd64478959c78'),
    'sv-large': ('KBLab/kb-whisper-large', 'd5d5984b4d8f7c4847a8ea203f1976285fb28300'),
    'en': ('Systran/faster-distil-whisper-large-v3', 'c3058b475261292e64a0412df1d2681c06260fab'),
}

def download_model(item):
    name, (repo, revision) = item
    folder = ROOT / 'models' / name
    folder.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(f'https://huggingface.co/api/models/{repo}/tree/{revision}') as response:
        listing = json.load(response)
    allowed = {'model.bin', 'config.json', 'tokenizer.json', 'vocabulary.json', 'preprocessor_config.json', 'README.md'}
    for entry in listing:
        filename = entry['path']
        if filename not in allowed:
            continue
        destination = folder / filename
        size = entry.get('size', 0)
        expected = entry.get('lfs', {}).get('oid')
        if destination.exists() and destination.stat().st_size == size:
            if not expected or hashlib.file_digest(destination.open('rb'), 'sha256').hexdigest() == expected:
                continue
        print(f'{name}: downloading {filename} ({size / 1e6:.1f} MB)', flush=True)
        temporary = destination.with_suffix(destination.suffix + '.download')
        digest = hashlib.sha256()
        count = 0
        last_report = 0
        with urllib.request.urlopen(f'https://huggingface.co/{repo}/resolve/{revision}/{filename}', timeout=120) as response, temporary.open('wb') as output:
            while chunk := response.read(4 * 1024 * 1024):
                output.write(chunk)
                digest.update(chunk)
                count += len(chunk)
                if count - last_report > 250_000_000:
                    print(f'{name}: {count / 1e6:.0f}/{size / 1e6:.0f} MB', flush=True)
                    last_report = count
        if count != size or (expected and digest.hexdigest() != expected):
            raise ValueError(f'Download verification failed: {name}/{filename}')
        os.replace(temporary, destination)
    (folder / 'source.json').write_text(json.dumps({'repo': repo, 'revision': revision}, indent=2), encoding='utf-8')
    print(f'Ready: {name}', flush=True)


if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(download_model, MODELS.items()))
