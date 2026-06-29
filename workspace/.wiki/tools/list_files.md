# Tool: workspace.list

## Description
List files and directories in the workspace.

## Parameters
- `path` (string, optional, default: "."): Directory path relative to workspace root

## Returns
```json
{
  "success": true,
  "path": ".",
  "files": [
    {"name": "main.py", "type": "file", "size": 1234, "modified": "2024-01-15T10:30:00Z"},
    {"name": "src", "type": "directory", "size": 0, "modified": "2024-01-15T10:30:00Z"}
  ]
}
```

## Example
```json
{"name": "workspace.list", "arguments": {"path": "src"}}
```

## Notes
- Shows both files and directories
- Includes size and modification time
- Hidden files (starting with .) are included