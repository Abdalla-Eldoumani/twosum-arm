// two_sum.asm
// The two-sum problem in ARMv8 AArch64 assembly.
//
// The program reads an array and a target from stdin, then prints
// any pair (i, j) whose elements sum to the target. Two solvers sit
// side by side in the same file: a direct O(n^2) nested-loop search
// and an O(n) pass backed by a 256-slot open-addressing hash set.
// Both run on the same input so you can compare them.
//
// Build:
//     make            native, on aarch64 hardware
//     make cross      from an x86_64 host
//
// Or by hand, the same steps the Makefile runs:
//     m4 two_sum.asm > two_sum.s
//     gcc -g two_sum.s -o two_sum

define(fp, x29)
define(lr, x30)

define(ARRAY_MAX, 100)
define(HASH_SIZE, 256)
define(HASH_MASK, 0xFF)

// Longest input token we accept, in characters. Nine digits caps a
// value at 999999999, so a sum or a complement still fits in the
// 32-bit registers both solvers use and can never wrap.
define(DIGIT_MAX, 9)


// Prompts and format strings. .string gives us a null-terminated
// byte sequence, which is what printf and scanf want.
        .data
prompt_size:    .string "Enter number of elements (1 to 100): "
prompt_elem:    .string "Enter element %d: "
prompt_target:  .string "Enter target sum: "
fmt_token:      .string "%15s"
msg_brute:      .string "\n-- O(n^2) brute force --\n"
msg_hash:       .string "\n-- O(n) hash set --\n"
msg_found:      .string "Pair found: arr[%d] (%d) + arr[%d] (%d) = %d\n"
msg_none:       .string "No pair sums to the target.\n"
msg_not_int:    .string "%s is not a whole number (digits only, optional -, 9 digits max).\n"
msg_range:      .string "%d is out of range (%d to %d).\n"
msg_eof:        .string "Input ended before the program had everything it needed.\n"


// Shared program state lives in .bss. Keeping n, target, and arr
// here means every function can reach them straight from memory
// without the caller bundling everything into argument registers.
        .bss
        .balign 4
n:          .skip 4
target:     .skip 4
arr:        .skip ARRAY_MAX * 4
hash_vals:  .skip HASH_SIZE * 4
hash_idx:   .skip HASH_SIZE * 4
hash_used:  .skip HASH_SIZE
tok_buf:    .skip 32


        .text
        .balign 4
        .global main


// In main we prompt the user for a size, validate
// it, read that many integers into arr[], read the target, and
// then hand off everything to each solver. Both solvers pull n, target, and arr
// straight out of .bss, so there is nothing to pass in.
//
// During the read loop, i sits in w19 and &arr in x22.
main:
        stp     fp, lr, [sp, -48]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]

        // The reader validates the size, so a bad one comes back as a
        // fresh prompt instead of ending the program.
        mov     w0, 1
        mov     w1, ARRAY_MAX
        ldr     x2, =prompt_size
        mov     w3, 0
        bl      read_int_range
        cbz     w1, main_eof

        ldr     x10, =n
        str     w0, [x10]

        ldr     x22, =arr
        mov     w19, 0                      // i

main_read_loop:
        ldr     x9, =n
        ldr     w10, [x9]
        cmp     w19, w10
        b.ge    main_read_done

        ldr     x2, =prompt_elem
        add     w3, w19, 1                  // show the user 1-based indexing
        bl      read_int_any
        cbz     w1, main_eof

        str     w0, [x22, w19, SXTW #2]     // arr[i]

        add     w19, w19, 1
        b       main_read_loop
main_read_done:

        ldr     x2, =prompt_target
        mov     w3, 0
        bl      read_int_any
        cbz     w1, main_eof

        ldr     x10, =target
        str     w0, [x10]

        bl      brute_force
        bl      hash_set

        mov     w0, 0
        b       main_exit

main_eof:
        ldr     x0, =msg_eof
        bl      printf
        mov     w0, 1

main_exit:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     fp, lr, [sp], 48
        ret


// read_token reads one whitespace-delimited token into tok_buf. The
// width in the format string is what keeps a long line from running
// past the end of the buffer, and reading a token rather than a
// number means junk gets consumed instead of jamming the next read.
//
// Output: w0 = 1 when a token arrived, 0 at end of input
read_token:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x0, =fmt_token
        ldr     x1, =tok_buf
        bl      scanf
        cmp     w0, 1
        b.eq    rt_ok
        mov     w0, 0
        b       rt_done
rt_ok:
        mov     w0, 1
rt_done:
        ldp     fp, lr, [sp], 16
        ret


// parse_int converts the token sitting in tok_buf to an integer. A
// leading sign is allowed, everything after it has to be a digit,
// and the digit count is capped so the value stays well inside the
// 32-bit range. Leaf function, no calls, so it needs no frame.
//
// Output: w0 = value
//         w1 = 1 when the token was a whole number, 0 otherwise
parse_int:
        ldr     x9, =tok_buf
        ldrb    w10, [x9]
        mov     w11, 0                      // 1 once we have seen a -
        cmp     w10, '-'
        b.ne    pi_plus
        mov     w11, 1
        add     x9, x9, 1
        b       pi_digits
pi_plus:
        cmp     w10, '+'
        b.ne    pi_digits
        add     x9, x9, 1

pi_digits:
        mov     w12, 0                      // value so far
        mov     w13, 0                      // digits seen
pi_loop:
        ldrb    w10, [x9]
        cbz     w10, pi_end
        cmp     w10, '0'
        b.lt    pi_bad
        cmp     w10, '9'
        b.gt    pi_bad
        sub     w10, w10, '0'
        mov     w14, 10
        mul     w12, w12, w14
        add     w12, w12, w10
        add     w13, w13, 1
        cmp     w13, DIGIT_MAX
        b.gt    pi_bad
        add     x9, x9, 1
        b       pi_loop

pi_end:
        cbz     w13, pi_bad                 // a lone sign is not a number
        cbz     w11, pi_pos
        sub     w12, wzr, w12
pi_pos:
        mov     w0, w12
        mov     w1, 1
        ret

pi_bad:
        mov     w0, 0
        mov     w1, 0
        ret


// read_int_any prints the prompt and reads one integer. Junk gets a
// line saying what was wrong with it and the prompt comes back, so a
// stray keystroke costs a retry instead of derailing the run.
//
// Input:  x2 = prompt string, w3 = prompt argument (for "%d" prompts)
// Output: w0 = value
//         w1 = 1 when the value is good, 0 when stdin ran out
read_int_any:
        stp     fp, lr, [sp, -32]!
        mov     fp, sp
        str     x2, [fp, 16]
        str     w3, [fp, 24]
ria_ask:
        ldr     x0, [fp, 16]
        ldr     w1, [fp, 24]
        bl      printf

        bl      read_token
        cbz     w0, ria_eof

        bl      parse_int
        cbnz    w1, ria_done

        ldr     x0, =msg_not_int
        ldr     x1, =tok_buf
        bl      printf
        b       ria_ask

ria_eof:
        mov     w0, 0
        mov     w1, 0

ria_done:
        ldp     fp, lr, [sp], 32
        ret


// read_int_range is read_int_any plus an inclusive range. A number
// outside the range gets its own line naming the range and the
// prompt comes back.
//
// Input:  w0 = min, w1 = max, x2 = prompt string, w3 = prompt argument
// Output: w0 = value
//         w1 = 1 when the value is good, 0 when stdin ran out
read_int_range:
        stp     fp, lr, [sp, -48]!
        mov     fp, sp
        str     w0, [fp, 16]
        str     w1, [fp, 20]
        str     x2, [fp, 24]
        str     w3, [fp, 32]
rir_try:
        ldr     x2, [fp, 24]
        ldr     w3, [fp, 32]
        bl      read_int_any
        cbz     w1, rir_done
        str     w0, [fp, 36]

        ldr     w9, [fp, 16]
        cmp     w0, w9
        b.lt    rir_out
        ldr     w9, [fp, 20]
        cmp     w0, w9
        b.gt    rir_out
        b       rir_done

rir_out:
        ldr     x0, =msg_range
        ldr     w1, [fp, 36]
        ldr     w2, [fp, 16]
        ldr     w3, [fp, 20]
        bl      printf
        b       rir_try

rir_done:
        ldp     fp, lr, [sp], 48
        ret


// brute_force walks every pair (i, j) with i < j and checks whether
// arr[i] + arr[j] equals the target. It prints the first pair it
// finds, or a "no pair" message if the loop runs out.
// Obvious, correct, and O(n^2).
//
// Register usage:
//   x19  arr base
//   w20  n
//   w21  target
//   w22  i
//   w23  j
brute_force:
        stp     fp, lr, [sp, -64]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]

        ldr     x0, =msg_brute
        bl      printf

        ldr     x19, =arr
        ldr     x9, =n
        ldr     w20, [x9]
        ldr     x9, =target
        ldr     w21, [x9]

        mov     w22, 0                      // i
bf_outer:
        sub     w9, w20, 1
        cmp     w22, w9
        b.ge    bf_none

        add     w23, w22, 1                 // j = i + 1
bf_inner:
        cmp     w23, w20
        b.ge    bf_next_i

        ldr     w9,  [x19, w22, SXTW #2]    // arr[i]
        ldr     w10, [x19, w23, SXTW #2]    // arr[j]
        add     w11, w9, w10
        cmp     w11, w21
        b.eq    bf_found

        add     w23, w23, 1
        b       bf_inner

bf_next_i:
        add     w22, w22, 1
        b       bf_outer

bf_found:
        ldr     x0, =msg_found
        mov     w1, w22
        ldr     w2, [x19, w22, SXTW #2]
        mov     w3, w23
        ldr     w4, [x19, w23, SXTW #2]
        mov     w5, w21
        bl      printf
        b       bf_done

bf_none:
        ldr     x0, =msg_none
        bl      printf

bf_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], 64
        ret


// hs_lookup searches the hash table for val with linear probing (https://en.wikipedia.org/wiki/Linear_probing) and
// returns where the search stopped. The caller looks at the flag to
// decide whether val already lives at that slot or whether the slot
// is empty and ready to accept an insertion. HASH_SIZE is more than
// twice the largest array we allow, so the probe is guaranteed to
// hit an empty slot sooner or later and we never risk an infinite
// loop.
//
// Input:  w0 = val
// Output: w0 = slot index
//         w1 = 1 if val sits at that slot, 0 if the slot is empty
hs_lookup:
        and     w2, w0, HASH_MASK           // start at val mod table size
        ldr     x3, =hash_used
        ldr     x4, =hash_vals
hs_lp_loop:
        ldrb    w5, [x3, w2, UXTW]
        cbz     w5, hs_lp_empty
        ldr     w6, [x4, w2, UXTW #2]
        cmp     w6, w0
        b.eq    hs_lp_found
        add     w2, w2, 1
        and     w2, w2, HASH_MASK           // wrap around the table
        b       hs_lp_loop

hs_lp_empty:
        mov     w0, w2
        mov     w1, 0
        ret

hs_lp_found:
        mov     w0, w2
        mov     w1, 1
        ret


// hash_set is the linear-time counterpart. For each arr[i] we ask
// whether target - arr[i] has turned up already; if yes we've found
// a pair, and if not we remember (arr[i], i) so later indices can
// find it. Every element is touched once and every hash op is O(1)
// on average, which gives O(n) overall.
//
// Register usage:
//   x19  arr base
//   w20  n
//   w21  target
//   w22  i
//   w23  val = arr[i]
//   w24  complement = target - val
hash_set:
        stp     fp, lr, [sp, -64]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]

        ldr     x0, =msg_hash
        bl      printf

        // Zero the occupancy map. If hash_set runs twice in the same
        // program we don't want stale entries carrying over.
        ldr     x9, =hash_used
        mov     w10, 0
hs_reset:
        strb    wzr, [x9, w10, UXTW]
        add     w10, w10, 1
        cmp     w10, HASH_SIZE
        b.lt    hs_reset

        ldr     x19, =arr
        ldr     x9, =n
        ldr     w20, [x9]
        ldr     x9, =target
        ldr     w21, [x9]

        mov     w22, 0                      // i
hs_outer:
        cmp     w22, w20
        b.ge    hs_none

        ldr     w23, [x19, w22, SXTW #2]    // val
        sub     w24, w21, w23               // complement

        // Has the complement been seen already?
        mov     w0, w24
        bl      hs_lookup
        cbz     w1, hs_insert_val

        // Yes: w0 holds the slot where it lives. Read back the
        // original index and print both sides of the pair.
        ldr     x9, =hash_idx
        ldr     w10, [x9, w0, UXTW #2]

        ldr     x0, =msg_found
        mov     w1, w10                     // earlier index j
        mov     w2, w24                     // arr[j] = complement
        mov     w3, w22                     // current index i
        mov     w4, w23                     // arr[i] = val
        mov     w5, w21
        bl      printf
        b       hs_done

hs_insert_val:
        // No match yet. Find where val belongs and record (val, i) --
        // unless the value is already in the table, in which case the
        // index that is already there is the earlier one and it stays.
        // First occurrence wins, which is what the visualizer shows
        // too, so a repeated value names the same index in both.
        mov     w0, w23
        bl      hs_lookup
        cbnz    w1, hs_next_i

        ldr     x9, =hash_vals
        str     w23, [x9, w0, UXTW #2]
        ldr     x9, =hash_idx
        str     w22, [x9, w0, UXTW #2]
        ldr     x9, =hash_used
        mov     w10, 1
        strb    w10, [x9, w0, UXTW]

hs_next_i:
        add     w22, w22, 1
        b       hs_outer

hs_none:
        ldr     x0, =msg_none
        bl      printf

hs_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], 64
        ret
