#!/usr/bin/env python3
"""
system_health_check.py
Purpose: Comprehensive system health monitoring with structured output
Usage:   ./system_health_check.py [OPTIONS]
Exit:    0 OK, 1 WARNING, 2 CRITICAL

Dependencies: None (uses Python standard library only)
"""

import sys
import os
import time
import json
import argparse
import subprocess
import platform
import socket
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from collections import defaultdict


class SystemHealthChecker:
    """Collect and analyze system health metrics."""

    def __init__(
        self,
        warning_thresholds: Dict[str, int],
        critical_thresholds: Dict[str, int]
    ):
        self.warning_thresholds = warning_thresholds
        self.critical_thresholds = critical_thresholds
        self.issues = []
        self.warnings = []

    def check_health(self) -> Dict[str, Any]:
        """Run all health checks and return results."""
        results = {
            'timestamp': datetime.now().isoformat(),
            'hostname': socket.gethostname(),
            'platform': self._get_platform_info(),
            'uptime': self._get_uptime(),
            'cpu': self._check_cpu(),
            'memory': self._check_memory(),
            'disk': self._check_disk(),
            'load': self._check_load_average(),
            'services': self._check_services(),
            'processes': self._check_processes(),
            'network': self._check_network(),
            'status': 'OK',
            'issues': self.issues,
            'warnings': self.warnings
        }

        # Determine overall status
        if self.issues:
            results['status'] = 'CRITICAL'
        elif self.warnings:
            results['status'] = 'WARNING'

        return results

    def _get_platform_info(self) -> Dict[str, str]:
        """Get platform information."""
        return {
            'system': platform.system(),
            'release': platform.release(),
            'version': platform.version(),
            'machine': platform.machine(),
            'python_version': platform.python_version()
        }

    def _get_uptime(self) -> Optional[str]:
        """Get system uptime."""
        try:
            with open('/proc/uptime', 'r', encoding='utf-8') as f:
                uptime_seconds = float(f.read().split()[0])
                days = int(uptime_seconds // 86400)
                hours = int((uptime_seconds % 86400) // 3600)
                minutes = int((uptime_seconds % 3600) // 60)
                return f"{days}d {hours}h {minutes}m"
        except (FileNotFoundError, PermissionError, ValueError):
            return None

    def _check_cpu(self) -> Dict[str, Any]:
        """Check CPU usage and information."""
        cpu_info = {
            'cores': None,
            'usage_percent': None,
            'status': 'OK'
        }

        try:
            # Get CPU count
            with open('/proc/cpuinfo', 'r', encoding='utf-8') as f:
                cpu_count = sum(1 for line in f if line.startswith('processor'))
                cpu_info['cores'] = cpu_count

            # Get CPU usage from /proc/stat
            usage = self._get_cpu_usage()
            if usage is not None:
                cpu_info['usage_percent'] = round(usage, 2)

                if usage >= self.critical_thresholds['cpu']:
                    cpu_info['status'] = 'CRITICAL'
                    self.issues.append(
                        f"CPU usage at {usage:.1f}% "
                        f"(critical threshold: {self.critical_thresholds['cpu']}%)"
                    )
                elif usage >= self.warning_thresholds['cpu']:
                    cpu_info['status'] = 'WARNING'
                    self.warnings.append(
                        f"CPU usage at {usage:.1f}% "
                        f"(warning threshold: {self.warning_thresholds['cpu']}%)"
                    )

        except (FileNotFoundError, PermissionError):
            cpu_info['status'] = 'UNKNOWN'

        return cpu_info

    def _get_cpu_usage(self) -> Optional[float]:
        """Calculate CPU usage percentage."""
        try:
            # Read /proc/stat twice with a small delay
            with open('/proc/stat', 'r', encoding='utf-8') as f:
                line1 = f.readline()
            time.sleep(0.1)
            with open('/proc/stat', 'r', encoding='utf-8') as f:
                line2 = f.readline()

            # Parse CPU stats
            stats1 = [int(x) for x in line1.split()[1:]]
            stats2 = [int(x) for x in line2.split()[1:]]

            # Calculate differences
            idle1 = stats1[3]
            idle2 = stats2[3]
            total1 = sum(stats1)
            total2 = sum(stats2)

            total_diff = total2 - total1
            idle_diff = idle2 - idle1

            if total_diff == 0:
                return None

            usage = 100.0 * (total_diff - idle_diff) / total_diff
            return usage

        except (FileNotFoundError, PermissionError, ValueError, IndexError):
            return None

    def _check_memory(self) -> Dict[str, Any]:
        """Check memory usage."""
        mem_info = {
            'total_mb': None,
            'used_mb': None,
            'free_mb': None,
            'available_mb': None,
            'usage_percent': None,
            'swap_total_mb': None,
            'swap_used_mb': None,
            'swap_percent': None,
            'status': 'OK'
        }

        try:
            with open('/proc/meminfo', 'r', encoding='utf-8') as f:
                meminfo = {}
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2:
                        key = parts[0].rstrip(':')
                        value = int(parts[1])
                        meminfo[key] = value

            # Convert kB to MB
            mem_info['total_mb'] = meminfo.get('MemTotal', 0) // 1024
            mem_info['free_mb'] = meminfo.get('MemFree', 0) // 1024
            mem_info['available_mb'] = meminfo.get('MemAvailable', 0) // 1024
            mem_info['used_mb'] = mem_info['total_mb'] - mem_info['available_mb']

            if mem_info['total_mb'] > 0:
                mem_info['usage_percent'] = round(
                    100.0 * mem_info['used_mb'] / mem_info['total_mb'], 2
                )

                if mem_info['usage_percent'] >= self.critical_thresholds['memory']:
                    mem_info['status'] = 'CRITICAL'
                    self.issues.append(
                        f"Memory usage at {mem_info['usage_percent']:.1f}% "
                        f"(critical threshold: {self.critical_thresholds['memory']}%)"
                    )
                elif mem_info['usage_percent'] >= self.warning_thresholds['memory']:
                    mem_info['status'] = 'WARNING'
                    self.warnings.append(
                        f"Memory usage at {mem_info['usage_percent']:.1f}% "
                        f"(warning threshold: {self.warning_thresholds['memory']}%)"
                    )

            # Swap information
            swap_total = meminfo.get('SwapTotal', 0) // 1024
            swap_free = meminfo.get('SwapFree', 0) // 1024
            swap_used = swap_total - swap_free

            mem_info['swap_total_mb'] = swap_total
            mem_info['swap_used_mb'] = swap_used

            if swap_total > 0:
                mem_info['swap_percent'] = round(100.0 * swap_used / swap_total, 2)
                if mem_info['swap_percent'] >= 50:
                    self.warnings.append(f"Swap usage at {mem_info['swap_percent']:.1f}%")

        except (FileNotFoundError, PermissionError, ValueError):
            mem_info['status'] = 'UNKNOWN'

        return mem_info

    def _check_disk(self) -> List[Dict[str, Any]]:
        """Check disk usage for all mounted filesystems."""
        disks = []

        try:
            # Read /proc/mounts to get mounted filesystems
            with open('/proc/mounts', 'r', encoding='utf-8') as f:
                mounts = [line.split() for line in f if line.strip()]

            # Filter to real filesystems (skip virtual filesystems)
            real_fs_types = {
                'ext4', 'ext3', 'ext2', 'xfs', 'btrfs', 'zfs', 'ntfs', 'vfat'
            }

            for mount in mounts:
                if len(mount) < 3:
                    continue

                device, mountpoint, fstype = mount[0], mount[1], mount[2]

                if fstype not in real_fs_types:
                    continue

                disk_info = self._get_disk_usage(mountpoint)
                if disk_info:
                    disk_info['device'] = device
                    disk_info['fstype'] = fstype
                    disks.append(disk_info)

        except (FileNotFoundError, PermissionError):
            pass

        return disks

    def _get_disk_usage(self, path: str) -> Optional[Dict[str, Any]]:
        """Get disk usage for a specific path."""
        try:
            # Use os.statvfs for proper disk stats
            vfs = os.statvfs(path)

            total = vfs.f_blocks * vfs.f_frsize
            free = vfs.f_bfree * vfs.f_frsize
            available = vfs.f_bavail * vfs.f_frsize
            used = total - free

            usage_percent = 0
            if total > 0:
                usage_percent = round(100.0 * used / total, 2)

            disk_info = {
                'mountpoint': path,
                'total_gb': round(total / (1024**3), 2),
                'used_gb': round(used / (1024**3), 2),
                'free_gb': round(free / (1024**3), 2),
                'available_gb': round(available / (1024**3), 2),
                'usage_percent': usage_percent,
                'status': 'OK'
            }

            if usage_percent >= self.critical_thresholds['disk']:
                disk_info['status'] = 'CRITICAL'
                self.issues.append(
                    f"Disk {path} at {usage_percent:.1f}% "
                    f"(critical threshold: {self.critical_thresholds['disk']}%)"
                )
            elif usage_percent >= self.warning_thresholds['disk']:
                disk_info['status'] = 'WARNING'
                self.warnings.append(
                    f"Disk {path} at {usage_percent:.1f}% "
                    f"(warning threshold: {self.warning_thresholds['disk']}%)"
                )

            return disk_info

        except (FileNotFoundError, PermissionError, OSError):
            return None

    def _check_load_average(self) -> Dict[str, Any]:
        """Check system load average."""
        load_info = {
            'load_1min': None,
            'load_5min': None,
            'load_15min': None,
            'cpu_cores': None,
            'load_per_core': None,
            'status': 'OK'
        }

        try:
            with open('/proc/loadavg', 'r', encoding='utf-8') as f:
                loads = f.read().split()
                load_info['load_1min'] = float(loads[0])
                load_info['load_5min'] = float(loads[1])
                load_info['load_15min'] = float(loads[2])

            # Get CPU count for load per core
            with open('/proc/cpuinfo', 'r', encoding='utf-8') as f:
                cpu_count = sum(1 for line in f if line.startswith('processor'))
                load_info['cpu_cores'] = cpu_count

            if cpu_count > 0:
                load_per_core = load_info['load_1min'] / cpu_count
                load_info['load_per_core'] = round(load_per_core, 2)

                # Check if load is high
                if load_per_core >= 2.0:
                    load_info['status'] = 'CRITICAL'
                    self.issues.append(
                        f"Load average {load_info['load_1min']} is high for "
                        f"{cpu_count} cores (load per core: {load_per_core:.2f})"
                    )
                elif load_per_core >= 1.5:
                    load_info['status'] = 'WARNING'
                    self.warnings.append(
                        f"Load average {load_info['load_1min']} is elevated for "
                        f"{cpu_count} cores (load per core: {load_per_core:.2f})"
                    )

        except (FileNotFoundError, PermissionError, ValueError, IndexError):
            load_info['status'] = 'UNKNOWN'

        return load_info

    def _check_services(self) -> List[Dict[str, str]]:
        """Check status of common system services."""
        services_to_check = [
            'ssh', 'sshd',
            'cron', 'crond',
            'systemd-journald',
            'NetworkManager', 'network-manager'
        ]

        service_status = []

        for service in services_to_check:
            status = self._get_service_status(service)
            if status['status'] != 'not_found':
                service_status.append(status)
                if status['status'] not in ['active', 'running']:
                    self.warnings.append(f"Service {service} is {status['status']}")

        return service_status

    def _get_service_status(self, service: str) -> Dict[str, str]:
        """Get status of a specific service using systemctl."""
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', service],
                capture_output=True,
                text=True,
                timeout=5,
                check=False
            )
            status = result.stdout.strip()

            return {
                'name': service,
                'status': status if status else 'unknown'
            }
        except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
            return {
                'name': service,
                'status': 'not_found'
            }

    def _check_processes(self) -> Dict[str, Any]:
        """Check process information."""
        process_info = {
            'total': 0,
            'running': 0,
            'sleeping': 0,
            'zombie': 0,
            'stopped': 0,
            'status': 'OK'
        }

        try:
            proc_path = Path('/proc')
            state_counts = defaultdict(int)

            for item in proc_path.iterdir():
                if item.is_dir() and item.name.isdigit():
                    try:
                        with open(item / 'stat', 'r', encoding='utf-8') as f:
                            stat_line = f.read()
                            # State is the third field (after PID and command)
                            state = stat_line.split(')')[1].split()[0]
                            state_counts[state] += 1
                    except (FileNotFoundError, PermissionError):
                        continue

            process_info['total'] = sum(state_counts.values())
            process_info['running'] = state_counts.get('R', 0)
            process_info['sleeping'] = state_counts.get('S', 0)
            process_info['zombie'] = state_counts.get('Z', 0)
            process_info['stopped'] = state_counts.get('T', 0)

            if process_info['zombie'] > 0:
                self.warnings.append(f"Found {process_info['zombie']} zombie process(es)")

        except (FileNotFoundError, PermissionError):
            process_info['status'] = 'UNKNOWN'

        return process_info

    def _check_network(self) -> Dict[str, Any]:
        """Check network interface statistics."""
        network_info = {
            'interfaces': [],
            'status': 'OK'
        }

        try:
            net_path = Path('/sys/class/net')
            for iface in net_path.iterdir():
                if iface.name == 'lo':
                    continue

                iface_info = {
                    'name': iface.name,
                    'state': self._read_file(iface / 'operstate'),
                    'rx_bytes': self._read_int_file(iface / 'statistics' / 'rx_bytes'),
                    'tx_bytes': self._read_int_file(iface / 'statistics' / 'tx_bytes'),
                    'rx_errors': self._read_int_file(iface / 'statistics' / 'rx_errors'),
                    'tx_errors': self._read_int_file(iface / 'statistics' / 'tx_errors')
                }

                # Convert bytes to MB
                if iface_info['rx_bytes']:
                    iface_info['rx_mb'] = round(iface_info['rx_bytes'] / (1024**2), 2)
                if iface_info['tx_bytes']:
                    iface_info['tx_mb'] = round(iface_info['tx_bytes'] / (1024**2), 2)

                network_info['interfaces'].append(iface_info)

                if iface_info['state'] == 'down':
                    self.warnings.append(f"Network interface {iface.name} is down")

        except (FileNotFoundError, PermissionError):
            network_info['status'] = 'UNKNOWN'

        return network_info

    def _read_file(self, path: Path) -> Optional[str]:
        """Read a file and return its content as string."""
        try:
            return path.read_text(encoding='utf-8').strip()
        except (FileNotFoundError, PermissionError):
            return None

    def _read_int_file(self, path: Path) -> Optional[int]:
        """Read a file and return its content as integer."""
        try:
            return int(path.read_text(encoding='utf-8').strip())
        except (FileNotFoundError, PermissionError, ValueError):
            return None


def format_plain_text(results: Dict[str, Any]) -> str:
    """Format results as plain text."""
    lines = []

    lines.append("=" * 70)
    lines.append("SYSTEM HEALTH CHECK")
    lines.append("=" * 70)
    lines.append(f"Timestamp: {results['timestamp']}")
    lines.append(f"Hostname:  {results['hostname']}")
    lines.append(f"Status:    {results['status']}")
    lines.append("")

    # Platform
    lines.append("Platform:")
    lines.append(f"  System:  {results['platform']['system']} {results['platform']['release']}")
    lines.append(f"  Machine: {results['platform']['machine']}")
    if results['uptime']:
        lines.append(f"  Uptime:  {results['uptime']}")
    lines.append("")

    # CPU
    cpu = results['cpu']
    lines.append(f"CPU: {cpu['status']}")
    lines.append(f"  Cores: {cpu['cores']}")
    if cpu['usage_percent'] is not None:
        lines.append(f"  Usage: {cpu['usage_percent']}%")
    lines.append("")

    # Memory
    mem = results['memory']
    lines.append(f"Memory: {mem['status']}")
    if mem['total_mb']:
        lines.append(f"  Total:     {mem['total_mb']} MB")
        lines.append(f"  Used:      {mem['used_mb']} MB")
        lines.append(f"  Available: {mem['available_mb']} MB")
        lines.append(f"  Usage:     {mem['usage_percent']}%")
        if mem['swap_total_mb'] and mem['swap_total_mb'] > 0:
            lines.append(
                f"  Swap:      {mem['swap_used_mb']}/{mem['swap_total_mb']} MB "
                f"({mem['swap_percent']}%)"
            )
    lines.append("")

    # Load average
    load = results['load']
    lines.append(f"Load Average: {load['status']}")
    if load['load_1min'] is not None:
        lines.append(f"  1min:  {load['load_1min']}")
        lines.append(f"  5min:  {load['load_5min']}")
        lines.append(f"  15min: {load['load_15min']}")
        if load['load_per_core'] is not None:
            lines.append(f"  Per core: {load['load_per_core']}")
    lines.append("")

    # Disk
    lines.append("Disk Usage:")
    for disk in results['disk']:
        lines.append(
            f"  {disk['mountpoint']} "
            f"({disk['device']}, {disk['fstype']}): {disk['status']}"
        )
        lines.append(f"    Total: {disk['total_gb']} GB")
        lines.append(f"    Used:  {disk['used_gb']} GB ({disk['usage_percent']}%)")
        lines.append(f"    Free:  {disk['available_gb']} GB")
    lines.append("")

    # Processes
    proc = results['processes']
    lines.append(f"Processes: {proc['status']}")
    lines.append(f"  Total:    {proc['total']}")
    lines.append(f"  Running:  {proc['running']}")
    lines.append(f"  Sleeping: {proc['sleeping']}")
    if proc['zombie'] > 0:
        lines.append(f"  Zombie:   {proc['zombie']} ⚠")
    lines.append("")

    # Services
    if results['services']:
        lines.append("Services:")
        for svc in results['services']:
            status_mark = "✓" if svc['status'] in ['active', 'running'] else "✗"
            lines.append(f"  {status_mark} {svc['name']:<20} {svc['status']}")
        lines.append("")

    # Network
    if results['network']['interfaces']:
        lines.append("Network Interfaces:")
        for iface in results['network']['interfaces']:
            state_mark = "✓" if iface['state'] == 'up' else "✗"
            lines.append(f"  {state_mark} {iface['name']:<15} {iface['state']}")
            if iface.get('rx_mb') is not None:
                lines.append(
                    f"     RX: {iface['rx_mb']} MB, TX: {iface['tx_mb']} MB"
                )
                if iface['rx_errors'] or iface['tx_errors']:
                    lines.append(
                        f"     Errors - RX: {iface['rx_errors']}, "
                        f"TX: {iface['tx_errors']}"
                    )
        lines.append("")

    # Issues and warnings
    if results['issues']:
        lines.append("CRITICAL ISSUES:")
        for issue in results['issues']:
            lines.append(f"  ✗ {issue}")
        lines.append("")

    if results['warnings']:
        lines.append("WARNINGS:")
        for warning in results['warnings']:
            lines.append(f"  ⚠ {warning}")
        lines.append("")

    lines.append("=" * 70)

    return "\n".join(lines)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Comprehensive system health monitoring',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run health check with default thresholds
  %(prog)s

  # Output as JSON
  %(prog)s --json

  # Custom warning thresholds
  %(prog)s --warn-cpu 80 --warn-memory 85 --warn-disk 90

  # Custom critical thresholds
  %(prog)s --crit-cpu 95 --crit-memory 95 --crit-disk 98

Exit codes:
  0 - All checks passed (OK)
  1 - Warnings detected
  2 - Critical issues detected
        """
    )

    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    parser.add_argument(
        '--warn-cpu',
        type=int,
        default=80,
        help='CPU usage warning threshold (default: 80%%)'
    )
    parser.add_argument(
        '--warn-memory',
        type=int,
        default=85,
        help='Memory usage warning threshold (default: 85%%)'
    )
    parser.add_argument(
        '--warn-disk',
        type=int,
        default=85,
        help='Disk usage warning threshold (default: 85%%)'
    )
    parser.add_argument(
        '--crit-cpu',
        type=int,
        default=95,
        help='CPU usage critical threshold (default: 95%%)'
    )
    parser.add_argument(
        '--crit-memory',
        type=int,
        default=95,
        help='Memory usage critical threshold (default: 95%%)'
    )
    parser.add_argument(
        '--crit-disk',
        type=int,
        default=95,
        help='Disk usage critical threshold (default: 95%%)'
    )

    args = parser.parse_args()

    # Set up thresholds
    warning_thresholds = {
        'cpu': args.warn_cpu,
        'memory': args.warn_memory,
        'disk': args.warn_disk
    }

    critical_thresholds = {
        'cpu': args.crit_cpu,
        'memory': args.crit_memory,
        'disk': args.crit_disk
    }

    # Run health check
    checker = SystemHealthChecker(warning_thresholds, critical_thresholds)
    results = checker.check_health()

    # Output results
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print(format_plain_text(results))

    # Exit with appropriate code
    if results['status'] == 'CRITICAL':
        return 2
    elif results['status'] == 'WARNING':
        return 1
    else:
        return 0


if __name__ == '__main__':
    sys.exit(main())
