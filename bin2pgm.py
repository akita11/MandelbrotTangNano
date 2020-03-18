# save binary data including sending data and received data
# note: for Python3, with -u option (blocked stdout buffer)

import sys;

# read headers
X = int.from_bytes(sys.stdin.buffer.read(1), byteorder='big')
Y = int.from_bytes(sys.stdin.buffer.read(1), byteorder='big')
for i in range(8):
    d = sys.stdin.buffer.read(1)

#print('P6',X,Y,'\n255')
sys.stdout.write('P6\n')
sys.stdout.write(str(Y))
sys.stdout.write(' ')
sys.stdout.write(str(X))
sys.stdout.write('\n255\n')
for y in range(Y):
    for x in range(X):
        d = int.from_bytes(sys.stdin.buffer.read(1), byteorder='big')
        if (d == 0x64):
            pix = 0x000000
        else:
            p = d % 7
            if p == 0:
                pix = 0x0000ff
            elif p == 1:
                pix = 0x00ff00
            elif p == 2:
                pix = 0x00ffff
            elif p == 3:
                pix = 0xff0000
            elif p == 4:
                pix = 0xff00ff
            elif p == 5:
                pix = 0xffff00
            elif p == 6:
                pix = 0xffffff
        sys.stdout.buffer.write(pix.to_bytes(3, byteorder='big'))
