#
# Generic makefile
#

all: dasm

dasm: main.o ops.o globals.o exp.o symbols.o mne6303.o mne6502.o mne68705.o mne6811.o
	cc -o dasm main.o ops.o globals.o exp.o symbols.o mne6303.o mne6502.o mne68705.o mne6811.o

.c.o:
	cc -c -O3 -Wall $<
