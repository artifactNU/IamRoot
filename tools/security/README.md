# Security Tools

Tools for security auditing, hardening, and incident response.

---

## Purpose

Security tools assist with:
- System hardening assessments
- Security audit collection
- Incident investigation
- Forensic data gathering

---

## Structure

    security/
      forensics/    # Incident investigation and evidence collection
      hardening/    # Security posture assessment and hardening helpers

---

## Critical Considerations

Security tools require extra care:
- May collect sensitive system information
- Output should be treated as confidential
- Consider legal and policy implications
- Document data retention requirements
- Never distribute tools that bypass security controls

---

## Guidelines

Security tools must:
- Be explicit about what data they collect
- Support secure output handling
- Log their own execution where appropriate
- Fail safely if permissions are insufficient
- Include clear documentation on intended use
