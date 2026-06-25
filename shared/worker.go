package shared

type Worker interface {
	Name() string
	Sieve(limit uint64, hasher *StreamHasher) (count uint64, err error)
	Config() map[string]string
}

type StreamHasher interface {
	WriteInt(n uint64)
	Sum() [32]byte
	HexSum() string
}