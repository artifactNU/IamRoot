#!/usr/bin/env perl
#
# Extract failed SSH login attempts with context
# Safe: read-only log analysis
#

use strict;
use warnings;
use autodie;

my $log_file = '/var/log/auth.log';
my %failed_attempts;

# Read-only check
die "Cannot read $log_file\n" unless -r $log_file;

open my $fh, '<', $log_file;

while (my $line = <$fh>) {
    if ($line =~ /Failed password for (\w+) from ([\d.]+)/) {
        my ($user, $ip) = ($1, $2);
        $failed_attempts{$ip}{$user}++;
    }
}

close $fh;

# Output formatted report
print "Failed SSH Login Attempts:\n";
print "=" x 60, "\n";

foreach my $ip (sort keys %failed_attempts) {
    print "\nFrom: $ip\n";
    foreach my $user (sort keys %{$failed_attempts{$ip}}) {
        printf "  %-20s : %d attempts\n", $user, $failed_attempts{$ip}{$user};
    }
}