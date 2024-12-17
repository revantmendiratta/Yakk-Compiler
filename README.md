# SimpleC Compiler

## Overview

The **SimpleC Compiler** is a lightweight compiler for a subset of the C programming language, designed to generate **x86-64 assembly code**. It supports fundamental data types, arithmetic operations, control flow structures, and pointer-based operations, making it suitable for learning compiler design principles and assembly generation.

---

## Features

### Supported Data Types
- `long`
- `long*`
- `char*`
- `char**`
- `void`

### Operators
- **Arithmetic**: `+`, `-`, `*`, `/`, `%`
- **Logical**: `&&`, `||` (short-circuit supported)
- **Equality**: `==`, `!=`
- **Relational**: `<`, `<=`, `>`, `>=`

### Control Structures
- `if`, `else`
- `while`, `do-while`
- `for`

### Functionality
- Function definitions with arguments and return values
- Array indexing and pointer dereferencing
- Local and global variable management

---

## Prerequisites

To build and run the compiler, ensure you have the following tools installed:

- **Lex/Flex**: For lexical analysis
- **Yacc/Bison**: For grammar parsing
- **GCC**: For assembling and linking the generated assembly code

---

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repo_url>
   cd simplec-compiler
   ```
2. **Build the compiler**:
   ```bash
   make
   ```

---

## Usage

### Compile a SimpleC Program
To compile a SimpleC source file:

```bash
./scc <source_file.c>
```
This generates an assembly file `source_file.s`.

### Assemble and Run the Code
After generating the assembly file, assemble it with GCC and run the output:

```bash
gcc -o output source_file.s
./output
```

---

## Example Programs

### Program 1: Hello World

```c
void main() {
    printf("Hello, world...\n");
}
```

**Steps:**

1. Compile:
   ```bash
   ./scc hello.c
   ```
2. Assemble and run:
   ```bash
   gcc -o hello hello.s
   ./hello
   ```

### Program 2: Factorial Function

```c
long fact(long n) {
    if (n == 0) return 1;
    return n * fact(n - 1);
}

void main() {
    printf("Factorial of 5 = %d\n", fact(5));
}
```

### Program 3: Summing an Array

```c
long sum(long n, long* a) {
    long i, s = 0;
    for (i = 0; i < n; i = i + 1) {
        s = s + a[i];
    }
    return s;
}

long main() {
    long* a;
    a = malloc(5 * 8);
    a[0] = 4; a[1] = 3; a[2] = 1; a[3] = 7; a[4] = 6;

    long s = sum(5, a);
    printf("sum = %d\n", s);
}
```

---

## Project Structure

- `simple.y`: The Yacc grammar and actions for code generation.
- `lexer`: Lexical analyzer (using Flex or Lex).
- `Makefile`: Build automation for the compiler.
- `tests/`: Example SimpleC programs to verify functionality.

---

## Testing

Run all included test cases to verify correctness:

```bash
cd tests
./testall
```

---

## Advanced Features (Optional)

- **Short-Circuit Logical Operators**: Optimized handling of `&&` and `||`.
- **Stack Usage**: Dynamic use of execution stack when registers are insufficient.
- **Performance Optimization**: Improved assembly for computationally intensive tasks.

---

## Contributing

Contributions are welcome! If you'd like to enhance the compiler or add new features, feel free to fork the repository and submit a pull request.
