package MBBS::AndroidCalendar;

use strict;
use warnings;

use autodie;
use File::stat; 
use Crypt::SaltedHash;
use Crypt::CBC;
use MIME::Base64::URLSafe;
use Date::Calc qw(Today Day_of_Week Add_Delta_Days);

use MBBS::DB;
use MBBS::SINetCalendar;
use MBBS::ICSCalendar qw( download_new_ics );

######
# Firstly, we hook into apache2
use Apache2::Connection;
use Apache2::RequestRec;
use Apache2::Access;
use Apache2::Const;

our $ICS_PATH = "/opt/mbbscalendar/ics/";
our $MAX_FILE_AGE = 60*60*3; # 3 hours

our $BLOWFISH_KEY = 'REPLACEME';

# 
# Subs to handle reversible encryption of usernames and passwords
#
# DO NOT STORE THESE ON THE SERVER SIDE!
#
sub _decrypt {
	my $data = shift;
	my $cipher = Crypt::CBC->new( -key    => $BLOWFISH_KEY,
				      -cipher => 'Blowfish'
		     );
	return $cipher->decrypt_hex($data);
}

sub handler {
	my $r = shift;

	# allow only GET method
	$r->allow_methods(1, qw(GET));

	my $uri = $ENV{'REQUEST_URI'};
	$uri =~ m#/\w+/([^/]+)#;

	my $userpass = _decrypt($1);

	$userpass =~ m/(\w+)\|(.*)/;
	my $USERNAME = $1;
	my $PASSWORD = $2;

	unless (defined($USERNAME) && $USERNAME ne '') {
		return Apache2::Const::NOT_FOUND;
	}
	unless (defined($PASSWORD) && $PASSWORD ne '') {
		return Apache2::Const::NOT_FOUND;
	}

	# Use DB Auth
	my $dbh = MBBS::DB->connect();

	my $ICS_FILE = $ICS_PATH . "$USERNAME.ics";
	# Check if the file doesn't exist or is too old
	# If it's not recent, use UQ for auth.
	if (!-e $ICS_FILE or (-e $ICS_FILE and (time - stat($ICS_FILE)->mtime) >= $MAX_FILE_AGE)) {
		# Download another. This sub will return 0 if auth fails.
		unless(MBBS::ICSCalendar::download_new_ics($USERNAME, $PASSWORD, $ICS_FILE)) {
			return Apache2::Const::NOT_FOUND;
		}
		# Update the stored credentials for later.
		my $sth = $dbh->prepare("DELETE FROM users WHERE username=?");
		$sth->execute($USERNAME);

		my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
		$csh->add($PASSWORD);
		my $salted = $csh->generate;

		$sth = $dbh->prepare("INSERT INTO users(username, password) VALUES(?,?)");
		$sth->execute($USERNAME, $salted) or die "Couldn't write to database";
	} else {
		# We've seen the user before, so we just check username and password
		my $sth = $dbh->prepare("SELECT password FROM users WHERE username=?");
		$sth->execute($USERNAME);
		my $stored_hash = $sth->fetchrow_array();

		unless (Crypt::SaltedHash->validate($stored_hash, $PASSWORD)) {
			return Apache2::Const::NOT_FOUND;
		}
	}

	print "Last-Modified: " . HTTP::Date::time2str(time) . "\n";
	print "Content-Type: text/calendar\n\n";

	open FH, $ICS_FILE;
	while (<FH>) {
		print;
	}
	close FH;

	return Apache2::Const::OK;

}



1;
