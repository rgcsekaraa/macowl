# Security Policy

## Supported versions

macowl is a small project. Only the latest release gets fixes.

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## A note on what macowl does

macowl asks for your admin password only for the "Even with Lid Closed" state.
It uses the password to run one system command, `pmset -a disablesleep`, which
controls whether the Mac sleeps when the lid is shut. It does not install any
background helper, it does not keep your password, and it does not talk to the
internet.

## Reporting a problem

If you find a security problem, please do not open a public issue first.
Instead, please report it privately using GitHub's
[private security advisory](../../security/advisories/new) feature, or contact
the maintainer directly.

Please include:

- What the problem is.
- Steps to see it happen.
- Your macOS version and Mac model.

I will reply as soon as I can and work on a fix.
