package MBBS::Authen;

use strict;
use warnings;

use autodie;
use File::stat; 
use Crypt::SaltedHash;

use MBBS::DB;

######
# Firstly, we hook into apache2
use Apache2::Connection ();
use Apache2::RequestRec ();
use Apache2::Access ();
use Apache2::Const;

our $ICS_PATH = "/opt/mbbscalendar/ics/";
our $MAX_FILE_AGE = 60*60*3; # 3 hours

sub handler {

	my $r = shift;

        unless ($r->some_auth_required) {
                $r->log_reason("No authentication has been configured");
                return Apache2::Const::FORBIDDEN;
        }

	# get user's authentication credentials
        my ($res, $sent_pw) = $r->get_basic_auth_pw;
        return $res if $res != Apache2::Const::OK;
        my $user = $r->user;


	# OK, so here we pretend that the auth is successful
	# if we've never seen them before, and return
	# AUTH_REQUIRED later in the request cycle.
	my $dbh = MBBS::DB->connect();

	my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
	$csh->add($sent_pw);
	my $salted = $csh->generate;

	my $ICS_FILE = $ICS_PATH . $user . ".ics";
	if (-e $ICS_FILE && (time - stat($ICS_FILE)->mtime) < $MAX_FILE_AGE) {
		# We've seen the user before, so we just check username and password
		my $sth = $dbh->prepare("SELECT password FROM users WHERE username=?");
		$sth->execute($user);
		my $stored_hash = $sth->fetchrow_array();

		unless (Crypt::SaltedHash->validate($stored_hash, $sent_pw)) {
			$r->note_basic_auth_failure;
			return Apache2::Const::AUTH_REQUIRED;
		}
	} else {
		# Update the stored credentials for later.
		my $sth = $dbh->prepare("DELETE FROM users WHERE username=?");
		$sth->execute($user);

		$sth = $dbh->prepare("INSERT INTO users(username, password) VALUES(?,?)");
		$sth->execute($user, $salted) or die "Couldn't write to database";
	}
	return Apache2::Const::OK;
	

}

1;
