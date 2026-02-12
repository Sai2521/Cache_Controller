# Cache_Controller
# 🧠 Verilog Cache Controller

A simplified 4-way set-associative cache controller designed using **Verilog** and simulated via **GTKWave**. Created as part of the *Computer Architecture and Design* course at Politehnica University of Timișoara.

---

## 🔧 Features

- 4-way set-associative cache (32 KB)
- **LRU** replacement policy
- **Write-back** & **Write-allocate** strategy
- Hit/miss detection
- Finite State Machine (FSM) control logic

---

## ⚙️ Specs

| Parameter        | Value       |
|------------------|-------------|
| Block Size       | 64 Bytes    |
| Word Size        | 4 Bytes     |
| Sets             | 128         |
| Replacement      | LRU         |
| Write Policy     | WB + WA     |

---

## 🧪 Testing

We designed 6 test cases covering:
- Read/Write hits and misses
- Dirty block eviction
- Allocation after eviction
- Full FSM coverage

Simulation was done using **GTKWave**, and logic correctness was verified via waveform analysis.

---

## 🛠 Tools Used

- Verilog (VS Code)
- GTKWave
- Git

---
