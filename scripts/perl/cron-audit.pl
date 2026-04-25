#!/usr/bin/env perl
#
# Collect and display all cron jobs from system and user crontabs
# Safe: read-only, skips files it cannot access
#

use strict;
use warnings;

my @sources;

push @sources, { file => '/etc/crontab', label => '/etc/crontab' };

if (-d '/etc/cron.d') {
    opendir my $dh, '/etc/cron.d' or die "Cannot open /etc/cron.d: $!\n";
    for my $f (sort readdir $dh) {
        next if $f =~ /^\./;
        my $path = "/etc/cron.d/$f";
        push @sources, { file => $path, label => "/etc/cron.d/$f" } if -f $path;
    }
    closedir $dh;
}

my $spool = '/var/spool/cron/crontabs';
if (-d $spool) {
    opendir my $dh, $spool or warn "Cannot open $spool (try running as root)\n";
    if ($dh) {
        for my $user (sort readdir $dh) {
            next if $user =~ /^\./;
            my $path = "$spool/$user";
            push @sources, { file => $path, label => "user: $user" } if -f -r $path;
        }
        closedir $dh;
    }
}

my $found = 0;

for my $src (@sources) {
    next unless -r $src->{file};

    open my $fh, '<', $src->{file} or next;
    my @jobs;

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/;
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*(MAILTO|PATH|SHELL|HOME)\s*=/;
        push @jobs, $line;
    }

    close $fh;
    next unless @jobs;

    $found = 1;
    print "\n$src->{label}\n";
    print '-' x length($src->{label}), "\n";
    print "$_\n" for @jobs;
}

print "No cron jobs found.\n" unless $found;
