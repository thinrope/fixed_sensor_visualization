#!/usr/bin/perl
use warnings;
use strict;
use utf8;

my $TIMEOUT = $ARGV[0];		# 10 intervals, or 2 h in default case is good
my @P;
while(<STDIN>)
{
	chomp;
	my @R = split(/,/, $_, 5);
	print "$P[0],$R[0]\n"
		if ($R[4] > ${TIMEOUT});
	@P = @R;
}
