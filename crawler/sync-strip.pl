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


my $dbh = DBI->connect("dbi:mysql:$opts{'db_name'}\@$opts{'db_host'}", $opts{'db_user'}, $opts{'db_password'});

# 1. get last 3 from db
my $sql = 'SELECT n, date_posted, id From strip Order by n desc LIMIT 3';
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

# 3. find first flickr item greater than last db item

# 4. fetch additional info for each photo not in db

# 5. store new photos in db