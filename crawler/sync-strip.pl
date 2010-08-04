#!/usr/local/bin/perl

use strict;
use warnings;

use Getopt::Long;
use DBI;
use URI;
use LWP::UserAgent;
use JSON;

my %opts = ();
my $configfile = '/etc/comic-strip.ini';
GetOptions("config=s" => \$configfile);

# Read config file
open CONFIG, "<$configfile" or die "Could not open $configfile: $!";

while(<CONFIG>) {
	next unless /=/;
	chomp;
	s/^\s+//;
	s/\s+$//;
	my ($k, $v) = split /\s*=\s*/;
	$opts{$k} = $v;
}

close CONFIG;

# Init utility objects

my $ua = LWP::UserAgent->new;
$ua->agent($opts{'app_name'} . ' ');
$ua->from($opts{'admin_email'});
$ua->timeout(10);

my $url = URI->new('http://query.yahooapis.com/v1/public/yql'); 

my $json = new JSON;
$json->utf8();




my $dbh = DBI->connect("dbi:mysql:$opts{'db_name'};host=$opts{'db_host'}", $opts{'db_user'}, $opts{'db_password'}) || die "Could not connect to db: $!";

# 1. get last 3 from db
my $sql = 'SELECT n, date_posted, id From strip Order by n desc LIMIT 1';
my $db_strips = $dbh->selectall_arrayref($sql, { Slice => {} });

# 2. get everything from flickr

my $yql = 'SELECT * From flickr.photosets.photos Where photoset_id=@photoset';
$url->query_form( q => $yql, photoset => $opts{'photoset_id'}, format => 'json', callback => '' );

my $response = $ua->get($url->canonical);

if($response->code != 200) {
	die 'YQL said ' . $response->code . "\n";
}

my $flickr_strips = $json->decode($response->content);
my @flickr_strips = @{$flickr_strips->{'query'}{'results'}{'photo'}};

# 3. find first flickr item greater than last db item
my ($start_index, $end_index) = (0, $#flickr_strips);
if(scalar @$db_strips) {
	my $last_id = $db_strips->{'id'};

	for( ; $start_index <= $end_index && $flickr_strips[$start_index]{'id'} != $last_id; $start_index++) {
		;
	}
	$start_index++;
}

@flickr_strips = @flickr_strips[$start_index..$end_index] if $start_index > 0;

# 4. fetch additional info for each photo not in db
$yql = sprintf 'SELECT id, description, dates.posted From flickr.photos.info Where photo_id IN (%s)',
		join ',', map { $_->{'id'} } @flickr_strips;
$url->query_form( q => $yql, format => 'json', callback => '' );

$response = $ua->get($url->canonical);

if($response->code != 200) {
	die 'YQL said ' . $response->code . "\n";
}

my $flickr_more = $json->decode($response->content);
my %flickr_more = map { ( $_->{'id'}, $_ ) } @{$flickr_more->{'query'}{'results'}{'photo'}};

for (@flickr_strips) {
	if(exists $flickr_more{$_->{'id'}}) {
		$_->{'description'} = $flickr_more{$_->{'id'}}{'description'};
		$_->{'date_posted'} = $flickr_more{$_->{'id'}}{'dates'}{'posted'};
	}
}

@flickr_strips = sort { $a->{'date_posted'} <=> $b->{'date_posted'} } @flickr_strips;


# 5. store new photos in db

$sql = sprintf
	'INSERT INTO strip (
		date_posted,
		id, farm, secret, server,
		title, description
	) VALUES (%s)',
	join '), (', map {
		my $tuple = $_;
		sprintf 'FROM_UNIXTIME(%s), %s',
			$dbh->quote($tuple->{'date_posted'}),
			join ',', map { $dbh->quote($tuple->{$_} || '') } qw(id farm secret server title description)
	} @flickr_strips;


$dbh->do($sql);
$dbh->disconnect();
