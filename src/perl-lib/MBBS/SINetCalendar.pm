package MBBS::SINetCalendar;

use strict;
use warnings;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;
use URL::Encode qw( url_encode );

our $VERSION = '1.00';

our $LOGIN_URL = 'https://www.sinet.uq.edu.au/ps/uqsinetsignin.html';
our $TIMETABLE_URL = 'https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/HRMS/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL?&STRM=6820&FolderPath=PORTAL_ROOT_OBJECT.UQ_MYSINET.UQ_MYSINET_TIMETABLE.UQMY_TM_TBL_ICAL_GBL&IsFolder=false&IgnoreParamTempl=FolderPath%2cIsFolder&PortalActualURL=https%3a%2f%2fwww.sinet.uq.edu.au%2fpsc%2fps%2fEMPLOYEE%2fHRMS%2fc%2fUQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL%3f%26STRM%3d6820&PortalContentURL=https%3a%2f%2fwww.sinet.uq.edu.au%2fpsc%2fps%2fEMPLOYEE%2fHRMS%2fc%2fUQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL&PortalContentProvider=HRMS&PortalCRefLabel=Timetable%20iCalendar%20Download&PortalRegistryName=EMPLOYEE&PortalServletURI=https%3a%2f%2fwww.sinet.uq.edu.au%2fpsp%2fps%2f&PortalURI=https%3a%2f%2fwww.sinet.uq.edu.au%2fpsc%2fps%2f&PortalHostNode=HRMS&NoCrumbs=yes&PortalKeyStruct=yes';

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

    # TODO - figure this out later
    if ($month <= 6) {
        # Semester 1
    } else {
        # Semester 2
    }

	#
	# Get timetable
	#
    $mech->get($TIMETABLE_URL);
    $mech->form_id('UQMY_TM_TBL_ICAL');
    # Get out the ICSSID
    my $icsid = $mech->value('ICSID');
    my $icsidenc = url_encode $icsid;

    my $postcontent = "ICAJAX=1&ICNAVTYPEDROPDOWN=0&ICType=Panel&ICElementNum=0&ICStateNum=1&ICAction=UQ_ICAL_EXP_DRV_UQ_ICAL_DOWNLOAD&ICXPos=0&ICYPos=0&ResponsetoDiffFrame=-1&TargetFrameName=None&FacetPath=None&ICFocus=&ICSaveWarningFilter=0&ICChanged=0&ICAutoSave=0&ICResubmit=0&ICSID=$icsidenc&ICActionPrompt=false&ICBcDomData=UnknownValue&ICPanelName=&ICFind=&ICAddCount=&ICAPPCLSDATA=&ptus_defaultlocalnode=PSFT_HR&ptus_dbname=SA90PROD&ptus_portal=EMPLOYEE&ptus_node=HRMS&ptus_workcenterid=&ptus_componenturl=https%3A%2F%2Fwww.sinet.uq.edu.au%2Fpsp%2Fps%2FEMPLOYEE%2FHRMS%2Fc%2FUQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL";
    $mech->post('https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/HRMS/c/UQMY_STUDENT.UQMY_TM_TBL_ICAL.GBL', content => $postcontent);

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
			      "\n" . 'X-WR-CALNAME:MBBS Timetable';
		}
		if ($fixed_ical ne '') {
			$fixed_ical .= "\n" . $_;
		} else {
			$fixed_ical = $_;
		}
	}

	return $fixed_ical;
}
