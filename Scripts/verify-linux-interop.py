"""Verify generated fixtures using GNU tar, then verify reverse archives on macOS."""
import hashlib, json, os, pathlib, shutil, subprocess, sys

mode, root_arg = sys.argv[1:3]
root = pathlib.Path(root_arg).resolve()
formats = {'tar': '', 'tar.gz': 'z', 'tar.xz': 'J', 'tar.bz2': 'j'}

def tree(folder, permissions=False):
    result = {}
    for p in sorted(folder.rglob('*')):
        name = p.relative_to(folder).as_posix()
        if p.is_symlink():
            result[name] = {'link': os.readlink(p)}
        elif p.is_dir():
            result[name] = {'directory': True}
        else:
            result[name] = {'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            if permissions:
                result[name]['executable'] = bool(p.stat().st_mode & 0o111)
    return result

if mode == 'linux':
    subprocess.run(['tar', '--version'], check=True)
    expected = tree(root/'expected')
    for fmt in formats:
        archive = root/'archives'/('plain.'+fmt)
        out = root/('linux-'+fmt); out.mkdir()
        subprocess.run(['tar', '-xf', str(archive), '-C', str(out)], check=True)
        assert tree(out) == expected, fmt
        shutil.rmtree(out)
        print('LINUX_GNU_TAR_SHA256_AND_CLEAN_PATHS_PASSED', fmt, flush=True)
    # Linux-origin PAX archives include executable files, an empty directory,
    # a safe relative symlink and paths longer than the classic TAR name field.
    reverse = root/'linux-reverse'; reverse.mkdir()
    payload = root/'linux-payload'; shutil.copytree(root/'expected', payload)
    files = payload/'Linux files'; files.mkdir()
    (files/'empty directory').mkdir()
    script = files/'run.sh'; script.write_text('#!/bin/sh\nprintf "interop\\n"\n'); script.chmod(0o755)
    (files/'safe-link').symlink_to('run.sh')
    deep = files/('long-'+'x'*110); deep.mkdir()
    (deep/'空 格.txt').write_text('Linux → macOS\n')
    (reverse/'expected.json').write_text(json.dumps(tree(payload, True), ensure_ascii=False))
    for fmt, flag in formats.items():
        archive = reverse/('linux.'+fmt)
        subprocess.run(['tar', '--format=pax', '-c'+flag+'f', str(archive), '-C', str(payload), '.'], check=True)
    shutil.rmtree(payload)
    print('LINUX_REVERSE_FIXTURES_CREATED', flush=True)
elif mode == 'mac':
    reader, engine = map(str, map(pathlib.Path.resolve, map(pathlib.Path, sys.argv[3:5])))
    expected = json.loads((root/'expected.json').read_text())
    for fmt in formats:
        archive = root/('linux.'+fmt)
        subprocess.run([reader, 'list', engine, str(archive), str(root/'unused'), fmt], check=True)
        out = root/('mac-'+fmt)
        subprocess.run([reader, 'extract', engine, str(archive), str(out), fmt], check=True)
        actual = tree(out, True)
        assert actual == expected, {'format': fmt, 'missing': expected.keys()-actual.keys(), 'extra': actual.keys()-expected.keys(),
                                    'different': [k for k in expected.keys() & actual.keys() if expected[k] != actual[k]]}
        shutil.rmtree(out)
        assert not list(root.glob('.aetherzip-*'))
        print('MAC_LINUX_TAR_CONTENT_PATHS_MODES_LINKS_PASSED', fmt, flush=True)
else:
    raise SystemExit('Expected linux or mac mode')
