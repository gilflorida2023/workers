package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"runtime"
	"time"

	"github.com/primeforge/shared/sieve"
)

type Result struct {
	DurationMs int64   `json:"duration_ms"`
	Primes     uint64  `json:"primes"`
	PeakMemMB  uint64  `json:"peak_mem_mb"`
	Config     string  `json:"config"`
	Worker     string  `json:"worker"`
	Host       string  `json:"host"`
	Limit      uint64  `json:"limit"`
	Timestamp  int64   `json:"timestamp"`
	CodeHash   string  `json:"code_hash"`
}

func main() {
	limit := flag.Uint64("limit", 100_000_000, "Sieve limit")
	wantHash := flag.Bool("hash", false, "Output KAT hash to stdout")
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

	result := Result{
		DurationMs: duration.Milliseconds(),
		Primes:     count,
		PeakMemMB:  peakMemMB,
		Config:     `{"wheel":210,"parallel":true,"segment_kb":256}`,
		Worker:     "baseline",
		Host:       hostname,
		Limit:      *limit,
		Timestamp:  time.Now().UnixMilli(),
		CodeHash:   "baseline-wheel210-parallel",
	}

	if *wantHash {
		fmt.Println(hasher.HexSum())
	}

	jsonResult, _ := json.Marshal(result)
	fmt.Fprintln(os.Stderr, string(jsonResult))
}