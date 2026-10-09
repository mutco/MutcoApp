import re, zlib, sys
data = open(sys.argv[1], 'rb').read()
for m in re.finditer(rb'(\d+) 0 obj(.*?)endobj', data, re.S):
    body = m.group(2)
    p = re.search(rb'stream\r?\n(.*?)\r?\nendstream', body, re.S)
    if not p: continue
    stream = p.group(1)
    if b'FlateDecode' in body[:p.start()]:
        try: stream = zlib.decompress(stream)
        except zlib.error: continue
    if b'BT' not in stream: continue
    vals = re.findall(rb'\((?:\\.|[^\\)])*\)\s*Tj|\[(.*?)\]\s*TJ', stream, re.S)
    print('OBJECT',m.group(1).decode())
    for v in re.findall(rb'\((?:\\.|[^\\)])*\)', stream):
        try: print(v[1:-1].decode('latin1'),end=' ')
        except: pass
    print()
