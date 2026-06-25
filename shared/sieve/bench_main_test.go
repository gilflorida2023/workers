package sieve

import (
	"fmt"
	"testing"
	"time"
)

func BenchmarkSeqVsPar10M(b *testing.B) {
	limit := uint64(10_000_000)
	
	// Sequential
	b.Run("sequential", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			s := NewBitPackedEratosthenes(limit, 210)
			s.ForEachPrimeSequential(func(p uint64) bool { return true })
		}
	})
	
	// Parallel
	b.Run("parallel", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			s := NewBitPackedEratosthenes(limit, 210)
			s.ForEachPrime(func(p uint64) bool { return true })
		}
	})
}

func TestBenchSeqVsPar(t *testing.T) {
	limit := uint64(10_000_000)
	
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
}
