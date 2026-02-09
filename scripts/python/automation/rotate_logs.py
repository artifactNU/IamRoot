#!/usr/bin/env python3
"""
rotate-logs.py
Purpose: Automate log rotation and compression with configurable retention
Usage:   ./rotate-logs.py CONFIG_FILE
Exit:    0 OK, 1 ERROR

Dependencies: None (uses Python standard library only)
"""

import sys
import json
import gzip
import shutil
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List
import re
import logging


class LogRotator:
    """Handle log file rotation and compression with configurable policies."""

    def __init__(self, config: Dict, dry_run: bool = False, verbose: bool = False):
        self.config = config
        self.dry_run = dry_run
        self.verbose = verbose
        self.stats = {
            'rotated': 0,
            'compressed': 0,
            'deleted': 0,
            'errors': 0,
            'bytes_freed': 0
        }

        # Setup logging
        log_level = logging.DEBUG if verbose else logging.INFO
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)

    def rotate_logs(self) -> int:
        """
        Execute log rotation based on configuration.
        Returns: Exit code (0 = success, 1 = error)
        """
        if not self.config.get('log_groups'):
            self.logger.error("No log_groups defined in configuration")
            return 1

        self.logger.info("Starting log rotation (dry_run=%s)", self.dry_run)

        for group_name, group_config in self.config['log_groups'].items():
            self.logger.info("Processing log group: %s", group_name)
            self._process_log_group(group_name, group_config)

        self._print_summary()
        return 0 if self.stats['errors'] == 0 else 1

    def _process_log_group(self, _group_name: str, config: Dict) -> None:
        """Process a single log group configuration."""
        log_dir = Path(config.get('directory', ''))
        pattern = config.get('pattern', '*')
        max_age_days = config.get('max_age_days', 30)
        max_rotations = config.get('max_rotations', 5)
        compress = config.get('compress', True)
        min_size_mb = config.get('min_size_mb', 0)

        if not log_dir.exists():
            self.logger.warning("Directory does not exist: %s", log_dir)
            return

        if not log_dir.is_dir():
            self.logger.error("Not a directory: %s", log_dir)
            self.stats['errors'] += 1
            return

        # Find matching log files
        try:
            log_files = self._find_log_files(log_dir, pattern)
        except (OSError, PermissionError) as e:
            self.logger.error("Error finding log files in %s: %s", log_dir, e)
            self.stats['errors'] += 1
            return

        if not log_files:
            self.logger.debug("No log files found matching pattern: %s", pattern)
            return

        self.logger.info("Found %d log file(s)", len(log_files))

        for log_file in log_files:
            try:
                self._process_log_file(
                    log_file,
                    max_age_days,
                    max_rotations,
                    compress,
                    min_size_mb
                )
            except (OSError, PermissionError) as e:
                self.logger.error("Error processing %s: %s", log_file, e)
                self.stats['errors'] += 1

    def _find_log_files(self, log_dir: Path, pattern: str) -> List[Path]:
        """Find log files matching the pattern."""
        # Convert glob pattern to regex if needed
        if '*' in pattern or '?' in pattern:
            return sorted(log_dir.glob(pattern))
        else:
            # Exact match
            log_file = log_dir / pattern
            return [log_file] if log_file.exists() else []

    def _process_log_file(
        self,
        log_file: Path,
        max_age_days: int,
        max_rotations: int,
        compress: bool,
        min_size_mb: float
    ) -> None:
        """Process a single log file."""
        # Check if file should be rotated
        if not self._should_rotate(log_file, min_size_mb):
            return

        self.logger.info("Rotating: %s", log_file)

        # Rotate existing rotated logs (shift numbering)
        self._shift_rotations(log_file, max_rotations)

        # Rotate current log file
        if not self.dry_run:
            rotated_name = f"{log_file}.1"
            try:
                shutil.copy2(log_file, rotated_name)
                # Truncate original log
                with open(log_file, 'w', encoding='utf-8'):
                    pass
                self.logger.info("Created: %s", rotated_name)
                self.stats['rotated'] += 1
            except (OSError, PermissionError) as e:
                self.logger.error("Failed to rotate %s: %s", log_file, e)
                self.stats['errors'] += 1
                return
        else:
            self.logger.info("[DRY RUN] Would rotate: %s -> %s.1", log_file, log_file)
            self.stats['rotated'] += 1

        # Compress rotated logs if enabled
        if compress:
            self._compress_rotated_logs(log_file, max_rotations)

        # Clean up old rotated logs
        self._cleanup_old_rotations(log_file, max_age_days, max_rotations)

    def _should_rotate(self, log_file: Path, min_size_mb: float) -> bool:
        """Determine if a log file should be rotated."""
        if not log_file.exists():
            return False

        # Check minimum size requirement
        if min_size_mb > 0:
            size_mb = log_file.stat().st_size / (1024 * 1024)
            if size_mb < min_size_mb:
                self.logger.debug(
                    "Skipping %s: size %.2fMB < %.2fMB",
                    log_file.name, size_mb, min_size_mb
                )
                return False

        return True

    def _shift_rotations(self, log_file: Path, max_rotations: int) -> None:
        """Shift existing rotation numbers (e.g., .2 -> .3, .1 -> .2)."""
        # Start from highest number and work backwards
        for i in range(max_rotations - 1, 0, -1):
            old_name = Path(f"{log_file}.{i}")
            new_name = Path(f"{log_file}.{i + 1}")

            # Also check for compressed versions
            old_gz = Path(f"{old_name}.gz")
            new_gz = Path(f"{new_name}.gz")

            if old_gz.exists():
                if not self.dry_run:
                    old_gz.rename(new_gz)
                    self.logger.debug("Renamed: %s -> %s", old_gz.name, new_gz.name)
                else:
                    self.logger.debug(
                        "[DRY RUN] Would rename: %s -> %s", old_gz.name, new_gz.name
                    )
            elif old_name.exists():
                if not self.dry_run:
                    old_name.rename(new_name)
                    self.logger.debug("Renamed: %s -> %s", old_name.name, new_name.name)
                else:
                    self.logger.debug(
                        "[DRY RUN] Would rename: %s -> %s", old_name.name, new_name.name
                    )

    def _compress_rotated_logs(self, log_file: Path, max_rotations: int) -> None:
        """Compress rotated log files."""
        for i in range(1, max_rotations + 1):
            rotated_file = Path(f"{log_file}.{i}")
            compressed_file = Path(f"{rotated_file}.gz")

            if rotated_file.exists() and not compressed_file.exists():
                if not self.dry_run:
                    try:
                        with open(rotated_file, 'rb') as f_in:
                            with gzip.open(compressed_file, 'wb') as f_out:
                                shutil.copyfileobj(f_in, f_out)

                        # Calculate space saved
                        original_size = rotated_file.stat().st_size
                        compressed_size = compressed_file.stat().st_size
                        saved = original_size - compressed_size
                        self.stats['bytes_freed'] += saved

                        # Remove original
                        rotated_file.unlink()

                        self.logger.info(
                            "Compressed: %s (%s -> %s)",
                            rotated_file.name,
                            self._format_bytes(original_size),
                            self._format_bytes(compressed_size)
                        )
                        self.stats['compressed'] += 1
                    except (OSError, PermissionError) as e:
                        self.logger.error("Failed to compress %s: %s", rotated_file, e)
                        self.stats['errors'] += 1
                else:
                    self.logger.info(
                        "[DRY RUN] Would compress: %s", rotated_file.name
                    )
                    self.stats['compressed'] += 1

    def _cleanup_old_rotations(
        self,
        log_file: Path,
        max_age_days: int,
        max_rotations: int
    ) -> None:
        """Remove old rotated log files based on age and count."""
        cutoff_date = datetime.now() - timedelta(days=max_age_days)

        # Find all rotated versions
        pattern = f"{log_file.name}.*"
        rotated_files = sorted(
            log_file.parent.glob(pattern),
            key=lambda p: p.stat().st_mtime
        )

        for rotated in rotated_files:
            # Skip if it's the main log file
            if rotated == log_file:
                continue

            # Check age
            mtime = datetime.fromtimestamp(rotated.stat().st_mtime)
            too_old = mtime < cutoff_date

            # Check rotation count
            match = re.search(r'\.(\d+)(\.gz)?$', rotated.name)
            if match:
                rotation_num = int(match.group(1))
                too_many = rotation_num > max_rotations
            else:
                too_many = False

            if too_old or too_many:
                size = rotated.stat().st_size
                if not self.dry_run:
                    try:
                        rotated.unlink()
                        self.logger.info("Deleted old rotation: %s", rotated.name)
                        self.stats['deleted'] += 1
                        self.stats['bytes_freed'] += size
                    except (OSError, PermissionError) as e:
                        self.logger.error("Failed to delete %s: %s", rotated, e)
                        self.stats['errors'] += 1
                else:
                    reason = "too old" if too_old else "exceeds max rotations"
                    self.logger.info(
                        "[DRY RUN] Would delete %s (%s)", rotated.name, reason
                    )
                    self.stats['deleted'] += 1

    def _format_bytes(self, bytes_size: int) -> str:
        """Format bytes into human-readable string."""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if bytes_size < 1024.0:
                return f"{bytes_size:.1f}{unit}"
            bytes_size /= 1024.0
        return f"{bytes_size:.1f}TB"

    def _print_summary(self) -> None:
        """Print summary of rotation operations."""
        self.logger.info("=" * 60)
        self.logger.info("Rotation Summary:")
        self.logger.info("  Files rotated:    %d", self.stats['rotated'])
        self.logger.info("  Files compressed: %d", self.stats['compressed'])
        self.logger.info("  Files deleted:    %d", self.stats['deleted'])
        self.logger.info("  Space freed:      %s", self._format_bytes(self.stats['bytes_freed']))
        self.logger.info("  Errors:           %d", self.stats['errors'])
        self.logger.info("=" * 60)


def load_config(config_file: str) -> Dict:
    """Load configuration from JSON file."""
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Configuration file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in configuration file: {e}", file=sys.stderr)
        sys.exit(1)


def print_example_config() -> None:
    """Print an example configuration file."""
    example = {
        "log_groups": {
            "apache_logs": {
                "directory": "/var/log/apache2",
                "pattern": "access.log",
                "max_age_days": 30,
                "max_rotations": 7,
                "compress": True,
                "min_size_mb": 10
            },
            "application_logs": {
                "directory": "/var/log/myapp",
                "pattern": "*.log",
                "max_age_days": 90,
                "max_rotations": 10,
                "compress": True,
                "min_size_mb": 1
            },
            "system_logs": {
                "directory": "/var/log",
                "pattern": "syslog",
                "max_age_days": 14,
                "max_rotations": 5,
                "compress": True,
                "min_size_mb": 0
            }
        }
    }

    print("Example configuration file (JSON):")
    print(json.dumps(example, indent=2))


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Automate log rotation and compression',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Rotate logs using configuration file
  %(prog)s /etc/logrotate.json

  # Dry run to see what would happen
  %(prog)s /etc/logrotate.json --dry-run

  # Verbose output
  %(prog)s /etc/logrotate.json --verbose

  # Show example configuration
  %(prog)s --example-config

Configuration format:
  JSON file with log_groups defining:
  - directory: Path to log directory
  - pattern: Filename pattern (supports * and ?)
  - max_age_days: Delete rotations older than this (default: 30)
  - max_rotations: Maximum number of rotations to keep (default: 5)
  - compress: Whether to gzip rotated logs (default: true)
  - min_size_mb: Minimum file size in MB to trigger rotation (default: 0)
        """
    )

    parser.add_argument(
        'config_file',
        nargs='?',
        help='Path to JSON configuration file'
    )
    parser.add_argument(
        '-n', '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--example-config',
        action='store_true',
        help='Print an example configuration file and exit'
    )

    args = parser.parse_args()

    # Handle --example-config
    if args.example_config:
        print_example_config()
        return 0

    # Require config file if not showing example
    if not args.config_file:
        parser.error("config_file is required")

    # Load configuration
    config = load_config(args.config_file)

    # Create rotator and execute
    rotator = LogRotator(config, dry_run=args.dry_run, verbose=args.verbose)
    return rotator.rotate_logs()


if __name__ == '__main__':
    sys.exit(main())
