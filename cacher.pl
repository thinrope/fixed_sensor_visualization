#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use DateTime::Format::ISO8601;

die ("\n[ERROR] Invalid number of arguments[", scalar @ARGV, "]!\n\nUsage:\n\t$0 <sensor_id> <fetch_since> <fetch_until> <TIMEZONE> <TZ>\n")
	unless (scalar @ARGV == 5);
my $id = $ARGV[0];
my $fetch_since = $ARGV[1];
my $fetch_until = $ARGV[2];
my $TIMEZONE = $ARGV[3];
my $TZ = $ARGV[4];

# API server uses in UTC in query and results
my $server_TZ='UTC';

my $since_query = qx!TZ=${server_TZ} date +since=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_since}'!; chomp $since_query;
my $until_query = qx!TZ=${server_TZ} date +until=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_until}'!; chomp $until_query;
qx!wget -q 'https://api.safecast.org/en-US/devices/$id/measurements.csv?${since_query}&${until_query}&order=captured_at+asc' -O cache/$id.tmp!;

open(IN, "<cache/$id.tmp")
	or die;
open(OUT, ">cache/$id.csv")
	or die;
while(<IN>)
{
	my @R = split(/,/, $_, 5);
	print OUT join(',', $R[0], $R[3]), "\n"
		if ($R[0] =~ s#(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) ${server_TZ}#DateTime::Format::ISO8601->parse_datetime(qq(${1}T${2}Z))->set_time_zone(${TIMEZONE}).${TZ}#e);
}
close(OUT)
	or die;
close(IN)
	or die;
