package MBBS::ICSCalendar;

use strict;
use warnings;

use autodie;
use File::stat; 
use Crypt::SaltedHash;
use Date::Calc qw(Today Day_of_Week Add_Delta_Days);

use MBBS::DB;
use MBBS::SOMCalendar;

######
# Firstly, we hook into apache2
use Apache2::Connection;
use Apache2::RequestRec;
use Apache2::Access;
use Apache2::Const;

our $ICS_PATH = "/opt/mbbscalendar/ics/";
our $MAX_FILE_AGE = 60*60*3; # 3 hours

sub handler {
	my $r = shift;

	# allow only GET method
	$r->allow_methods(1, qw(GET));

	my $USERNAME = $r->user;
	my ($res, $PASSWORD) = $r->get_basic_auth_pw;

	my $ICS_FILE = $ICS_PATH . "$USERNAME.ics";
	# Check if the file doesn't exist or is too old
	if (!-e $ICS_FILE or (-e $ICS_FILE and (time - stat($ICS_FILE)->mtime) >= $MAX_FILE_AGE)) {
		# Download another. This sub will return 0 if auth fails.
		unless(download_new_ics($USERNAME, $PASSWORD, $ICS_FILE)) {
			$r->note_basic_auth_failure();
			return Apache2::Const::AUTH_REQUIRED;
		}
	} 

	print "Content-type: text/calendar\n";
	print "Content-Disposition: inline; filename=calendar.ics\n\n";

	open FH, $ICS_FILE;
	while (<FH>) {
		print;
	}
	close FH;

	return Apache2::Const::OK;

}



#########################

sub download_new_ics {

	my $USERNAME = shift;
	my $PASSWORD = shift;
	my $ICS_FILE = shift;


	my $uqcal = MBBS::SINetCalendar->new(username => $USERNAME,
				     password => $PASSWORD);

	unless($uqcal->login()) {
		return 0; 
	}

	# Get today's date
	my ($year, $month, $day) = Today();

	# Get calendar
	my $ical = $uqcal->get_semester($year, $month, $day) or die "Couldn't get last week's calendar.\n";
	
	open WH, ">$ICS_FILE";
    print WH $ical;
	close WH;

	return 1;
}

1;
