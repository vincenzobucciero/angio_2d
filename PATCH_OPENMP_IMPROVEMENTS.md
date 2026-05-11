# OpenMP Performance Improvements - Phase 2 Patch

## Goal
Improve speedup from 1.16x to target >= 2x by addressing false sharing and improving parallelization.

## Root Causes
1. **False sharing in ADI**: Thread-specific buffers allocated linearly without padding
2. **Aggressive if() conditions**: Some loops skip parallelization (e.g., `if(My > 4)` in ADI)
3. **Schedule inefficiency**: Static schedule may leave threads idle on non-uniform workload

## Patch Strategy

### Patch 1: Cache-line alignment in ADI (src/adi.c)
- Add padding (64 bytes / 8 doubles) between thread-specific buffers
- Reduces false sharing contention
- Implementation: Allocate buffers with explicit stride (`max_threads * (nmax + CACHE_PAD)`)

### Patch 2: Reduce parallelization guards (src/adi.c, src/reaction.c)
- Remove overly conservative `if()` conditions
- Change `if(My > 4)` → always parallelize if `max_threads > 1`
- This prevents thread fork/join overhead waste on small conditions

### Patch 3: Optimize loop schedules (src/operators.c, src/reaction.c)
- Change `schedule(static)` → `schedule(auto)` in fine-grained loops
- Allows compiler/runtime to choose best strategy
- Or use dynamic with small chunk size for load balancing

## Files affected
- src/adi.c: Patch 1, 2
- src/reaction.c: Patch 2
- src/operators.c: Patch 2, 3

## Expected Impact
- Patch 1: +15-20% (eliminate false sharing)
- Patch 2: +10-15% (reduce parallelization overhead)
- Patch 3: +5-10% (better work distribution)
- Combined target: 1.16x → ~1.5-1.8x range (may reach 2x with hardware support)

## Validation
- Run phase2_test_and_benchmark.py after each patch
- Verify numerical correctness (RelL2 <= 1e-6)
- Check speedup improvement trajectory
