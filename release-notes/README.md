# Release Notes

This directory contains version-specific release notes for Chief.

## Structure

Each version has its own release notes file:

- `v3.0.md` - Released version v3.0 (historical record)
- `v3.1.0-original.md` - Original v3.1.0 release (preserved for reference)
- `v3.1.0-dev.md` - Current development version release notes  
- `v3.1.0.md` - Final release version notes (will be created when releasing)
- `v3.2.0-dev.md` - Next development cycle
- etc.

## Benefits

- **Historical Reference**: Each version maintains its own complete release notes
- **No Overwrites**: Previous version notes are preserved permanently
- **Easy Navigation**: Find release notes for any specific version
- **Development Tracking**: Development versions document features as they're built

## Workflow

1. **Starting Development**: `__chief.bump next-dev` creates new `vX.Y.Z-dev.md`
2. **During Development**: Update the development version's release notes
3. **Releasing**: `__chief.bump release` can reference the final notes
4. **Post-Release**: Development notes become historical record

## Usage

Reference specific version release notes in documentation:
```markdown
See [v3.0 Release Notes](release-notes/v3.0.md) for details.
See [v3.1.0 Release Notes](release-notes/v3.1.0.md) for details.
```

