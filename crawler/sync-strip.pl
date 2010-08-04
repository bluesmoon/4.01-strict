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

open CONFIG, "<$configfile" or die "Could not open $configfile: $!";

while(<CONFIG>) {
	next unless /=/;
	chomp;
	s/^\s+//;
	s/\s+$//;
	my ($k, $v) = split /\s*=\s*/;
	$opts{$k} = $v;
}


my $dbh = DBI->connect("dbi:mysql:$opts{'db_name'};host=$opts{'db_host'}", $opts{'db_user'}, $opts{'db_password'}) || die "Could not connect to db: $!";

# 1. get last 3 from db
my $sql = 'SELECT n, date_posted, id From strip Order by n desc LIMIT 1';
my $db_strips = $dbh->selectall_arrayref($sql, { Slice => {} });

# 2. get everything from flickr

my $yql = 'SELECT * From flickr.photosets.photos Where photoset_id=@photoset';
my $url = URI->new('http://query.yahooapis.com/v1/public/yql'); 
$url->query_form( q => $yql, photoset => $opts{'photoset_id'}, format => 'json', callback => '' );

my $ua = LWP::UserAgent->new;
$ua->agent($opts{'app_name'} . ' ');
$ua->from($opts{'admin_email'});
$ua->timeout(10);
my $response = $ua->get($url->canonical);

if($response->code != 200) {
	die 'YQL said ' . $response->code . "\n";
}

my $json = new JSON;
$json->utf8();
my $flickr_strips = $json->decode($response->content);
$flickr_strips = $flickr_strips->{'query'}{'results'}{'photo'};

# 3. find first flickr item greater than last db item
my $start_index=0;
if(scalar @$db_strips) {
	my $last_id = $db_strips->{'id'};

	for( ; $start_index < @$flickr_strips && $flickr_strips->[$start_index]{'id'} != $last_id; $start_index++) {
		;
	}
	$start_index++;
}
if($start_index < @$flickr_strips) {
	@$flickr_strips = @{$flickr_strips->[$start_index..$#$flickr_strips]};
}

# 4. fetch additional info for each photo not in db

# 5. store new photos in db
