package main

import (
	"github.com/primeforge/shared/sieve"
)

type BaselineWorker struct{}

func (w *BaselineWorker) Name() string {
	return "w1_baseline"
}

func (w *BaselineWorker) Config() map[string]string {
	return map[string]string{
		"wheel":      "210",
		"seg_span":   "auto",
		"parallel":   "true",
		"pre_sieve":  "true",
		"strategy":   "bitpacked_parallel",
	}
}

func (w *BaselineWorker) Sieve(limit uint64, hasher *sieve.StreamHasher) (uint64, error) {
	s := sieve.NewBitPackedEratosthenes(limit, 210)
	count := uint64(0)
	s.ForEachPrime(func(p uint64) bool {
		hasher.WriteInt(p)
		count++
		return true
	})
	return count, nil
}