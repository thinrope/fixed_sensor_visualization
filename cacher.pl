#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use DateTime::Format::ISO8601;

die ("\n[ERROR] Invalid number of arguments!\n\nUsage:\n\t$0 <sensor_id> <since_date>\n")
	unless (scalar @ARGV == 2);
my $id = $ARGV[0];
my $since_date = $ARGV[1];

my $since_query = qx!date +since=%d%%2F%m%%2F%Y+00%%3A00%%3A00 --date='${since_date}'!; chomp $since_query;
qx!wget -q 'https://api.safecast.org/en-US/devices/$id/measurements.csv?${since_query}&order=captured_at+asc' -O cache/$id.tmp!;

open(IN, "<cache/$id.tmp")
	or die;
open(OUT, ">cache/$id.csv")
	or die;
while(<IN>)
{
	my @R = split(/,/, $_, 5);
	print OUT join(',', $R[0], $R[3]), "\n"
		if ($R[0] =~ s#(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) UTC#DateTime::Format::ISO8601->parse_datetime(qq(${1}T${2}Z))->set_time_zone(q(Asia/Tokyo)).q(JST)#e);
}
close(OUT)
	or die;
close(IN)
	or die;
