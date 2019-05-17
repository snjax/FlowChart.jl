# Description

Flowchart.jl is optimized compiler for [circom](https://github.com/iden3/circom), potentially allowing to build circuits with millions of constraints and gates and fully compatible with [circomlib](https://github.com/iden3/circomlib).

## TODO

- [x] Base data structures developed (final field, constraints, etc)
- [x] Base tools for constraint optimizations (same as in original circom, but with several algorithmic optimizations)
- [ ] Ast compiler reverse engineering
- [ ] Witness codegen for julia language
- [ ] Unit tests
- [ ] Advanced constraints optimizer (for quadratic part of constraints)
- [ ] Witness codegen for C (for embedding into C, C++, Go and Rust)