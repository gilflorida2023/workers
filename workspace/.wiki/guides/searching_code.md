# Guide: Searching Code

## Basic Search
```json
{"name": "workspace.search", "arguments": {"pattern": "func Sieve"}}
```

## Search with File Filter
```json
{"name": "workspace.search", "arguments": {"pattern": "TODO", "file_pattern": "*.go"}}
```

## Search with Context
```json
{"name": "workspace.search", "arguments": {"pattern": "error", "context_lines": 5}}
```

## Regex Patterns

| Pattern | Matches |
|---------|---------|
| `func\\s+\\w+` | Function definitions (Go) |
| `def\\s+\\w+` | Function definitions (Python) |
| `TODO|FIXME|XXX` | TODO comments |
| `\\b[A-Z_]{3,}\\b` | Constants (UPPER_SNAKE) |
| `\\.go$` | Go files (use file_pattern instead) |

## Tips
- Use `file_pattern` instead of regex for file extensions
- `(?i)` for case-insensitive: `(?i)error`
- `(?-i)` for case-sensitive: `(?-i)Error`
- `context_lines` helps understand context