# Guide: Python Development

## Running Python Scripts
```json
{"name": "workspace.run", "arguments": {"path": "python3 script.py"}}
```

Or with arguments:
```json
{"name": "workspace.run", "arguments": {"path": "python3 main.py", "args": ["--limit", "100"]}}
```

## Syntax Checking (Compile)
```json
{"name": "workspace.compile", "arguments": {"path": "script.py", "language": "python"}}
```
Validates syntax only (no binary produced).

## Common Patterns

### Sieve of Eratosthenes
```python
def sieve(limit: int) -> list[int]:
    if limit < 2:
        return []
    sieve = [True] * (limit + 1)
    sieve[0] = sieve[1] = False
    for i in range(2, int(limit**0.5) + 1):
        if sieve[i]:
            for j in range(i*i, limit+1, i):
                sieve[j] = False
    return [i for i, is_prime in enumerate(sieve) if is_prime]
```

## Tips
- Use `python3 -m py_compile script.py` for syntax check
- `pip install -r requirements.txt` for dependencies
- `pytest` for testing