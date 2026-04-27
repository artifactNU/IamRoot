#!/usr/bin/env perl
#
# Report successful SSH logins grouped by user and source IP
# Safe: read-only log analysis
#

use strict;
use warnings;
use autodie;

my $log_file = '/var/log/auth.log';
my %logins;

die "Cannot read $log_file\n" unless -r $log_file;

open my $fh, '<', $log_file;

while (my $line = <$fh>) {
    if ($line =~ /Accepted \S+ for (\S+) from ([\d.]+)/) {
        my ($user, $ip) = ($1, $2);
        $logins{$user}{$ip}++;
    }
}

close $fh;

if (!%logins) {
    print "No successful SSH logins found in $log_file\n";
    exit 0;
}

print "Successful SSH Logins:\n";
print "=" x 60, "\n";

foreach my $user (sort keys %logins) {
    print "\nUser: $user\n";
    foreach my $ip (sort keys %{$logins{$user}}) {
        printf "  %-20s : %d login%s\n",
            $ip,
            $logins{$user}{$ip},
            $logins{$user}{$ip} == 1 ? '' : 's';
    }
}
