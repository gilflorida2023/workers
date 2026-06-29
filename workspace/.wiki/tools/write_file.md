# Tool: workspace.write

## Description
Write content to a file in the workspace. Creates directories as needed.

## Parameters
- `path` (string, required): Path to the file relative to workspace root
- `content` (string, required): Content to write

## Returns
```json
{
  "success": true,
  "path": "file.py",
  "bytes_written": 1234
}
```

## Example
```json
{"name": "workspace.write", "arguments": {"path": "hello.py", "content": "print('Hello!')"}}
```

## Notes
- Overwrites existing files
- Creates parent directories automatically
- Path must be within workspace