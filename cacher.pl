#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use DateTime::Format::ISO8601;

die ("\n[ERROR] Invalid number of arguments[", scalar @ARGV, "]!\n\n",
	"Usage:\n\t$0 <sensor_id> <fetch_since> <fetch_until> <TIMEZONE> <TZ> <AVG_WINDOW_LARGE> <AVG_VINDOW_SMALL>\n")
	unless (scalar @ARGV == 7);
my $id = $ARGV[0];
my $fetch_since = $ARGV[1];
my $fetch_until = $ARGV[2];
my $TIMEZONE = $ARGV[3];
my $TZ = $ARGV[4];
my $AVG_WINDOW_LARGE = $ARGV[5];
my $AVG_WINDOW_SMALL = $ARGV[6];

die ("\n[ERROR] AVG_WINDOW_LARGE must be bigger than AVG_WINDOW_SMALL\n")
	unless ($AVG_WINDOW_LARGE > $AVG_WINDOW_SMALL);

# API server uses in UTC in query and results
my $server_TZ='UTC';


# {{{ Simple Moving Average filter implementation
# -------------------------------------------------------------------
sub SMA_filter_init
{
	my ($bins, $config) = @_;
	@{$bins} = ();
}

sub SMA_filter_update
{
	my ($bins, $config, $value, $dt) = @_;
	push @{$bins}, $value;
	shift @{$bins}							# trim the oldest, if buffer too big
		if (scalar(@{$bins}) > $config->{window});
}

sub SMA_filter_read
{
	my ($bins, $config) = @_;
	return( (eval join('+', @{$bins})) / scalar(@{$bins}));		# eval buffer
}
# }}}

# {{{ Low Pass filter implementation
# -------------------------------------------------------------------
sub LP_filter_init
{
	my ($bins, $config) = @_;

	@{$bins} = ();
	map { $bins->[$_] = $config->{IV}; } 0 .. $config->{order};	# OBO!

	my $gainScale = 1.0 / sqrt( 2.0 ** (1.0/$config->{order}) - 1.0);
        $config->{rc} = 1.0 / ( 2.0 * 3.1415927 * $config->{cutoff} * $gainScale );
}

sub LP_filter_update
{
	my ($bins, $config, $v, $dt) = @_;

	my $a  =  $dt / ($config->{rc} + $dt);

	$bins->[0] = $v;
	map { $bins->[$_] = (1.0 - $a ) * $bins->[$_] + $a * $bins->[$_ - 1];} 1 .. $config->{order};
}

sub LP_filter_read
{
	my ($bins, $config) = @_;
	return $bins->[$config->{order}];
}
# }}}

my $since_query = qx!TZ=${server_TZ} date +since=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_since}'!; chomp $since_query;
my $until_query = qx!TZ=${server_TZ} date +until=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_until}'!; chomp $until_query;
my $URL = "https://api.safecast.org/en-US/devices/$id/measurements.csv?${since_query}&${until_query}&unit=cpm&order=captured_at+asc";
open(LOG, ">cache/$id.URL")
	or die("$! , exitting");
print LOG $URL;
close(LOG)
	or die("$! , exitting");

my $cmd = "wget -q '${URL}' -O cache/$id.tmp";
qx!$cmd!;

open(IN, "<cache/$id.tmp")
	or die("$! , exitting");
open(OUT, ">cache/$id.csv")
	or die("$! , exitting");


my $t_prev = -1;
my $dt_prev = 36000;	# NOTE: Big number initially, 10h

my @SMA_LARGE_bins = (); my %SMA_LARGE_config = ( 'window' => $AVG_WINDOW_LARGE);
&SMA_filter_init(\@SMA_LARGE_bins, \%SMA_LARGE_config);

my @SMA_SMALL_bins = (); my %SMA_SMALL_config = ( 'window' => $AVG_WINDOW_SMALL);
&SMA_filter_init(\@SMA_SMALL_bins, \%SMA_SMALL_config);

#my @LP_SMALL_bins = (); my %LP_SMALL_config = ( 'order' => 1, 'cutoff' => 60E-6, 'IV' => 0.0);
#&LP_filter_init(\@LP_SMALL_bins, \%LP_SMALL_config);

while(<IN>)
{
	my @R = split(/,/, $_, 5);
	if ($R[0] =~ m#(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) ${server_TZ}#)
	{
		my $timestamp = DateTime::Format::ISO8601->parse_datetime(qq(${1}T${2}Z))->set_time_zone(${TIMEZONE});

		# calculate difference
		$t_prev = $timestamp->epoch() - 300	# defeault is 5min
			if ($t_prev == -1);
		my $dt = $timestamp->epoch() - $t_prev;
		$t_prev = $timestamp->epoch();

		&SMA_filter_update(\@SMA_LARGE_bins, \%SMA_LARGE_config, $R[3], $dt);
		my $SMA_LARGE = &SMA_filter_read(\@SMA_LARGE_bins, \%SMA_LARGE_config);

		&SMA_filter_update(\@SMA_SMALL_bins, \%SMA_SMALL_config, $R[3], $dt);
		my $SMA_SMALL = &SMA_filter_read(\@SMA_SMALL_bins, \%SMA_SMALL_config);

		#&LP_filter_update(\@LP_SMALL_bins, \%LP_SMALL_config, $R[3], $dt);
		#my $LP_SMALL = &LP_filter_read(\@LP_SMALL_bins, \%LP_SMALL_config);

		print OUT "\n"				# print blank line, if there was missing data (for gnuplot)
			if ($dt > 5.0 * $dt_prev);
		$dt_prev = $dt;

		print OUT join(',', "${timestamp}${TZ}", $R[3], sprintf("%0.3f,%0.3f,%d\n", $SMA_LARGE, $SMA_SMALL, $dt));
	}
}

close(OUT)
	or die("$!, exitting");
close(IN)
	or die("$! ,exitting");
__END__
# vim: set foldmethod=marker :
