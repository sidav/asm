// This is an entrypoint label descriptor.
// If built with clang, it should be called _main on Mac or main on Linux.
// If built with as+ld, it should be called _start
.global _main
.align 2 // Pad the address of the next line to a multiple of 4 bytes. Padding is strictly required by ARM architecture, but not strictly needed in code itself (the code may be padded already). But it's recommended still.


// This is MacOS entrypoint! May not compile on Linux.
_main:
    ret // return. The contents of x0 (its last byte) is the return code.

// Entrypoint and exit if building with as+ld (works on Linux only):
// .global _start
// .align 2
// _start:
//  (your code goes here)
//  mov x0, #0   // exit code
//  mov x8, #93  // syscall number: exit
//  svc #0       // no ret here: nobody called _start, there is no caller to return to

registers:
    // ARM64 has 31 8-byte general purpose registers, called x0...x30.
    // w0...w30 are lower 4-byte parts of the corresponding x0..x30.
    // Registers x0-x7 can be used for anything and usually are arguments for calls. Also they are expected to be clobbered (changed)
    // Registers x0-x15 are generally safe for change (clobber)
    // Registers x16 and x17 are for service purposes (x16 holds syscall number on Mac, for example)
    // Register x18 is reserved on Mac; don't touch it at all there.
    // Registers x19-x28 are long-living; the program as a whole is expected not to clobber them (but any subroutine may do this as long as it sets them back before ret)
    // Register x29 is frame pointer; don't touch it on Mac
    // x30 is return address. Can be written with bl, and read by ret
    // Special registers:
    // pc is not available directly; points to current instruction; increases by 4 each instruction
    // sp is stack pointer, on arm it MUST be a multiple of 16 at all times
    // xzr is always-zero register, safe to write into, but writing won't change it
    // Flags (N, Z, C, V) live in special nzcv register; read directly only by mrs instruction, indirectly by conditional branching instructions.

    mov x0, #1 // put literal 1 (decimal) to register x0
    mov x1, #0x10 // put HEX 16 to register x1
    mov x2, #0b100 // Put binary 4 to register x2

    mov w1, #1 // Put 1 to lower 4 bytes of register x1. This will zero the upper 4 bytes!

    mrs x1, nzcv // Move to Register from System register. In this example, put nzcv to x1
    msr nzcv, x1 // vice versa.



arithmetic:
    add x0, x0, x1 // x0 = x0 + x1
    sub x0, x0, x1 // x0 = x0 - x1
    mul x0, x0, x1 // x0 = x0 * x1
    udiv x0, x1, x2 // x0 = x1 / x2, x1 and x2 are treated as unsigned
    sdiv x0, x1, x2 // x0 = x1 / x2, x1 and x2 are treated as signed
    lsl x0, x0, #1 // x0 = x0 << 1
    lsr x0, x0, #1 // x0 = x0 >> 1

    adds x0, x0, x1 // x0 = x0 + x1 AND SET FLAGS to nzcv.
    // Also, flags can be set by subs, cmp, cmn and tst
    cmp x0, x1 // compare x0 with x1, set flags. x0 and x1 are unchanged.
    cmp x0, #2 // ditto, but compare with literal
    // Some instructions are aliases of arithmetic with xzr register to throw the result out.
    // cmp a, b = subs xzr, a, b // CoMPare
    // cmn a, b = adds xzr, a, b // CoMpare Negative
    // tst a, b = ands xzr, a, b // TeST bit mask

memory:
    sub sp, sp, #16 // "Allocate" 16 bytes on stack (stack grows down, so sp should DECREASE)
    str x0, [sp] // Save contents of register x0 at address contained in sp. Beware of segfaults! Take memory first.
    ldr x1, [sp] // Load contents at [sp] address to x1
    add sp, sp, #16 // Deallocate the 16 bytes from stack

    // Shorter, single instruction versions of the above:
    str x0, [sp, #-16]! // Push: sp -= 16, save x0 to the new address in sp
    ldr x0, [sp], #16 // pop: load [sp] to x0, then sp += 16

    // str and ldr do change sp in two cases: "!" after the brackets (pre-index) 
    // or an offset after the brackets (post-index).
    // With the offset inside the brackets and no "!", sp is not changed:
    str x0, [sp, #-16] // save what's in x0 to mem address [sp-16], but don't change sp itself. Beware: don't write to unallocated memory! Everything below sp can and may be overwritten by OS at any moment. This instruction is only an example.
    // Offsets may be registers only in specific case:
    ldr x0, [sp, x1]     // works: address = sp + x1, neither sp nor x1 changes
    // ldr x0, [sp, x1]!    // error: no pre-index with a register
    // ldr x0, [sp], x1     // error: no post-index with a register

    // ALWAYS deallocate anything you've put on the stack before calling ret!

flow:
    // A label is a name for an address; it generates no code.
    b flow_skip // Branch (unconditional jump to label)
    mov x0, #123 // this line won't be executed, it's skipped by b above
flow_skip:
    // Flags N, Z, C, V are set only by instructions with the "s" suffix (adds, subs, ands) and by cmp, cmn, tst.
    subs x1, x1, #1 // x1 -= 1, and set flags
    cmp x0, x1 // flags = x0 - x1, result thrown away (alias for subs xzr, x0, x1)

    // The CPU does not know whether a register is signed; YOU choose by the condition.
    // Conditional jumps read the flags left by the previous cmp / subs / adds / ands.
    // After "cmp a, b" (flags = a - b), read each condition as "jump if a ? b".
    //
    // Both signed and unsigned:
    // b.eq label // equal:      jump if a == b               (Z = 1)
    // b.ne label // not equal:  jump if a != b               (Z = 0)
    //
    // Signed (registers treated as two's complement numbers):
    // b.lt label // less than:           jump if a <  b      (N != V)
    // b.le label // less or equal:       jump if a <= b      (Z = 1 or N != V)
    // b.gt label // greater than:        jump if a >  b      (Z = 0 and N == V)
    // b.ge label // greater or equal:    jump if a >= b      (N == V)
    //
    // Unsigned (registers treated as plain non-negative numbers):
    // b.lo label // lower:               jump if a <  b      (C = 0)  alias: b.cc
    // b.ls label // lower or same:       jump if a <= b      (C = 0 or Z = 1)
    // b.hi label // higher:              jump if a >  b      (C = 1 and Z = 0)
    // b.hs label // higher or same:      jump if a >= b      (C = 1)  alias: b.cs
    //
    // Why two families: the flags are the same, the interpretation differs.
    // Example: a = -1 (0xFFFFFFFFFFFFFFFF), b = 1
    //   signed:   -1 < 1, so b.lt jumps and b.gt does not
    //   unsigned: 0xFFFF...FFFF > 1, so b.hi jumps and b.lo does not
    // Pick the family by the TYPE of your data: counts, sizes, addresses, indexes -> unsigned;
    // anything that can be negative -> signed.
    //
    // Reminder: C after a subtraction means "no borrow occurred" (a >= b unsigned), not "carry".
    // Reminder: eq / ne are the same for signed and unsigned; only the order tests differ.

    // Compare-and-branch against zero; flags are NOT touched:
    cbz x0, flow_skip // jump if x0 == 0
    cbnz x0, flow_skip // jump if x0 != 0

    // Test-bit-and-branch; bit 0 is the rightmost:
    tbz x0, #0, flow_skip // jump if bit 0 is 0 (even number)
    tbnz x0, #0, flow_skip // jump if bit 0 is 1 (odd number)

    // Loop template: counter in x1, counts down to zero.
    mov x1, #5
flow_loop:
    sub x1, x1, #1
    cbnz x1, flow_loop // repeat while x1 != 0

    // "if without else": invert the condition and jump over the body.
    cmp x0, x1
    b.le flow_endif // if NOT (x0 > x1), skip the body
    mov x0, x1 // body: runs only when x0 > x1
flow_endif:

functions:
    // bl label: jump and save the return address in x30. ret: jump to x30.
    // A function that calls another one MUST save x30 (bl overwrites it):
    //     str x30, [sp, #-16]!   at the start
    //     ldr x30, [sp], #16     right before ret
    // A leaf function (one which calls nothing) needs nothing: ret is enough.
    // Arguments: x0, x1, ...; result: x0; x0-x15 may be clobbered by the callee.

// MACROS
// A macro is a template: assembler replaces each use with its body BEFORE assembling.
// It generates no code by itself; only the places where it's used do generate code.
// Parameters are substituted with a backslash: \reg, \value.

.macro PUSH reg
    str \reg, [sp, #-16]! // sp -= 16, then store the register at the new sp
.endmacro

.macro POP reg
    ldr \reg, [sp], #16 // load the register from sp, then sp += 16
.endmacro

.macro LOAD_LITERAL reg, value
    mov \reg, #\value // two parameters; note "#\value" gives a literal like #42
.endmacro

macro_usage:
    PUSH x0
    POP x0
    LOAD_LITERAL x0, 5 // Note: not #5, because the macro does have # sign already
