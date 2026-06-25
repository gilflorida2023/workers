package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"

	"github.com/primeforge/shared/sieve"
)

type WorkerConfig struct {
	Wheel      int  `json:"wheel"`
	Parallel   bool `json:"parallel"`
	SegmentKB  int  `json:"segment_kb"`
}

func main() {
	limit := flag.Uint64("limit", 1000000, "upper bound for prime search")
	showHash := flag.Bool("hash", false, "output KAT hash to stdout")
	showConfig := flag.Bool("config", false, "output worker config JSON to stderr")
	verifyKAT := flag.Bool("verify", false, "self-verify KAT hash via kat_verify tool")
	flag.Parse()

	debug.SetGCPercent(-1)
	runtime.GOMAXPROCS(runtime.NumCPU())

	start := time.Now()
	e := sieve.NewBitPackedEratosthenes(*limit, 2310)

	var primes []uint64
	e.ForEachPrime(func(p uint64) bool {
		primes = append(primes, p)
		return true
	})

	hasher := sieve.NewStreamHasher()
	for _, p := range primes {
		hasher.WriteInt(p)
	}

	duration := time.Since(start)

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	peakMemMB := mem.Sys / 1024 / 1024

	result := map[string]any{
		"worker":       "w2_wheel2310",
		"host":         getHostname(),
		"limit":        *limit,
		"duration_ms":  duration.Milliseconds(),
		"primes":       len(primes),
		"peak_mem_mb":  peakMemMB,
		"kat_hash":     hasher.HexSum(),
		"config":       map[string]string{"wheel": "2310", "parallel": "true", "segment_kb": "256"},
		"success":      true,
	}

	if *showConfig {
		cfg := WorkerConfig{
			Wheel:     2310,
			Parallel:  true,
			SegmentKB: 256,
		}
		json.NewEncoder(os.Stderr).Encode(cfg)
	} else {
		json.NewEncoder(os.Stderr).Encode(result)
	}

	if *showHash {
		hash := hasher.HexSum()
		fmt.Println(hash)

		if *verifyKAT {
			cmd := exec.Command("kat_verify", strconv.FormatUint(*limit, 10), hash)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				os.Exit(1)
			}
		}
	}
}

func getHostname() string {
	hostname, _ := os.Hostname()
	return hostname
}