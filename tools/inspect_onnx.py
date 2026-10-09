from pathlib import Path

def fields(data):
    i = 0
    while i < len(data):
        key = 0; shift = 0
        while True:
            b = data[i]; i += 1; key |= (b & 127) << shift
            if b < 128: break
            shift += 7
        no, wire = key >> 3, key & 7
        if wire == 0:
            v = 0; shift = 0
            while True:
                b = data[i]; i += 1; v |= (b & 127) << shift
                if b < 128: break
                shift += 7
        elif wire == 2:
            n = 0; shift = 0
            while True:
                b = data[i]; i += 1; n |= (b & 127) << shift
                if b < 128: break
                shift += 7
            v = data[i:i+n]; i += n
        elif wire == 5:
            v = data[i:i+4]; i += 4
        elif wire == 1:
            v = data[i:i+8]; i += 8
        else:
            raise ValueError((no, wire, i))
        yield no, v

def one(data, number):
    return next((v for n,v in fields(data) if n == number), None)

def decode_value_info(data):
    name = one(data, 1).decode()
    tensor = one(one(data, 2), 1)
    elem = one(tensor, 1)
    shape = one(tensor, 2)
    dims = []
    for n, v in fields(shape):
        if n == 1: dims.append(one(v, 1) or one(v, 2))
    return name, elem, dims

model = Path('FileApp/mutco_yolo11s_best.onnx').read_bytes()
graph = one(model, 7)
for no, value in fields(graph):
    if no in (11, 12):
        print('input' if no == 11 else 'output', decode_value_info(value))
for no, value in fields(model):
    if no == 14:
        key = one(value, 1)
        if key in (b'names', b'task', b'imgsz'):
            print(key.decode(), one(value, 2)[:2000])
