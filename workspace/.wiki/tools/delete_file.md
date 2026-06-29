# Tool: workspace.delete

## Description
Delete a file or directory from the workspace.

## Parameters
- `path` (string, required): Path to delete relative to workspace root
- `recursive` (boolean, optional, default: false): Delete directories recursively

## Returns
```json
{
  "success": true,
  "path": "old_file.py"
}
```

## Example
```json
{"name": "workspace.delete", "arguments": {"path": "temp.txt"}}
```

## Notes
- Use recursive=true for directories
- Path must be within workspace
- Cannot delete workspace root