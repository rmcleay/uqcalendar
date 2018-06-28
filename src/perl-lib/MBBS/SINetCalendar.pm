package MBBS::SINetCalendar;

use strict;
use warnings;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use URL::Encode qw( url_encode );

our $VERSION = '1.00';

our $LOGIN_URL = 'https://www.sinet.uq.edu.au/psp/ps/?cmd=login&languageCd=ENG&';
our $TIMETABLE_URL_SEM1 = 'https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/SA/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL?STRM=6820';
our $TIMETABLE_URL_SEM2 = 'https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/SA/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL?STRM=6860';

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
	$mech->agent_alias( 'Mac Safari' );
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
	if ($mech->content =~ m/You may have entered an invalid User ID and.or Password/
     || $mech->content =~ m/User ID and Password are required/) {
		return 0;
	}
	return 1;
}

sub get_semester {
	my ($self, $year, $month, $day) = @_;
	my $mech = $self->{mech};

    my $TIMETABLE_URL;

    # Last day of semester is june 23rd
    if ($month < 6 || ($month == 6 && $day < 23)) {
        # Semester 1
        $TIMETABLE_URL = $TIMETABLE_URL_SEM1;
    } else {
        # Semester 2
        $TIMETABLE_URL = $TIMETABLE_URL_SEM2;
    }

	#
	# Get timetable
	#
    $mech->get($TIMETABLE_URL);
    
    $mech->form_id('UQMY_TM_TBL_ICAL');

    
    # Get out the ICSSID
    my $icsid = $mech->value('ICSID');
    my $icsidenc = url_encode $icsid;

    # They're using javascript to change a whole bunch of
    # form fields that we're just going to set manually.
    # Much cheaper than running a JS interpreter.
    my $postcontent = join '&', map {
        if ($_->name eq 'ICAction') {
           'ICAction=UQ_ICAL_EXP_DRV_UQ_ICAL_DOWNLOAD';
        } else {
            $_->name . '=' . url_encode $_->value;
        }
    } $mech->current_form->inputs;
    $postcontent .= '&ICAJAX=1';

    $mech->post('https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/SA/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL', content => $postcontent);

    $mech->content =~ m/window.open..(.*\.ics)',/;
    my $ics_loc = $1;

    $mech->get($ics_loc);

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
			      "\n" . 'X-WR-CALNAME:UQ Timetable';
		}
		if ($fixed_ical ne '') {
			$fixed_ical .= "\n" . $_;
		} else {
			$fixed_ical = $_;
		}
	}

	return $fixed_ical;
}
