# Release Notes

This directory contains version-specific release notes for Chief.

## Structure

Each version has its own release notes file:

- `v3.0.md` - Released version v3.0 (historical record)
- `v3.1.0-dev.md` - Development version release notes (work-in-progress)
- `v3.1.0.md` - Complete v3.1.0 release notes (comprehensive re-release)
- `v3.2.0-dev.md` - Next development cycle
- etc.

## Benefits

- **Historical Reference**: Each version maintains its own complete release notes
- **No Overwrites**: Previous version notes are preserved permanently
- **Easy Navigation**: Find release notes for any specific version
- **Development Tracking**: Development versions document features as they're built

## Workflow

1. **Releasing (maintainers)**: `chief.release_publish --next vX.Y.Z` turns `vX.Y.Z-dev.md` into the final `vX.Y.Z.md`, publishes the GitHub release from it, and creates the next `vA.B.C-dev.md`. Check progress any time with `chief.release_status`. These dev-only commands need `chief.config-set dev_tools true` and Chief on the `dev` branch.
2. **During Development**: Update the development version's release notes
3. **Optional staging**: `chief.release_prepare` does the release bump on dev without publishing, for review first
4. **Post-Release**: Development notes become historical record

## Usage

Reference specific version release notes in documentation:
```markdown
See [v3.0 Release Notes](release-notes/v3.0.md) for details.
See [v3.1.0 Release Notes](release-notes/v3.1.0.md) for details.
```

