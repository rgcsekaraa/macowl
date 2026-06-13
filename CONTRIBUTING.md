# Contributing to macowl

Thank you for taking interest in macowl. It is a small project, so the rules
are also small and simple.

## What you need

- A Mac running macOS 13 or newer.
- The Xcode command line tools. If `swiftc --version` works in your terminal,
  you are ready. If not, run `xcode-select --install` once.

That is all. There is no package manager and no extra dependency. The whole app
is plain Swift in two files.

## The files

- `main.swift` - the full app. Menu bar, power assertions and the lid logic.
- `makeicon.swift` - draws the app icon into an iconset.
- `build.sh` - builds the app and installs it to `/Applications`.
- `build-dmg.sh` - builds a DMG into `./dist` for sharing.

## How to build and test

To build and run your change locally:

```sh
./build.sh
```

This installs macowl into `/Applications` and opens it. Click the owl in the
menu bar and check that each state works as you expect.

If you only want to check that the code compiles, you can run:

```sh
swiftc -O -o /tmp/macowl main.swift
```

If you change the icon, you can preview it like this:

```sh
swift makeicon.swift /tmp/preview.iconset
open /tmp/preview.iconset
```

Please test the lid closed state carefully, because it changes a system
setting. Always confirm that turning it off and quitting puts your Mac back to
normal sleep.

## Sending a change

1. Fork the repo and make a new branch for your change.
2. Keep each commit small and clear. One idea per commit is best.
3. Write a short, plain commit message that says what changed and why.
4. Open a pull request and describe what you did and how you tested it.

## Style

- Keep the code simple and easy to read. This project values clarity over
  cleverness.
- Match the style that is already there.
- Do not use em dashes in code or docs. A normal hyphen is fine.
- Add a short comment when something is not obvious, especially around the power
  and lid logic.

## Releasing a new version (for maintainers)

Releases are automated. There are two ways to cut one:

1. **Push a version tag.** This is the usual way.

   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```

2. **Use the Actions tab.** Open the `release` workflow on GitHub, click
   *Run workflow*, and type the version (for example `1.2.0`). It will create
   the tag for you.

Either way, GitHub Actions builds the DMG with the right version baked in and
publishes it on the Releases page with generated notes. Remember to update
`CHANGELOG.md` before tagging.

The version string flows from the tag into the build through the
`MACOWL_VERSION` variable, so you do not edit any version number in the code.

## Reporting bugs and ideas

Please open an issue. Tell us your macOS version, your Mac model, and the steps
to see the problem. Screenshots help a lot.
