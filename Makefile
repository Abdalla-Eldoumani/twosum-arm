# two_sum and two_sum_viz
#
# Native build on ARM hardware:
#     make
# Cross-compile from an x86 host:
#     make cross
# Run:
#     ./two_sum         (plain solver)
#     ./two_sum_viz     (animated visualizer)

CC = gcc
CROSS_CC = aarch64-linux-gnu-gcc
M4 = m4
CFLAGS = -g

.PHONY: all cross clean

all: two_sum two_sum_viz

two_sum: two_sum.asm
	$(M4) $< > two_sum.s
	$(CC) $(CFLAGS) two_sum.s -o $@

two_sum_viz: two_sum_viz.asm
	$(M4) $< > two_sum_viz.s
	$(CC) $(CFLAGS) two_sum_viz.s -o $@

cross:
	$(M4) two_sum.asm > two_sum.s
	$(M4) two_sum_viz.asm > two_sum_viz.s
	$(CROSS_CC) -static two_sum.s -o two_sum
	$(CROSS_CC) -static two_sum_viz.s -o two_sum_viz

clean:
	rm -f two_sum.s two_sum_viz.s two_sum two_sum_viz