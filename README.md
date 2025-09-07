# fuzzy_finder_zig

Learning to implement the Smith Waterman algorithm while leveraging SIMD. This
is my first time using Zig. This project draws a lot of inspiration from
[this](https://github.com/Saghen/frizbee).

# Benchmarks

```bash
$ poop "$PWD/zig-out/bin/fuzzy_finder_zig skov $HOME/Downloads --simd true"   "$PWD/zig-out/bin/fuzzy_finder_zig skov $HOME/Downloads --simd false"
Benchmark 1 (73 runs): /home/jamestjw/Documents/myprojects/fuzzy_finder_zig/zig-out/bin/fuzzy_finder_zig skov /home/jamestjw/Downloads --simd true
  measurement          mean ± σ            min … max           outliers         delta
  wall_time          68.4ms ± 3.19ms    64.2ms … 81.1ms          2 ( 3%)        0%
  peak_rss           4.81MB ± 96.4KB    4.49MB … 4.88MB          1 ( 1%)        0%
  cpu_cycles         29.3M  ± 1.11M     27.7M  … 33.6M           5 ( 7%)        0%
  instructions       35.0M  ± 33.4K     34.9M  … 35.0M           0 ( 0%)        0%
  cache_references   4.10M  ±  157K     3.76M  … 5.15M           3 ( 4%)        0%
  cache_misses       22.5K  ± 2.01K     18.1K  … 27.1K           0 ( 0%)        0%
  branch_misses       285K  ±  842       283K  …  287K           0 ( 0%)        0%
Benchmark 2 (14 runs): /home/jamestjw/Documents/myprojects/fuzzy_finder_zig/zig-out/bin/fuzzy_finder_zig skov /home/jamestjw/Downloads --simd false
  measurement          mean ± σ            min … max           outliers         delta
  wall_time           383ms ± 8.32ms     365ms …  396ms          0 ( 0%)        💩+459.5% ±  3.7%
  peak_rss           2.68MB ±  128KB    2.52MB … 2.92MB          0 ( 0%)        ⚡- 44.3% ±  1.2%
  cpu_cycles          142M  ± 2.65M      139M  …  148M           0 ( 0%)        💩+383.2% ±  2.9%
  instructions        332M  ± 30.7K      332M  …  332M           0 ( 0%)        💩+850.6% ±  0.1%
  cache_references   9.33M  ±  164K     9.02M  … 9.74M           1 ( 7%)        💩+127.6% ±  2.2%
  cache_misses       21.9K  ± 5.25K       15K  … 31.7K           0 ( 0%)          -  2.4% ±  7.1%
  branch_misses       899K  ± 15.0K      873K  …  924K           0 ( 0%)        💩+215.6% ±  1.2%
```
