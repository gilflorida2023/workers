# Tool: wiki.lookup

## Description
Look up tool documentation from the wiki. Returns the full markdown content for a tool or guide.

## Parameters
- `topic` (string, required): Tool name (e.g., "workspace.read") or guide name (e.g., "getting_started")

## Returns
```json
{
  "success": true,
  "topic": "workspace.read",
  "content": "# Tool: workspace.read\n\n## Description\n..."
}
```

## Example
```json
{"name": "wiki.lookup", "arguments": {"topic": "workspace.compile"}}
```

## Notes
- Searches both tools/ and guides/ directories
- Returns full markdown content
- Use when you need detailed parameter info or examples