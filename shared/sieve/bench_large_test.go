package sieve

import (
	"fmt"
	"testing"
	"time"
)

func TestBenchLarge(t *testing.T) {
	for _, limit := range []uint64{10_000_000, 50_000_000, 100_000_000, 200_000_000} {
		fmt.Printf("\n=== Limit: %d ===\n", limit)
		
		// Sequential
		s1 := NewBitPackedEratosthenes(limit, 210)
		start := time.Now()
		c1 := 0
		s1.ForEachPrimeSequential(func(p uint64) bool { c1++; return true })
		seqTime := time.Since(start)
		
		// Parallel
		s2 := NewBitPackedEratosthenes(limit, 210)
		start = time.Now()
		c2 := 0
		s2.ForEachPrime(func(p uint64) bool { c2++; return true })
		parTime := time.Since(start)
		
		fmt.Printf("Sequential: %d primes in %v\n", c1, seqTime)
		fmt.Printf("Parallel:   %d primes in %v\n", c2, parTime)
		fmt.Printf("Speedup:    %.2fx\n", float64(seqTime)/float64(parTime))
		
		if c1 != c2 {
			t.Errorf("Count mismatch at %d: seq=%d par=%d", limit, c1, c2)
		}
	}
}
