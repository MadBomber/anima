# Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types
- feat: new feature
- fix: bug fix
- docs: documentation
- refactor: code change with no feature/fix
- test: adding/updating tests
- chore: build, deps, tooling
- perf: performance improvement
- ci: CI/CD changes

## Rules
- Description: imperative mood, lowercase, no period, <72 chars
- Breaking change: append `!` after type, e.g. `feat!:` or add `BREAKING CHANGE:` footer
