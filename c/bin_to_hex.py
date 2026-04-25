# bin_to_hex.py - converts raw binary to word-per-line hex for $readmemh
import sys
with open(sys.argv[1], 'rb') as f:
    data = f.read()
# pad to word boundary
while len(data) % 4:
    data += b'\x00'
for i in range(0, len(data), 4):
    word = data[i:i+4]
    # little-endian word
    print(f'{int.from_bytes(word, "little"):08x}')
