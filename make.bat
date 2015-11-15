nasm -dNEW_NASM -fobj append.asm -o append.obj
alink append.obj
upx --8086 append.exe
