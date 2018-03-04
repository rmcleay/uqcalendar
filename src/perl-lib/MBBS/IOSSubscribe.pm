package MBBS::IOSSubscribe;

use strict;
use warnings;

use autodie;
use File::stat; 
use Crypt::SaltedHash;

use MBBS::DB;
use MBBS::SOMCalendar;

######
# Firstly, we hook into apache2
use Apache2::RequestRec;
use Apache2::Access;
use Apache2::Const;

# Then CGI.pm
use CGI;

our $MOBILECONFIG = "/opt/mbbscalendar/ios.mobileconfig";
our $FAILEDPAGE = "/opt/mbbscalendar/www/ios/form2.html";
our $ICS_PATH = "/opt/mbbscalendar/ics/";
our $MAX_FILE_AGE = 60*60*3; # 3 hours

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

	if (1 == $AUTH_SUCCEEDED) {

		print "Content-type: application/x-apple-aspen-config; chatset=utf-8\n";
		print qq|Content-Disposition: attachment; filename="mbbstimetable.mobileconfig"\n\n|;

		undef $/;
		open FH, $MOBILECONFIG;
		$_ = <FH>;
		s/###INSERTUSERNAME###/$username/;
		s/###INSERTPASSWORD###/$password/;
		print $_;
		close FH;
	} else {
		print "Content-type: text/html\n\n";

		open FH, $FAILEDPAGE;
		while (<FH>) {
			s/###INSERTUSERNAME###/$username/;
			print $_;
		}
		close FH;
	}

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
