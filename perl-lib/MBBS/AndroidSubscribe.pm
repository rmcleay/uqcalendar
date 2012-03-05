package MBBS::AndroidSubscribe;

use strict;
use warnings;

use autodie;
use File::stat; 
use Crypt::SaltedHash;
use Crypt::CBC;
use MIME::Base64::URLSafe;

use MBBS::DB;
use MBBS::SOMCalendar;

######
# Firstly, we hook into apache2
use Apache2::RequestRec;
use Apache2::Access;
use Apache2::Const;

# Then CGI.pm
use CGI;

our $RESULTPAGE = "/opt/mbbscalendar/www/android/result.html";
our $ICS_PATH = "/opt/mbbscalendar/ics/";
our $MAX_FILE_AGE = 60*60*3; # 3 hours

our $BLOWFISH_KEY = 'REPLACEME';

# 
# Subs to handle reversible encryption of usernames and passwords
#
# DO NOT STORE THESE ON THE SERVER SIDE!
#
sub encrypt {
	my $data = shift;
	my $cipher = Crypt::CBC->new( -key    => $BLOWFISH_KEY,
				      -cipher => 'Blowfish'
		     );
	return $cipher->encrypt_hex($data);
}

sub handler {
	my $r = shift;

	my $q = CGI->new;

	# allow only POST method
	$r->allow_methods(1, qw(POST));

	my $AUTH_SUCCEEDED = 0;

	my $username = $q->param('username');
	my $password = $q->param('password');
	my $password2 = $q->param('password2');
		
	if (!defined($username) || $username eq '') {
		$username = '';
	} else {
		$username = lc $username;
	}

	my $ICS_FILE = $ICS_PATH . "$username.ics";
	# Check if the file doesn't exist or is too old
	if ($username eq '' || !defined($password) || !defined($password2) || $password eq '' || $password ne $password2) {
		# We want to skip to the end
		$AUTH_SUCCEEDED = 0;
	} elsif (!-e $ICS_FILE or (-e $ICS_FILE and (time - stat($ICS_FILE)->mtime) >= $MAX_FILE_AGE)) {
		# Check against the SOM
		if (check_auth($username, $password)) {
			$AUTH_SUCCEEDED = 1;
		}
	} else {
		# Check against db
		my $dbh = MBBS::DB->connect();
		# We've seen the user before, so we just check username and password
		my $sth = $dbh->prepare("SELECT password FROM users WHERE username=?");
		$sth->execute($username);
		my $stored_hash = $sth->fetchrow_array();

		if (Crypt::SaltedHash->validate($stored_hash, $password)) {
			$AUTH_SUCCEEDED = 1;
		}
	}

	my $message = '';
	if (1 == $AUTH_SUCCEEDED) {
		my $e_userpass = encrypt("$username|$password");
		$message = "http://mbbscalendar.fearthecow.net/androidcal/$e_userpass/calendar.ics";
	} else {
		$message = 'Either username or password incorrect or passwords did not match.<br>Hit Back and try again.';
	}

	print "Content-type: text/html\n\n";

	open FH, $RESULTPAGE;
	while (<FH>) {
		s/###MESSAGE###/$message/;
		print $_;
	}
	close FH;

	return Apache2::Const::OK;
}



#########################

sub check_auth() {

	my $USERNAME = shift;
	my $PASSWORD = shift;

	my $mbbs = MBBS::SOMCalendar->new(username => $USERNAME,
				     password => $PASSWORD);

	if ($mbbs->login()) {
		return 1; 
	} else {
		return 0;
	}
}

1;
