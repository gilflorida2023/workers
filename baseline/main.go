package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"time"

	"github.com/primeforge/shared/sieve"
)

func main() {
	limit := flag.Uint64("limit", 100_000_000, "Sieve limit")
	wantHash := flag.Bool("hash", false, "Output KAT hash to stdout")
	verifyKAT := flag.Bool("verify", false, "Self-verify KAT hash via kat_verify tool")
	flag.Parse()

	hostname, _ := os.Hostname()

	start := time.Now()
	hasher := sieve.NewStreamHasher()

	s := sieve.NewEratosthenesWithWheel(*limit, 210)
	count := uint64(0)
	s.ForEachPrime(func(p uint64) bool {
		hasher.WriteInt(p)
		count++
		return true
	})

	duration := time.Since(start)

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	peakMemMB := mem.Sys / 1024 / 1024

	result := map[string]any{
		"worker":       "w1_baseline",
		"host":         hostname,
		"limit":        *limit,
		"duration_ms":  duration.Milliseconds(),
		"primes":       count,
		"peak_mem_mb":  peakMemMB,
		"kat_hash":     hasher.HexSum(),
		"config":       map[string]string{"wheel": "210", "parallel": "true", "segment_kb": "256"},
		"success":      true,
	}

	if *wantHash {
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

	json.NewEncoder(os.Stderr).Encode(result)
}