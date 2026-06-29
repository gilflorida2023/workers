# Tool: workspace.search

## Description
Search for text patterns in files within the workspace using grep.

## Parameters
- `pattern` (string, required): Regular expression pattern to search for
- `path` (string, optional, default: "."): Directory to search in
- `file_pattern` (string, optional): Glob pattern for files (e.g., "*.py")
- `context_lines` (integer, optional, default: 2): Lines of context around matches

## Returns
```json
{
  "success": true,
  "pattern": "func.*Sieve",
  "matches": [
    {"file": "sieve.go", "line": 10, "content": "func Sieve(n int) []int {"},
    {"file": "sieve.go", "line": 45, "content": "    return Sieve(limit)"}
  ]
}
```

## Example
```json
{"name": "workspace.search", "arguments": {"pattern": "TODO", "file_pattern": "*.go"}}
```

## Notes
- Uses grep -r with -n for line numbers
- Case-insensitive by default (use (?-i) for case-sensitive)
- Respects .gitignore