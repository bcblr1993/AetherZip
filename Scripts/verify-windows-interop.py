"""Only generated public fixtures are transferred between CI runners."""
import hashlib, pathlib, shutil, subprocess, sys

root = pathlib.Path(sys.argv[1]).resolve()
seven = shutil.which('7z') or r'C:\Program Files\7-Zip\7z.exe'
password = 'AetherZip-large-fixture-only-2026!'

def tree(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file()}

expected = tree(root/'expected')
assert len(expected) == 4
archives = [root/'archives'/name for name in ['plain.zip','encrypted.zip','encrypted.7z','split.volumes/split.7z.001']]
for i, archive in enumerate(archives):
    out = root/f'windows-output-{i}'
    subprocess.run([seven, 'x', '-y', '-p'+password, '-o'+str(out), str(archive)], check=True)
    assert tree(out) == expected, archive.name
    shutil.rmtree(out)
    print('WINDOWS_SHA256_AND_CLEAN_PATHS_PASSED', archive.name, flush=True)

# Also exercise Windows' ordinary ZIP extraction API independently of 7-Zip.
subprocess.run(['powershell', '-NoProfile', '-Command',
    'Expand-Archive -LiteralPath $args[0] -DestinationPath $args[1]',
    str(archives[0]), str(root/'windows-native')], check=True)
assert tree(root/'windows-native') == expected
shutil.rmtree(root/'windows-native')
print('WINDOWS_EXPAND_ARCHIVE_PASSED', flush=True)

reverse = root/'reverse'
reverse.mkdir()
for fmt in ['zip', '7z']:
    cmd = [seven, 'a', '-t'+fmt, '-p'+password]
    cmd += ['-mem=AES256'] if fmt == 'zip' else ['-mhe=on']
    subprocess.run(cmd + [str(reverse/('windows.'+fmt)), '.'], cwd=root/'expected', check=True)
print('WINDOWS_REVERSE_FIXTURES_CREATED', flush=True)
