"""Offline transcription worker. Emits UTF-8 JSON lines for the Windows UI."""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import traceback

ROOT = Path(__file__).resolve().parent
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['HF_HUB_DISABLE_XET'] = '1'
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')


def emit(kind, **data):
    print(json.dumps(dict(kind=kind, **data), ensure_ascii=False), flush=True)


def save_text(path, text, overwrite=False, expected_mtime=None):
    """Same-directory atomic publication; never truncate an existing transcript."""
    path = Path(path)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        if overwrite:
            if expected_mtime is not None and path.exists() and path.stat().st_mtime_ns != expected_mtime:
                raise FileExistsError('Markdown-filen har ändrats under transkriberingen. Starta om för att spara.')
            os.replace(temporary, path)
        else:
            # On Windows rename fails if destination exists, including a concurrent creation.
            os.rename(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def transcribe(job):
    started = time.monotonic()
    source = Path(job['audio']).resolve(strict=True)
    target = source.with_suffix('.md')
    if source == target:
        raise ValueError('Välj en ljudfil, inte en Markdown-fil.')
    overwrite = bool(job.get('overwrite', False))
    expected = target.stat().st_mtime_ns if target.exists() else None
    if target.exists() and not overwrite:
        raise FileExistsError(f'Filen finns redan: {target}')
    language = job['language']
    if language not in ('sv', 'en'):
        raise ValueError('Välj svenska eller engelska.')
    model_key = ('sv-large' if job.get('quality') == 'large' else 'sv-small') if language == 'sv' else 'en'
    model_path = ROOT / 'models' / model_key
    if not (model_path / 'model.bin').is_file():
        raise FileNotFoundError('Modellen saknas. Kör download_models.py för att installera den.')
    emit('status', text='Läser ljudfilen …')
    from faster_whisper import WhisperModel, decode_audio
    audio = decode_audio(str(source), sampling_rate=16000)
    duration = len(audio) / 16000
    if not duration:
        raise ValueError('Ljudfilen är tom.')
    emit('status', text='Laddar språkmodellen …', duration=duration)
    model = WhisperModel(str(model_path), device='cpu', compute_type='int8',
                         cpu_threads=min(8, os.cpu_count() or 4), num_workers=1,
                         local_files_only=True)
    emit('status', text='Transkriberar …', duration=duration, model=model_key)
    segments, info = model.transcribe(audio, language=language, task='transcribe',
                                     beam_size=5, condition_on_previous_text=False,
                                     vad_filter=True, vad_parameters={'min_silence_duration_ms': 500})
    decode_started = time.monotonic()
    paragraphs, paragraph = [], []
    previous_end = 0.0
    processed = 0.0
    for segment in segments:
        text = segment.text.strip()
        if text:
            if paragraph and (segment.start - previous_end >= 2.0 or sum(map(len, paragraph)) >= 700):
                paragraphs.append(' '.join(paragraph))
                paragraph = []
            paragraph.append(text)
            previous_end = segment.end
        processed = max(processed, min(segment.end, duration))
        elapsed = time.monotonic() - decode_started
        speed = processed / max(elapsed, .001)
        emit('progress', percent=min(99, processed / duration * 100), processed=processed,
             duration=duration, elapsed=time.monotonic() - started, speed=speed,
             remaining=max(0, duration - processed) / max(speed, .001), text=text)
    if paragraph:
        paragraphs.append(' '.join(paragraph))
    if not paragraphs:
        emit('empty', text='Inget tal kunde identifieras. Ingen Markdown-fil har skapats.')
        return
    emit('status', text='Sparar Markdown-filen …')
    save_text(target, '\n\n'.join(paragraphs) + '\n', overwrite, expected)
    emit('done', output=str(target), elapsed=time.monotonic() - started, duration=duration,
         model=model_key, paragraphs=len(paragraphs))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--job', required=True)
    args = parser.parse_args()
    try:
        with open(args.job, encoding='utf-8-sig') as stream:
            transcribe(json.load(stream))
    except Exception as error:
        traceback.print_exc(file=sys.stderr)
        emit('error', text=str(error))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
