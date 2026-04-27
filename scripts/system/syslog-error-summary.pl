#!/usr/bin/env perl
#
# Summarise ERROR and WARNING entries in syslog grouped by program
# Usage:   perl syslog-error-summary.pl [/path/to/syslog]
# Safe: read-only log analysis
#

use strict;
use warnings;
use autodie;

my $log_file = $ARGV[0] // '/var/log/syslog';
my %counts;

die "Cannot read $log_file\n" unless -r $log_file;

open my $fh, '<', $log_file;

while (my $line = <$fh>) {
    # Standard syslog format: Mon DD HH:MM:SS hostname program[pid]: message
    next unless $line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+(\S+?)(?:\[\d+\])?:\s+(.+)/;
    my ($program, $message) = ($1, $2);

    if ($message =~ /\b(error|critical|crit|emerg|alert)\b/i) {
        $counts{$program}{error}++;
    } elsif ($message =~ /\bwarning\b/i) {
        $counts{$program}{warning}++;
    }
}

close $fh;

if (!%counts) {
    print "No errors or warnings found in $log_file\n";
    exit 0;
}

my @programs = sort {
    ($counts{$b}{error}   // 0) <=> ($counts{$a}{error}   // 0)
        ||
    ($counts{$b}{warning} // 0) <=> ($counts{$a}{warning} // 0)
} keys %counts;

printf "%-30s %8s %8s\n", 'Program', 'Errors', 'Warnings';
print '-' x 50, "\n";

foreach my $prog (@programs) {
    printf "%-30s %8d %8d\n",
        $prog,
        $counts{$prog}{error}   // 0,
        $counts{$prog}{warning} // 0;
}
