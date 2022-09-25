#!/usr/bin/perl

# Need to install perl module:
#perl -MCPAN -e shell
#>install Parallel::ForkManager

use strict;
use warnings;
use LWP::Simple;
use Parallel::ForkManager;

my $pm = Parallel::ForkManager->new(300); # Set max number of processes

my $file = "/tmp/diff2"; # Set file with commands generated by /etc/sidinfo.sh
my $logfile = '/tmp/sidupdater.log'; # Set log file

open my $in, "<:encoding(utf8)", $file or die "$file: $!"; # Read lines
my @lines = <$in>;
close $in;

chomp @lines; # Remove newline characters

print "Writing log into /tmp/sidupdater.log\n"; # Printing information

LINES:
for my $line (@lines) { # Iterate through lines
     $pm->start and next LINES; # Start child process and generate new parallel child process
     qx($line); # Execute command
     $pm->finish; # Stop child process
}
$pm->wait_all_children; # Wait until all processes are finished

print "All /etc/motd_sidinfo updated\n";
