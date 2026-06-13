# Changelog

All notable changes to macowl are written here. This project follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-06-13

### Fixed
- The build scripts hardcoded the version, so every release built the same
  `macowl-1.0.0.dmg`. The version now comes from the git tag (or the
  `MACOWL_VERSION` variable) and flows into both the DMG name and the app's
  Info.plist.
- The tag lookup no longer aborts the build scripts on a repo with no tags.

### Added
- The release workflow can now be run by hand from the Actions tab with a
  version input, in addition to pushing a version tag.

## [1.0.0] - 2026-06-13

The first release.

### Added
- Menu bar app that keeps the Mac awake using IOKit power assertions, with no
  Dock icon and no `caffeinate` child process.
- Three awake states: System, System + Display, and Off.
- A new state, Even with Lid Closed, that keeps the Mac running with the lid
  shut by using the `pmset disablesleep` system setting.
- Safety for the lid state: a marker file and a check on launch, so the Mac is
  never left stuck awake after a crash or a force quit.
- Restore of normal sleep on SIGTERM, SIGINT and SIGHUP, and on quit.
- Clear error messages when the admin prompt is refused or fails.
- Start at Login option using SMAppService.
- A custom owl icon that opens its eyes when awake and closes them when off.
- `build.sh` to build and install locally, and `build-dmg.sh` to make a DMG.

[1.0.1]: https://github.com/rgcsekaraa/macowl/releases/tag/v1.0.1
[1.0.0]: https://github.com/rgcsekaraa/macowl/releases/tag/v1.0.0
