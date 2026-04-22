// two_sum.asm
// The two-sum problem in ARMv8 AArch64 assembly.
//
// The program reads an array and a target from stdin, then prints
// any pair (i, j) whose elements sum to the target. Two solvers sit
// side by side in the same file: a direct O(n^2) nested-loop search
// and an O(n) pass backed by a 256-slot open-addressing hash set.
// Both run on the same input so you can see that they agree.
//
// Build:
//     m4 two_sum.asm > two_sum.s
//     gcc -o two_sum two_sum.s

define(fp, x29)
define(lr, x30)

define(ARRAY_MAX, 100)
define(HASH_SIZE, 256)
define(HASH_MASK, 0xFF)


// Prompts and format strings. .string gives us a null-terminated
// byte sequence, which is what printf and scanf want.
        .data
prompt_size:    .string "Enter number of elements (1 to 100): "
prompt_elem:    .string "Enter element %d: "
prompt_target:  .string "Enter target sum: "
fmt_int:        .string "%d"
msg_brute:      .string "\n-- O(n^2) brute force --\n"
msg_hash:       .string "\n-- O(n) hash set --\n"
msg_found:      .string "Pair found: arr[%d] (%d) + arr[%d] (%d) = %d\n"
msg_none:       .string "No pair sums to the target.\n"
msg_size_err:   .string "Size must be between 1 and 100.\n"


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
        stp     fp, lr, [sp, -32]!
        mov     fp, sp

        ldr     x0, =prompt_size
        bl      printf

        ldr     x0, =fmt_int
        add     x1, fp, 16
        bl      scanf

        // Validate the size before committing it to n.
        ldr     w9, [fp, 16]
        cmp     w9, 1
        b.lt    main_size_err
        cmp     w9, ARRAY_MAX
        b.gt    main_size_err

        ldr     x10, =n
        str     w9, [x10]

        ldr     x22, =arr
        mov     w19, 0                      // i

main_read_loop:
        ldr     x9, =n
        ldr     w10, [x9]
        cmp     w19, w10
        b.ge    main_read_done

        ldr     x0, =prompt_elem
        add     w1, w19, 1                  // show the user 1-based indexing
        bl      printf

        ldr     x0, =fmt_int
        add     x1, x22, w19, SXTW #2       // &arr[i]
        bl      scanf

        add     w19, w19, 1
        b       main_read_loop
main_read_done:

        ldr     x0, =prompt_target
        bl      printf

        ldr     x0, =fmt_int
        add     x1, fp, 16
        bl      scanf

        ldr     w9, [fp, 16]
        ldr     x10, =target
        str     w9, [x10]

        bl      brute_force
        bl      hash_set

        mov     w0, 0
        b       main_exit

main_size_err:
        ldr     x0, =msg_size_err
        bl      printf
        mov     w0, 1

main_exit:
        ldp     fp, lr, [sp], 32
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
        stp     fp, lr, [sp, -16]!
        mov     fp, sp

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
        ldp     fp, lr, [sp], 16
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
        stp     fp, lr, [sp, -16]!
        mov     fp, sp

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
        // No match yet. Find where val belongs and record (val, i).
        mov     w0, w23
        bl      hs_lookup

        ldr     x9, =hash_vals
        str     w23, [x9, w0, UXTW #2]
        ldr     x9, =hash_idx
        str     w22, [x9, w0, UXTW #2]
        ldr     x9, =hash_used
        mov     w10, 1
        strb    w10, [x9, w0, UXTW]

        add     w22, w22, 1
        b       hs_outer

hs_none:
        ldr     x0, =msg_none
        bl      printf

hs_done:
        ldp     fp, lr, [sp], 16
        ret
