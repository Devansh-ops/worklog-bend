"""Extract only SHA-256 verified locked proof tools into a persistent Unix cache."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
lock = json.loads((root / 'toolchain/bend.lock.json').read_text())
cache = Path(os.environ.get('WORKLOG_PROOF_CACHE', Path.home() / '.cache/worklog-bend-proof')).resolve()
cache.mkdir(parents=True, exist_ok=True)
for name, spec in lock['proofTools'].items():
    archive = root / '.toolchain' / name
    with archive.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != spec['sha256']:
        raise RuntimeError(f'Integrity mismatch: {name}; run node scripts/install-proof-tools.mjs')

lean = cache / f"lean-{lock['lean']}-linux" / 'bin/lean'
if not lean.exists():
    # Ubuntu supplies libzstd with the system, avoiding a pip dependency.
    lib = ctypes.CDLL('libzstd.so.1')
    class Buffer(ctypes.Structure):
        _fields_ = [('data', ctypes.c_void_p), ('size', ctypes.c_size_t), ('pos', ctypes.c_size_t)]
    lib.ZSTD_createDStream.restype = ctypes.c_void_p
    lib.ZSTD_initDStream.argtypes = [ctypes.c_void_p]
    lib.ZSTD_decompressStream.argtypes = [ctypes.c_void_p, ctypes.POINTER(Buffer), ctypes.POINTER(Buffer)]
    lib.ZSTD_decompressStream.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_freeDStream.argtypes = [ctypes.c_void_p]
    decoder = lib.ZSTD_createDStream()
    lib.ZSTD_initDStream(decoder)
    child = subprocess.Popen(['tar', '-xf', '-', '-C', str(cache)], stdin=subprocess.PIPE)
    remaining = 1
    try:
        with (root / '.toolchain/lean-linux.tar.zst').open('rb') as archive:
            while data := archive.read(1024 * 1024):
                source = ctypes.create_string_buffer(data)
                incoming = Buffer(ctypes.cast(source, ctypes.c_void_p), len(data), 0)
                while incoming.pos < incoming.size:
                    output = ctypes.create_string_buffer(1024 * 1024)
                    outgoing = Buffer(ctypes.cast(output, ctypes.c_void_p), len(output), 0)
                    remaining = lib.ZSTD_decompressStream(decoder, ctypes.byref(outgoing), ctypes.byref(incoming))
                    if lib.ZSTD_isError(remaining):
                        raise RuntimeError('Lean archive decompression failed')
                    child.stdin.write(output.raw[:outgoing.pos])
        child.stdin.close()
        if child.wait() != 0 or remaining != 0:
            raise RuntimeError('Lean archive extraction incomplete')
    finally:
        lib.ZSTD_freeDStream(decoder)
        if child.poll() is None:
            child.terminate()
            child.wait()

bun = cache / 'bun-linux-x64/bun'
if not bun.exists():
    with zipfile.ZipFile(root / '.toolchain/bun-linux.zip') as archive:
        archive.extractall(cache)
    bun.chmod(0o755)
assert subprocess.check_output([str(bun), '--version'], text=True).strip() == lock['bun']
assert f"version {lock['lean']}," in subprocess.check_output([str(lean), '--version'], text=True)
print(f'Proof tools verified in {cache}')
