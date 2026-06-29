# Guide: Getting Started

## Overview
This wiki provides documentation for the coding agent's tools and workflows.

## Tool Categories

### Workspace Operations
| Tool | Description |
|------|-------------|
| `workspace.read` | Read file contents |
| `workspace.write` | Write file contents |
| `workspace.list` | List directory contents |
| `workspace.delete` | Delete files/directories |

### Code Execution
| Tool | Description |
|------|-------------|
| `workspace.compile` | Compile source code (Go, Python, C, C++, Rust) |
| `workspace.run` | Execute binaries/scripts |
| `workspace.search` | Search code with grep |

### Documentation
| Tool | Description |
|------|-------------|
| `wiki.lookup` | Look up tool documentation |

## Workflow Example

```json
{"name": "wiki.lookup", "arguments": {"topic": "workspace.write"}}
{"name": "workspace.write", "arguments": {"path": "hello.py", "content": "print('Hello!')"}}
{"name": "workspace.run", "arguments": {"path": "python3 hello.py"}}
```

## Best Practices
1. Always use `wiki.lookup` before using a new tool
2. Read files before editing them
3. Compile before running
4. Search before writing new code