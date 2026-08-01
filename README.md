# two-sum

One ARMv8 AArch64 assembly program for the two-sum problem, with two
faces: an animated terminal visualizer that traces how each algorithm
finds its pair, and a console mode that asks the same questions and
just prints the answers.

Run the visualizer in a browser, no toolchain:
<https://aarch64-playground.vercel.app/playground?example=two-sum>

## Why

I was scrolling reels one night, someone was solving two-sum in
Python, and the top comment was "now do it in assembly." So here
it is. That's it. No deeper story. This is nothing short of a toy "project".

## What's in store

`two_sum_viz.asm` is the whole thing. Two algorithms sit side by side
in it and both run on the same input so you can compare them:

- A direct O(n^2) nested-loop search.
- An O(n) pass using a 16-slot open-addressing hash set.

Started with no arguments, it takes over the terminal: pick a preset
or type in your own array, then watch i and j crawl across the cells,
or watch the hash slots light up as values get inserted and looked up.

Started with `console` as its argument, it asks the same questions one
line at a time, runs both algorithms on the answers, and prints a
labelled line for each:

    $ ./two_sum_viz console
    two-sum -- brute force O(n^2) and hash set O(n)
    type an array and a target; each solver prints the pair it finds.
    how many elements (1 to 10): 4
    arr[0] = 2
    arr[1] = 7
    arr[2] = 11
    arr[3] = 15
    target sum (-9999 to 9999): 9
    brute force:  arr[0] (2) + arr[1] (7) = 9   comparisons: 1
    hash set:     arr[0] (2) + arr[1] (7) = 9   probes: 3
    brute force checks every pair; the hash set trades a table for the loop.

Same reader, same bounds, same complaints as the visualizer. Not one
escape byte goes out on that path, so it pipes and logs cleanly.

## What the visualizer shows

Startup lands on a boxed welcome screen; press enter and the home
screen takes over. Every screen wears the same frame: the app mark and
the screen's name on the title bar, a rule under it and another above
the bottom, a standing line that says what the screen expects next,
and a message row where a rejected answer lands. Those shapes and that
palette come from dsav, the visualizer this one grew out of, so the
two read as one family.

Home lists what you can set and what you can run, one line of context
each, and a three-line readout of what is staged: array, target, and
animation speed.

A run screen stacks its panels inside the same frame: the phase line
with the target on the right and a complexity card under it, the array
row with coloured cells, the hash-table panel on hash runs, and a
narration strip. The live counters sit on the standing line and the
colour key on the message row, so the two things you keep glancing at
are always in the same place.

During brute force, cell `i` carries the "in hand" fill and cell `j`
the one it is being compared against. The narration below the array
tracks each comparison:

    i=0  j=1   arr[0]+arr[1] = 2 + 7 = 9   target = 9
                                                       MATCH.

The counters show comparisons against the worst case:

    comparisons 1   of 6    worst case n(n-1)/2

During hash set, the array sits on top and the 16-slot hash table is
drawn in two rows of eight. The slot being probed is warm, a collision
is red, a hit is green, and a fresh insert flashes. Looking a value up
and finding room for it both walk the table, and both get drawn. The
trace panel narrates each step:

    i=0   val = arr[0] = 2   complement = target - val = 7
    look up 7.  initial slot = 7 & 0x0F = 7.
    slot 7 is empty.  complement is not in the table yet.
    insert 2.  initial slot = 2 & 0x0F = 2.
    record (val=2, idx=0) at slot 2, then move on.

The counters show the probes and inserts running live.

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

Build:

    make cross

Run through QEMU (the `-static` link in the Makefile means no ARM
libc needs to be on disk):

    qemu-aarch64-static ./two_sum_viz
    qemu-aarch64-static ./two_sum_viz console

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
Terminal handles UTF-8 (for the frame, the box drawing, and the
panel rules) and 256-colour ANSI correctly out of the box;
`cmd.exe` mangles both.

If you're on Windows 10, set your WSL default to WSL2 so the
Linux kernel features used by QEMU all work:

    wsl --set-default-version 2

### Native ARM Linux (Raspberry Pi, ARM server, any aarch64 Linux box)

If your shell itself runs on aarch64, skip QEMU entirely. Install:

    sudo apt-get install m4 gcc make

Build native and run directly:

    make
    ./two_sum_viz
    ./two_sum_viz console

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

At least 80 columns wide and 25 rows tall, with UTF-8 support and
256-colour ANSI. Any modern terminal handles both: Windows Terminal,
iTerm2, Alacritty, Kitty, WezTerm, gnome-terminal, Konsole, or the VS
Code integrated terminal. Console mode needs none of that.

## Building without the Makefile

If you'd rather drive the toolchain by hand:

    m4 two_sum_viz.asm > two_sum_viz.s
    aarch64-linux-gnu-gcc -static two_sum_viz.s -o two_sum_viz

(Use plain `gcc` instead of `aarch64-linux-gnu-gcc` on a native
aarch64 host.)

## Controls

The visualizer is menu-driven. Numbers pick entries. From home you can
set the array (preset or manual), set the target, adjust the animation
delay (100-3000 ms per frame, default 700), and watch one or both
algorithms run. After a run, press enter to come back. `0` quits.

Anything that isn't a number the prompt asked for gets a line on the
message row saying so, and the prompt comes back where it was.

Console mode has no controls: it asks, you answer, it prints.

## Notes

- Array capped at 10 elements so the row fits in 80 columns.
  Values run from -99 to 999 for the same reason: the cells are
  five columns wide. Targets run from -9999 to 9999. Console mode
  holds to the same bounds, because it is the same reader.
- Both algorithms report the *first* index of a repeated value, so
  `[3, 3, 4, 7, 1, 8]` with target 10 gives `arr[0]` and `arr[3]`
  in the animation and on the console line. Where an input has more
  than one valid pair they can still name different ones: brute force
  returns the first pair in reading order, the hash set returns the
  complement it happens to have stored.
- The hash table has 16 slots (mask `0x0F`) so both halves fit on
  screen. Console mode uses the same table rather than a bigger one,
  so the two faces cannot drift apart.
- No whole-screen flicker: frames repaint in place, never a
  clear-screen between frames.
- The visual language is lifted from another project I built:
  <https://github.com/Abdalla-Eldoumani/dsav>

## License

MIT. Go crazy.
