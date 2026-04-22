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

Startup lands on a boxed welcome screen; press enter and the main
menu takes over. The menu shows your current state (array loaded,
target set, animation speed) so you always see what's staged, plus
a tip line that points newcomers at a good first path through the
options.

Every run screen has four stacked panels: the phase header with
the target on the right, the array row with coloured cells, the
hash-table panel for hash runs, a narration strip, and a live
stats line. A colour legend sits at the bottom so you never have
to guess what yellow means.

During brute force, cell `i` is yellow and cell `j` is cyan. The
narration below the array tracks each comparison:

    i=0  j=1   arr[0]+arr[1] = 2 + 7 = 9   target = 9
                                                       MATCH.

The stats line shows comparisons against the worst case:

    comparisons: 1    / 6     (max n*(n-1)/2)

During hash set, the array sits on top and the 16-slot hash table
is drawn in two rows of eight. The active probe flashes magenta, a
collision is red, a hit is green, and a fresh insert flashes
yellow. The trace panel narrates each step:

    i=0   val = arr[0] = 2   complement = target - val = 7
    look up 7.  initial slot = 7 & 0x0F = 7.
    slot 7 is empty.  complement is not in the table yet.
    record (val=2, idx=0) at slot 2, then move on.

Stats show the probe and insert counters running live.

## Presets

Six presets cover the cases worth watching:

| name       | array                 | target | what it shows                 |
| ---------- | --------------------- | ------ | ----------------------------- |
| classic    | `[2, 7, 11, 15]`      | 9      | early match                   |
| negatives  | `[-3, 4, 1, -1]`      | 0      | negatives work fine           |
| duplicates | `[5, 5]`              | 10     | two slots with the same value |
| no pair    | `[1, 2, 3, 4, 5]`     | 100    | the miss path                 |
| late match | `[3, 3, 4, 7, 1, 8]`  | 10     | table partially full          |
| collision  | `[0, 16, 32, 48, 33]` | 49     | heavy linear probing          |

The collision preset is the most fun to watch: every value hashes
to slot 0, so the insert has to probe 0 -> 1 -> 2 -> 3 before
finding room, and the later lookup walks that same chain.

## Getting started

Pick the section that matches your setup.

### Linux x86_64

You're cross-compiling the assembly and running the result under
QEMU user-mode emulation. Install the toolchain:

    sudo apt-get install m4 gcc-aarch64-linux-gnu qemu-user-static make

Build both binaries:

    make cross

Run through QEMU (the `-static` link in the Makefile means no ARM
libc needs to be on disk):

    qemu-aarch64-static ./two_sum_viz
    qemu-aarch64-static ./two_sum

On Fedora / RHEL, the package names are `m4`,
`gcc-aarch64-linux-gnu`, and `qemu-user-static`. On Arch, `m4`,
`aarch64-linux-gnu-gcc` (from AUR), and `qemu-user-static`.

### Windows (via WSL)

WSL runs a real Linux kernel on x86_64, so the Linux path above
applies. Open a WSL shell (Ubuntu is the typical pick) and:

    sudo apt-get update
    sudo apt-get install m4 gcc-aarch64-linux-gnu qemu-user-static make
    make cross
    qemu-aarch64-static ./two_sum_viz

Use **Windows Terminal**, not the legacy `cmd.exe`. Windows
Terminal handles UTF-8 (for the box drawing in the welcome splash
and the section dividers) and ANSI colour correctly out of the
box; `cmd.exe` mangles both.

If you're on Windows 10, set your WSL default to WSL2 so the
Linux kernel features used by QEMU all work:

    wsl --set-default-version 2

### Native ARM Linux (Raspberry Pi, ARM server, any aarch64 Linux box)

If your shell itself runs on aarch64, skip QEMU entirely. Install:

    sudo apt-get install m4 gcc make

Build native and run directly:

    make
    ./two_sum_viz
    ./two_sum

### macOS on Apple Silicon

macOS uses Mach-O binaries and BSD system calls, so the Linux ELF
the Makefile produces won't run natively. Run a Linux arm64
container and follow the "Native ARM Linux" steps inside it. Any
of these will do:

- [OrbStack](https://orbstack.dev) (fastest, designed for this)
- Docker Desktop with a Linux arm64 image (`docker run -it --rm ubuntu`)
- [UTM](https://mac.getutm.app) for a full VM
- Lima, colima, or Multipass for a headless VM

### Terminal requirements

At least 80 columns wide, around 26 rows tall, with UTF-8 support
and ANSI colour. Any modern terminal handles both: Windows
Terminal, iTerm2, Alacritty, Kitty, WezTerm, gnome-terminal,
Konsole, or the VS Code integrated terminal.

## Building without the Makefile

If you'd rather drive the toolchain by hand:

    m4 two_sum_viz.asm > two_sum_viz.s
    aarch64-linux-gnu-gcc -static two_sum_viz.s -o two_sum_viz

(Use plain `gcc` instead of `aarch64-linux-gnu-gcc` on a native
aarch64 host.)

## Controls

The visualizer is menu-driven. Numbers pick menu items. From the
main menu you can set the array (preset or manual), set the
target, adjust the animation delay (100-3000 ms per frame, default
700), and watch one or both algorithms run. After a run, press
enter to return to the main menu.

## Notes

- Array capped at 10 elements so the row fits in 80 columns.
- The visualizer's hash table has 16 slots (mask `0x0F`) so both
  halves fit on screen. The plain solver uses a 256-slot table
  instead, which keeps collisions rare the way a real hash set
  should. The shrunken table in the visualizer doesn't change the
  algorithm's behaviour; it just makes every slot visible at once.
- No whole-screen flicker: only cells that change get redrawn
  between frames.
- The visualizer was inspired by another project I built: <https://github.com/Abdalla-Eldoumani/dsav>

## License

MIT. Go crazy.