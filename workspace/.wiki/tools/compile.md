# Tool: workspace.compile

## Description
Compile source code in the workspace. Supports Go, Python, C, C++, Rust.

## Parameters
- `path` (string, required): Path to source file relative to workspace root
- `language` (string, optional): "go", "python", "c", "cpp", "rust", or "auto" (default: auto-detect from extension)

## Returns
```json
{
  "success": true,
  "language": "go",
  "binary": "main",
  "output": "compilation output..."
}
```

## Example
```json
{"name": "workspace.compile", "arguments": {"path": "main.go", "language": "go"}}
```

## Notes
- For Python: validates syntax (py_compile), no binary produced
- For Go: produces binary with same name as source (without .go)
- For C/C++: produces a.out or named binary
- For Rust: requires Cargo.toml, uses cargo build
- On failure: success=false, output contains error messages