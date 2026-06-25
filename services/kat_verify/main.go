package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type Manifest struct {
	CheckpointHashes   map[string]string       `json:"checkpoint_hashes"`
	VerificationTiers  []VerificationTier      `json:"verification_tiers"`
}

type VerificationTier struct {
	Tier        string `json:"tier"`
	Bound       Bound  `json:"bound"`
	SHA256      string `json:"sha256"`
	TotalTerms  int    `json:"total_terms"`
}

type Bound struct {
	Type  string `json:"type"`
	Value uint64 `json:"value"`
}

var manifest *Manifest

func LoadManifest(manifestPath string) error {
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return fmt.Errorf("read manifest: %w", err)
	}
	manifest = &Manifest{}
	if err := json.Unmarshal(data, manifest); err != nil {
		return fmt.Errorf("parse manifest: %w", err)
	}
	return nil
}

func Verify(limit uint64, hash string) (bool, error) {
	if manifest == nil {
		if err := LoadManifest(filepath.Join("..", "..", "manifests", "A000040.json")); err != nil {
			return false, err
		}
	}
	
	hash = strings.TrimSpace(hash)
	
	// Check verification tiers (bound by count)
	for _, tier := range manifest.VerificationTiers {
		if tier.Bound.Type == "count" && tier.TotalTerms == int(limit) {
			return tier.SHA256 == hash, nil
		}
		if tier.Bound.Type == "upper_limit" && tier.Bound.Value == limit {
			return tier.SHA256 == hash, nil
		}
	}
	
	// Check checkpoint hashes (by limit)
	for k, v := range manifest.CheckpointHashes {
		var kLimit uint64
		fmt.Sscanf(k, "%d", &kLimit)
		if kLimit == limit && v == hash {
			return true, nil
		}
	}
	
	return false, fmt.Errorf("no manifest entry for limit %d", limit)
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "usage: %s <limit> <hash>\n", os.Args[0])
		os.Exit(1)
	}
	limit, err := strconv.ParseUint(os.Args[1], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid limit: %v\n", err)
		os.Exit(1)
	}
	hash := os.Args[2]
	
	ok, err := Verify(limit, hash)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	
	if ok {
		fmt.Println("Verified: true")
	} else {
		fmt.Println("Verified: false")
		os.Exit(1)
	}
}

