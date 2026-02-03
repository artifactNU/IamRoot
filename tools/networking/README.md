# Networking Tools

Tools for network diagnostics, analysis, and documentation.

---

## Purpose

Networking tools help:
- Diagnose connectivity issues
- Document network configuration
- Analyze traffic patterns
- Audit network security posture

---

## Structure

    networking/
      sniffing/    # Packet capture and analysis helpers
      scanning/    # Port scanning and service discovery

---

## Safety Considerations

Networking tools can be sensitive:
- Packet capture may contain credentials or sensitive data
- Port scanning may trigger security alerts
- Always obtain authorization before scanning networks
- Consider privacy when documenting network topology

---

## Guidelines

Tools should:
- Clearly document what data they collect
- Support output redaction for sensitive information
- Fail safely if required tools are missing
- Be read-only by default
