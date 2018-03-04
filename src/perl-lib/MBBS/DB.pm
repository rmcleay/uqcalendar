package MBBS::DB;

use strict;
use warnings;

use DBI;

#Database related constants
my $database="mbbscalendar.sqlite";
my $database_server="";
my $database_server_type="SQLite";
my $database_user_id="";
my $database_password=""; 

use DBI;
use strict;
use vars qw/$connected $dbh/;

#Database Functions
sub connect
{
	return $dbh if ($connected && $dbh->ping);
	$dbh = DBI->connect("DBI:$database_server_type:$database:$database_server", $database_user_id, $database_password) or die;
	#$dbh->{PrintError} = 0;
	$connected = 1;
	return $dbh;
}

sub disconnect
{
	if($connected == 1) {
		$connected = 0;
		if ($dbh->ping) {
			$dbh->disconnect;
		}
	}
}

1;
