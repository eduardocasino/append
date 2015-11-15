# Makefile for building under Linux
#

UPX=/home/eduardo/fdos/upx/upx

INSTDIR=/root/.dosemu/drives/c/src/append/
#INSTDIR=/home/eduardo/.dosemu/drives/c/bin/

all: append.exe

install: all
	cp append.exe $(INSTDIR)
	
clean:
	rm -f append.exe append.com

append.exe: append.com
	$(UPX) --8086 -f -o $@ $<

append.com: append.asm cmdline.asm environ.asm int21.asm int2f.asm useful.mac
	nasm -dNEW_NASM -fbin append.asm -o $@

