# Tool: workspace.run

## Description
Execute a compiled binary or script in the workspace.

## Parameters
- `path` (string, required): Path to executable/script relative to workspace root
- `args` (array of strings, optional): Command line arguments
- `timeout` (integer, optional, default: 30): Timeout in seconds

## Returns
```json
{
  "success": true,
  "stdout": "program output...",
  "stderr": "error output...",
  "exit_code": 0
}
```

## Example
```json
{"name": "workspace.run", "arguments": {"path": "./main", "args": ["-limit", "100"]}}
```

## Notes
- Working directory is workspace root
- For Python scripts: use "python3 script.py" as path
- Captures both stdout and stderr
- Returns exit_code (0 = success)