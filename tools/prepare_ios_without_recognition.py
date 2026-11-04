"""Remove music recognition from an explicit iOS export checkout before Godot import."""
from pathlib import Path
import argparse, shutil

def prepare(project):
    root = Path(project).resolve()
    if not (root / 'project.godot').is_file():
        raise RuntimeError('Expected a SYNK project checkout')
    path = root / 'scripts/song_details.gd'
    source = path.read_text(encoding='utf-8-sig')
    if 'var recognition:Node' in source:
        lines = source.splitlines(keepends=True)
        lines = [line for line in lines if not line.startswith('var recognition') and not line.startswith('const TOKEN_FILE=')]
        source = ''.join(lines)
        start = source.index('\trecognition_button=action(')
        end = source.index('\n\tvar rows=', start)
        source = source[:start] + source[end:]
        start = source.index('\trecognition=preload(')
        end = source.index('\n\tvisible=false', start)
        source = source[:start] + source[end:]
        source = source[:source.index('\nfunc configure_recognition()')].rstrip() + '\n'
    if 'recognition' in source.lower():
        raise RuntimeError('Unexpected recognition reference remains in Song Details')
    path.write_text(source, encoding='utf-8', newline='\n')
    native = (root / 'assets/native/chromaprint').resolve()
    if not native.is_relative_to(root) or native == root:
        raise RuntimeError('Unsafe native-library target')
    if native.exists():
        shutil.rmtree(native)
    for suffix in ['', '.uid']:
        client = root / ('scripts/music_recognition.gd' + suffix)
        if client.exists():
            client.unlink()
    presets = root / 'export_presets.cfg'
    value = presets.read_text(encoding='utf-8')
    value = value.replace('assets/native/chromaprint/*.md,assets/native/chromaprint/*.txt,assets/native/chromaprint/*.zip', '')
    presets.write_text(value, encoding='utf-8', newline='\n')
    print('iOS music recognition removed: UI, client, native extension and dependencies.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', required=True)
    prepare(parser.parse_args().project)
