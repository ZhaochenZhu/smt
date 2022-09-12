#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use POSIX;

use Cwd;

### Testing out argument command
# my $ARGC        = @ARGV;
# my $workdir     = getcwd();

my @a = (1,2,3,4,5,6,7);
# my @b = sub { @_[1..$#_] }->(@ARGV);

# print Dumper \@ARGV;
# my $numTrackV =12;

# my $len = length(sprintf("%b", $numTrackV))+4;
# print(length(sprintf("%b", $numTrackV)), "\n");
# print($len, "\n");

### example code of dereferencing array from hash
# my @temp = ();
# print Dumper($map_metal_to_vertices{"$metal"});

# @temp = @{$map_metal_to_vertices{"$metal"}};
# my $len = scalar @temp;
# for my $i (0 .. $len - 1)
# {
#     print("$temp[$i]\n");
# }
# exit(0);

sub combine;
sub combine_sub;

sub combine {
	# take a list and number as arg
	my ($list, $n) = @_;
	# raise an exception if n > len(list)
	die "Insufficient list members" if $n > @$list;
	# vectorization:  if for all item in list
	return map [$_], @$list if $n <= 1;

	my @comb;
    
	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		print("val: $val\n");
		my @rest = @$list[$i+1..$#$list];
		print("rest\n");
		print(Dumper\@rest);
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
		if($i==0){
			last; # terminate loop
		}
	}

	return @comb;
}

sub combine_sub {
	my ($list, $n) = @_;
	die "Insufficient list members" if $n > @$list;

	return map [$_], @$list if $n <= 1;

	my @comb;

	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		my @rest = @$list[$i+1..$#$list];
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
	}

	return @comb;
}

print(Dumper\combine([@a], 5))

