# Makefile for building under Linux
#
# Yes! you can cross-build under Linux. You just need the Linux versions of
# nasm and (optionally) upx and this patch to compile alink under Linux:
# http://perso.wanadoo.es/samelborp/misc/alinklnx.zip
#

ALINK=/home/eduardo/fdos/alink/alink
UPX=/home/eduardo/fdos/upx/upx

INSTDIR=/root/.dosemu/drives/c/src/append/
#INSTDIR=/home/eduardo/.dosemu/drives/c/bin/

all: append.exe

install:
	cp append.exe $(INSTDIR)
	
clean:
	rm -f append.exe append.obj

append.exe: append.obj
	$(ALINK) -oEXE -o $@ $<
	$(UPX) --8086 $@

append.obj: append.asm cmdline.asm environ.asm int21.asm int2f.asm useful.mac
	nasm -dNEW_NASM -fobj append.asm -o $@

