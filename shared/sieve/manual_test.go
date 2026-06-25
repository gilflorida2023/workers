package sieve

import (
	"fmt"
	"testing"
)

func TestManualParallel10M(t *testing.T) {
	s := NewBitPackedEratosthenes(10000000, 210)
	count := 0
	s.ForEachPrimeSequential(func(p uint64) bool {
		count++
		return true
	})
	fmt.Printf("Sequential 10M: %d primes\n", count)

	s2 := NewBitPackedEratosthenes(10000000, 210)
	count2 := 0
	s2.ForEachPrime(func(p uint64) bool {
		count2++
		return true
	})
	fmt.Printf("Parallel 10M: %d primes\n", count2)

	if count != count2 {
		t.Errorf("Count mismatch: seq=%d par=%d", count, count2)
	}
}
