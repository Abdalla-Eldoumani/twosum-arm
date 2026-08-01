# two_sum_viz
#
# Native build on ARM hardware:
#     make
# Cross-compile from an x86 host:
#     make cross
# Run:
#     make run                 the visualizer
#     ./two_sum_viz console    the same solvers as plain text
# A cross build is an aarch64 binary, so run it through QEMU:
#     qemu-aarch64-static ./two_sum_viz

CC = gcc
CROSS_CC = aarch64-linux-gnu-gcc
M4 = m4
CFLAGS = -g

.PHONY: all cross run clean

all: two_sum_viz

two_sum_viz: two_sum_viz.asm
	$(M4) $< > two_sum_viz.s
	$(CC) $(CFLAGS) two_sum_viz.s -o $@

cross:
	$(M4) two_sum_viz.asm > two_sum_viz.s
	$(CROSS_CC) -static two_sum_viz.s -o two_sum_viz

run: two_sum_viz
	./two_sum_viz

clean:
	rm -f two_sum_viz.s two_sum_viz
