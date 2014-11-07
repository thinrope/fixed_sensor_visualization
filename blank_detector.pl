#!/usr/bin/perl
use warnings;
use strict;
use utf8;

my @P;
while(<>)
{
	chomp;
	my @R = split(/,/, $_, 5);
	print "$P[0],$R[0]\n"
		if ($R[4] > 7200);	# FIXME: hardcoded 2 h
	@P = @R;
}
