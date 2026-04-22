# two-sum

Two ARMv8 AArch64 assembly programs for the two-sum problem: a
plain command-line solver (`two_sum.asm`) and an animated terminal
visualizer (`two_sum_viz.asm`) that traces how the two algorithms find their pair.

## Why

I was scrolling reels one night, someone was solving two-sum in
Python, and the top comment was "now do it in assembly." So here
it is. That's it. No deeper story. This is nothing short of a toy "project".

## What's in store

`two_sum.asm` is the base solver. It reads an array and a target
from stdin, then prints any pair (i, j) whose elements sum to the
target. Two algorithms sit side by side in the same file and both
run on the same input so you can see they agree:

- A direct O(n^2) nested-loop search.
- An O(n) pass using a 256-slot open-addressing hash set.

`two_sum_viz.asm` is the same two algorithms wired up with ANSI
colours and step-by-step narration in the terminal. You pick a
preset or type in your own array, then watch i and j crawl across
the cells, or watch the hash slots light up as values get inserted
and looked up.

## What the visualizer shows

During brute force, cell `i` is yellow, cell `j` is cyan, and the
narration below the array tracks each comparison:

    i=0  j=1   arr[0]+arr[1] = 2 + 7 = 9   target = 9 MATCH.

During hash set, the array sits on top and the 16-slot hash table
is drawn in two rows of eight. The active probe flashes magenta, a
collision is red, a hit is green, and a fresh insert flashes
yellow. The trace panel narrates each step:

    i=0   val = arr[0] = 2   complement = target - val = 7
    look up 7.  initial slot = 7 & 0x0F = 7.
    slot 7 is empty.  complement is not in the table yet.
    record (val=2, idx=0) at slot 2, then move on.

Both runs also show live counters: comparisons for brute force,
probes and inserts for the hash run.

## Presets

Six presets cover the cases worth watching:

| name       | array                 | target | what it shows                |
| ---------- | --------------------- | ------ | ---------------------------- |
| classic    | `[2, 7, 11, 15]`      | 9      | early match                  |
| negatives  | `[-3, 4, 1, -1]`      | 0      | negatives work fine          |
| duplicates | `[5, 5]`              | 10     | two slots with the same value |
| no pair    | `[1, 2, 3, 4, 5]`     | 100    | the miss path                |
| late match | `[3, 3, 4, 7, 1, 8]`  | 10     | table partially full         |
| collision  | `[0, 16, 32, 48, 33]` | 49     | heavy linear probing         |

The collision preset is the most fun to watch: every value hashes
to slot 0, so the insert has to probe 0 -> 1 -> 2 -> 3 before
finding room, and the later lookup walks that same chain.

## Build

On ARM hardware:

    make

On an x86 host with the cross toolchain installed:

    make cross

Then run:

    ./two_sum       # plain solver
    ./two_sum_viz   # visualizer

Or without the Makefile:

    m4 two_sum_viz.asm > two_sum_viz.s
    gcc -o two_sum_viz two_sum_viz.s

## Controls

The visualizer is menu-driven. Numbers pick menu items. From the
main menu you can set the array (preset or manual), set the
target, adjust the animation delay (100-3000 ms per frame, default
700), and then watch one or both algorithms run. After a run,
press enter to return to the main menu.

## Notes

- Array capped at 10 elements so the row fits in 80 columns.
- Hash table has 16 slots (mask `0x0F`) so both halves fit on
  screen. The plain solver in `two_sum.asm` uses a 256-slot table
  for the same reason every real hash set uses a big load-factor
  headroom: fewer collisions. The behaviour is identical; the
  shrunken table in the visualizer just makes everything visible.
- Needs a terminal at least 80 columns wide and around 26 rows
  tall, with ANSI colour support.
- No whole-screen flicker: only cells that change get redrawn
  between frames.
- The visualizer section of this project was inspired by another project that I built: https://github.com/Abdalla-Eldoumani/dsav

## License

MIT. Go crazy.