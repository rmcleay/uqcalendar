package MBBS::SINetCalendar;

use strict;
use warnings;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;

our $VERSION = '1.00';

our $LOGIN_URL = 'https://www.sinet.uq.edu.au/ps/uqsinetsignin.html';
our $TIMETABLE_URL = 'https://www.sinet.uq.edu.au/psp/ps/EMPLOYEE/HRMS/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL?&STRM=6820&FolderPath=PORTAL_ROOT_OBJECT.UQ_MYSINET.UQ_MYSINET_TIMETABLE.UQMY_TM_TBL_ICAL_GBL&IsFolder=false&IgnoreParamTempl=FolderPath%2cIsFolder';
our $ICAL_URL = 'https://my.som.uq.edu.au/MBBSTimetable/CalendarDownload.aspx?calType=ical';

sub new {
	my($class, %args) = @_;

	my $self = bless({}, $class);

	unless (exists($args{username}) and exists($args{password})) {
		return undef;
	}

	# Set user and pass
	$self->{username} = $args{username};
	$self->{password} = $args{password};


	# Create mech obj
	my $mech = WWW::Mechanize->new();
	$mech->agent_alias( 'Windows IE 11' );
	$self->{mech} = $mech;

	return $self;
}

sub login {

	my ($self, undef) = @_;
	my $mech = $self->{mech};

	#
	# Login as user
	#
	$mech->get( $LOGIN_URL );
	$mech->form_number(1);
	$mech->set_fields(
        'userid1' => $self->{username},
		'userid' => uc $self->{username},
        'timezoneOffset' => '-600',
		'pwd' => $self->{password},
	);
	$mech->click();
	if ($mech->content =~ m/You may have entered an invalid User ID and.or Password/) {
		return 0;
	}
	return 1;
}

sub get_semester {
	my ($self, $year, $month, $day) = @_;
	my $mech = $self->{mech};

    # TODO - figure this out later
    if ($month <= 6) {
        # Semester 1
    } else {
        # Semester 2
    }

	#
	# Get timetable
	#
	$mech->get( $TIMETABLE_URL );

	# Format it to match the website
	my $date = str2time("$year-$month-$day");

	# Set the form to send the XML post with the data
	$mech->form_number(1);
	$mech->click('UQ_ICAL_EXP_DRV_UQ_ICAL_DOWNLOAD');

	# The iCal file
	my $ical = $mech->content;

	return 0 if ($ical =~ m/No calendar Info found/);

	return _cleanup_ical($ical);
}

# Fix the broken ical file
sub _cleanup_ical() {
	my $ical = shift;

	my $fixed_ical = '';
	foreach (split("\n", $ical)) {

		if (m/^LOCATION/) {
			s/,/\\,/g;
		} elsif (m/^VERSION/) {
			s/VERSION:1\.0/VERSION:2.0/;
			$_ .= "\n" . 'PRODID:-//FearTheCow.net/MBBS The Ripper V1.1//EN';
			$_ .= "\n" . 'SEQUENCE:' . time;
			$_ .= "\n" . 'METHOD:PUBLISH' .
			      "\n" . 'X-WR-CALNAME:MBBS Timetable';
		} elsif (m/^DESCRIPTION/) {
			s/^DESCRIPTION:/SUMMARY:/;
			s/,/\\,/g;
		} else {
			s/^SUMMARY:/DESCRIPTION:/;
		}
		if ($fixed_ical ne '') {
			$fixed_ical .= "\n" . $_;
		} else {
			$fixed_ical = $_;
		}
	}

	return $fixed_ical;
}
