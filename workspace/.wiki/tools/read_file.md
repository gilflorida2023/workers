# Tool: workspace.read

## Description
Read a file from the workspace directory.

## Parameters
- `path` (string, required): Relative path to file within workspace

## Returns
- `content` (string): File contents
- `size` (integer): File size in bytes
- `path` (string): Path that was read

## Example
```json
{"path": "main.go"}
```

Returns:
```json
{"content": "package main\n\nfunc main() {\n    println(\"Hello\")\n}", "size": 45, "path": "main.go"}
```

## Errors
- `file_not_found`: Path does not exist
- `permission_denied`: Cannot read file
- `not_a_file`: Path is a directory

## Notes
- Path is relative to workspace root: `/home/scout/projects/sandbox/workspace/`
- Maximum file size: 10MB
- Text files only (UTF-8)