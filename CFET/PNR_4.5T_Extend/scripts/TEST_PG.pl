#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use POSIX;

use Cwd;

### Testing out argument command
my $ARGC        = @ARGV;
my $workdir     = getcwd();

my @a = (1,2,3,4,5,6,7);
my @b = sub { @_[1..$#_] }->(@ARGV);

print Dumper \@ARGV;
my $numTrackV =12;

my $len = length(sprintf("%b", $numTrackV))+4;
print(length(sprintf("%b", $numTrackV)), "\n");
print($len, "\n");