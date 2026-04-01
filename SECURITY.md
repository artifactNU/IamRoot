# Security Policy

Thank you for helping keep IamRoot and its users.

## Supported Versions

IamRoot currently follows a rolling-release model on the `main` branch.
Security fixes are applied to the latest state of `main`.

| Version                     | Supported   |
| --------------------------- | ----------- |
| `main`                      | Yes         |
| tagged releases             | Best effort |
| archived/deprecated content | No          |

Notes:
- Files in `archive/` are historical and are not actively maintained.
- Deprecated scripts are not guaranteed to receive security updates.

## Reporting a Vulnerability

Please do not report security vulnerabilities in public issues or discussions.

Preferred method:
- Use GitHub Private Vulnerability Reporting for this repository:
  - Go to the Security tab in the repository and choose "Report a vulnerability".

If private reporting is unavailable:
- Open an issue with minimal detail and request a private contact channel, or
- Contact the maintainer through a trusted private channel.

When reporting, include:
- Affected file(s), script(s), or docs path(s)
- Impact and severity (what an attacker can do)
- Reproduction steps or proof of concept
- Any suggested remediation

## Response Expectations

Maintainers aim to:
- Acknowledge receipt within 7 days
- Provide an initial triage update within 14 days
- Share remediation status and expected timeline when confirmed

Complex issues may take longer, especially when broad testing is required.

## Disclosure Process

- Reports are triaged and validated privately.
- A fix is prepared and reviewed.
- Once a fix is available, maintainers may publish a coordinated disclosure with remediation guidance.
- Credit will be given to reporters who want to be acknowledged.

## Scope Notes for This Repository

Because IamRoot contains scripts and operational guidance:
- Security issues may include unsafe defaults, command injection risk, privilege misuse, or data exposure.
- Documentation issues that could cause unsafe operator behavior are also in scope.
- Best-effort scripts and deprecated archive content are lower-priority unless high-impact.