.macro PUSH reg
    str \reg, [sp, #-16]!
.endmacro

.macro POP reg
    ldr \reg, [sp], #16
.endmacro

.macro INC reg, val=1
    add \reg, \reg, #\val
.endmacro

.macro DEC reg, val=1
    sub \reg, \reg, #\val
.endmacro 

.macro SWAP reg1, reg2
    PUSH \reg1
    mov \reg1, \reg2
    POP \reg2
.endmacro

// To be called as very first instruction for any func which calls other funcs
.macro ENTER
    PUSH x30
.endmacro

// To be called as very last instruction for any func which calls other funcs; use instead of ret.
.macro LEAVE
    POP x30
    ret
.endmacro

.macro BREAK
    brk #0 // stop here; the debugger catches it, a plain run ends with code 133
.endmacro

// Erases existing flags!
.macro ASSERT_EQ a, b
    cmp \a, \b
    b.eq assert_ok_\@
    brk #0
assert_ok_\@: // do nothing
.endmacro
