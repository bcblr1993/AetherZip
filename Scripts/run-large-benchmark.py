#!/usr/bin/env python3
"""Opt-in multi-GB benchmark. Never part of swift test. Own generated extraction folders are removed after SHA-256 verification.
Generated data is removed on success, failure, or interruption; only measurements remain.
Use --keep-data explicitly to retain fixtures for a follow-up investigation.
"""
import argparse, atexit, hashlib, json, os, pathlib, shutil, signal, subprocess, sys, time, zipfile
from datetime import datetime

REPO = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--keep-data', action='store_true')
parser.add_argument('--profile', choices=['full', 'low-memory'], default='full')
args = parser.parse_args()
GIB = 1024**3
ROOT = REPO / '.build' / ('large-benchmark-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
ROOT.mkdir(parents=True, exist_ok=False)
owned_data = []
active_process = None

def cleanup():
    global active_process
    if active_process is not None and active_process.poll() is None:
        # The runner and engine have their own process group. Reap it before removing data.
        os.killpg(active_process.pid, signal.SIGCONT)
        os.killpg(active_process.pid, signal.SIGTERM)
        try: active_process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(active_process.pid, signal.SIGKILL)
            active_process.wait()
    if args.keep_data: return
    removed = []
    # ROOT was exclusively created by this invocation; never search user-selected folders.
    candidates = owned_data + list(ROOT.glob('.aetherzip-*'))
    for path in candidates:
        if path.parent != ROOT: raise RuntimeError('Cleanup path escaped benchmark root')
        if path.is_symlink(): path.unlink()
        elif path.is_dir(): shutil.rmtree(path)
        elif path.exists(): path.unlink()
        else: continue
        removed.append(path.name)
    (ROOT/'cleanup.json').write_text(json.dumps({'removed':removed,'remaining_free_bytes':shutil.disk_usage(ROOT).free},indent=2))

atexit.register(cleanup)
def interrupted(signum, frame): raise SystemExit(128 + signum)
signal.signal(signal.SIGTERM, interrupted)
signal.signal(signal.SIGINT, interrupted)
required_gib = 50 if args.profile == 'full' else 10
if shutil.disk_usage(ROOT).free < required_gib * GIB:
    raise SystemExit(f'Need at least {required_gib} GiB free before creating fixtures')
ENGINE = pathlib.Path.home() / 'Applications/AetherZip.app/Contents/Resources/7zz'
if not ENGINE.exists(): ENGINE = REPO / 'Resources/7zz'
RUNNER = ROOT / 'benchmark'
subprocess.run(['xcrun', 'swiftc', '-O', '-swift-version', '6', '-module-name', 'AetherZipBenchmark',
                *map(str, sorted((REPO/'Sources/Core').glob('*.swift'))),
                str(REPO/'Scripts/benchmark.swift'), '-o', str(RUNNER)], check=True)
print('RESULT_ROOT=' + str(ROOT), flush=True)

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        while block := f.read(8*1024*1024): h.update(block)
    return h.hexdigest()

def generate(path, size, random=False):
    start = time.monotonic(); h = hashlib.sha256()
    # Repeated structured content, not sparse files or zero-filled test files.
    record = (b'{"timestamp":"2026-10-12T14:00:00Z","device":"sensor-042","temperature":23.75,"status":"online","payload":"AetherZip large archive benchmark"}\n')
    block = (record * (4*1024*1024 // len(record) + 1))[:4*1024*1024]
    with path.open('xb') as f:
        remaining = size
        while remaining:
            part = os.urandom(min(4*1024*1024, remaining)) if random else block[:remaining]
            f.write(part); h.update(part); remaining -= len(part)
    print(json.dumps({'fixture':path.name,'bytes':size,'generation_seconds':round(time.monotonic()-start,2)}), flush=True)
    return {path.name: {'bytes':size,'sha256':h.hexdigest()}}

random_gib = 4 if args.profile == 'full' else 2
random_file = ROOT/f'random-{random_gib}GiB-plus-64KiB.bin'
owned_data.append(random_file)
random_manifest = generate(random_file,random_gib*GIB+65536,True)
log_manifest = {}; small_manifest = {}
if args.profile == 'full':
    log_file = ROOT/'structured-8GiB.log'
    owned_data.append(log_file)
    log_manifest = generate(log_file,8*GIB)
    small = ROOT/'many-files'; owned_data.append(small); small.mkdir()
    small_manifest = {}; block = os.urandom(64*1024) * 4
    for i in range(10000):
        folder = small/f'{i//100:03d}'; folder.mkdir(exist_ok=True)
        p = folder/f'item-{i:05d}.dat'
        data = i.to_bytes(8,'little') + block[8:]
        p.write_bytes(data)
        small_manifest[str(p.relative_to(ROOT))] = {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    print('Generated 10000 files, 2.44 GiB total',flush=True)
(ROOT/'manifests.json').write_text(json.dumps({'random':random_manifest,'structured':log_manifest,'many':small_manifest},indent=2))

results = {'environment': {'date':datetime.now().isoformat(), 'machine':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),
    'memory_bytes':int(subprocess.check_output(['sysctl','-n','hw.memsize'])),
    'os':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip(), 'engine':str(ENGINE),
    'method':'single pass, warm filesystem cache possible; other user apps running; 0.5 s sampled aggregate process-tree RSS',
    'compression_level':5,'resource_policy':'ArchiveResources; 2/4 compression threads, 2 extraction/test threads, 16 MiB balanced LZMA2 dictionary'}, 'cases':[]}

def measure(case,op,source,out,fmt):
    global active_process
    log = ROOT/f'{case}-{op}.jsonl'; samples=[]; started=time.monotonic()
    with log.open('w') as f:
        p=subprocess.Popen([str(RUNNER),op,str(ENGINE),str(source),str(out),fmt],stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        active_process = p
        while p.poll() is None:
            rows={}
            for line in subprocess.check_output(['ps','-axo','pid=,ppid=,rss=,%cpu='],text=True).splitlines():
                fields=line.split()
                if len(fields)==4:
                    pid,ppid,rss,cpu=fields; rows[int(pid)]=(int(ppid),int(rss),float(cpu))
            ids={p.pid}
            while True:
                children={pid for pid,row in rows.items() if row[0] in ids}
                if children<=ids:break
                ids|=children
            samples.append({'seconds':round(time.monotonic()-started,3),
                'rss_kib':sum(rows[x][1] for x in ids if x in rows),
                'runner_rss_kib':rows.get(p.pid,(0,0,0))[1],
                'cpu_percent':sum(rows[x][2] for x in ids if x in rows)})
            time.sleep(.5)
        code=p.wait()
        active_process = None
    elapsed=time.monotonic()-started
    (ROOT/f'{case}-{op}-samples.json').write_text(json.dumps(samples))
    events=[]
    for line in log.read_text().splitlines():
        try: events.append(json.loads(line))
        except ValueError: pass
    result={'seconds':round(next((x['seconds'] for x in reversed(events) if x.get('event')=='complete'),elapsed),3),
        'peak_tree_rss_mib':round(max((x['rss_kib'] for x in samples),default=0)/1024,2),
        'peak_runner_rss_mib':round(max((x['runner_rss_kib'] for x in samples),default=0)/1024,2),
        'peak_sample_cpu_percent':max((x['cpu_percent'] for x in samples),default=0),'exit_code':code}
    print(json.dumps({'case':case,'operation':op,**result}),flush=True)
    if code: raise RuntimeError(f'{case}/{op} failed; inspect {log}')
    return result

cases = [('random-7z-aes',random_file,random_manifest,'7z-aes')]
if args.profile == 'full':
    cases = [('random-zip64',random_file,random_manifest,'zip')] + cases + [
        ('structured-7z',log_file,log_manifest,'7z'),
        ('structured-tar-xz',log_file,log_manifest,'tar.xz'),
        ('many-files-7z',small,small_manifest,'7z')]
for name,source,manifest,fmt in cases:
    print('START '+name,flush=True)
    archive=ROOT/(name+'.'+fmt.replace('-aes','')); output=ROOT/(name+'-extracted')
    owned_data.extend([archive, output])
    record={'name':name,'input_bytes':sum(x['bytes'] for x in manifest.values()),'files':len(manifest),'format':fmt}
    record['create']=measure(name,'create',source,archive,fmt)
    record['archive_bytes']=archive.stat().st_size
    record['list']=measure(name,'list',archive,output,fmt)
    record['extract']=measure(name,'extract',archive,output,fmt)
    for relative,expected in manifest.items():
        actual=output/relative
        assert actual.stat().st_size==expected['bytes'] and digest(actual)==expected['sha256'],str(actual)
    actual_names={str(p.relative_to(output)) for p in output.rglob('*') if p.is_file()}
    assert actual_names==set(manifest),actual_names-set(manifest)
    record['sha256_verified']=True
    record['sources_retained']=all((ROOT/n).stat().st_size==v['bytes'] and digest(ROOT/n)==v['sha256'] for n,v in manifest.items())
    assert record['sources_retained']
    if fmt=='zip':
        with zipfile.ZipFile(archive) as z:
            record['zip64']=any(x.file_size>0xffffffff and x.extract_version>=45 for x in z.infolist())
            assert record['zip64']
    for operation in ['create','extract']:
        record[operation]['mib_per_second']=round(record['input_bytes']/1024**2/record[operation]['seconds'],2)
    results['cases'].append(record)
    (ROOT/'results.json').write_text(json.dumps(results,indent=2,ensure_ascii=False))
    if args.profile == 'low-memory':
        assert all(record[op]['peak_tree_rss_mib'] < 1024 for op in ['create','list','extract']), 'Task RSS exceeded 1 GiB'
    # Only delete this case's generated output after every content/source check succeeded.
    shutil.rmtree(output)
    if not args.keep_data: archive.unlink()
    print('VERIFIED '+name,flush=True)
print('ALL_CASES_PASSED '+str(ROOT/'results.json'),flush=True)
