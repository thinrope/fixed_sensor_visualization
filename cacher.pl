#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use DateTime::Format::ISO8601;

die ("\n[ERROR] Invalid number of arguments[", scalar @ARGV, "]!\n\nUsage:\n\t$0 <sensor_id> <fetch_since> <fetch_until> <TIMEZONE> <TZ> <SMA_BINS1> <SMA_BINS2>\n")
	unless (scalar @ARGV == 7);
my $id = $ARGV[0];
my $fetch_since = $ARGV[1];
my $fetch_until = $ARGV[2];
my $TIMEZONE = $ARGV[3];
my $TZ = $ARGV[4];
my $SMA_BINS1 = $ARGV[5];
my $SMA_BINS2 = $ARGV[6];

die ("\n[ERROR] SMA_BINS1 must be more than SMA_BINS2\n")
	unless ($SMA_BINS1 > $SMA_BINS2);

# API server uses in UTC in query and results
my $server_TZ='UTC';

my $since_query = qx!TZ=${server_TZ} date +since=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_since}'!; chomp $since_query;
my $until_query = qx!TZ=${server_TZ} date +until=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_until}'!; chomp $until_query;
qx!wget -q 'https://api.safecast.org/en-US/devices/$id/measurements.csv?${since_query}&${until_query}&order=captured_at+asc' -O cache/$id.tmp!;

open(IN, "<cache/$id.tmp")
	or die;
open(OUT, ">cache/$id.csv")
	or die;

my @sma_bins = ();
while(<IN>)
{
	my @R = split(/,/, $_, 5);
	if ($R[0] =~ s#(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) ${server_TZ}#DateTime::Format::ISO8601->parse_datetime(qq(${1}T${2}Z))->set_time_zone(${TIMEZONE}).${TZ}#e)
	{
		push @sma_bins, $R[3];							# push in buffer
		shift @sma_bins								# trim the oldest, if buffer too big
			if (scalar(@sma_bins) > $SMA_BINS1);
		#print STDERR  join(":", $#sma_bins-11, $#sma_bins), "\t", join("\t", @sma_bins), "\n";
		my $sma1 = (eval join('+', @sma_bins)) / scalar(@sma_bins);		# eval buffer
		my $sma2 = $sma1;							# place for smaller buffer
		if (scalar(@sma_bins) > $SMA_BINS2)						# if buffer is larger than smaller size
		{
			$sma2 = (eval join('+', @sma_bins[$#sma_bins-$SMA_BINS2 + 1 .. $#sma_bins])) / $SMA_BINS2;	# use only last 12 bins, NOTE: index OB1
		}
		print OUT join(',', $R[0], $R[3], sprintf("%0.3f,%0.3f\n", $sma1, $sma2));
	}
}
close(OUT)
	or die;
close(IN)
	or die;
