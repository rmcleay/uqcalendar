package MBBS::SOMCalendar;

use strict;
use warnings;
use WWW::Mechanize;
use Date::Format;
use Date::Parse;

our $VERSION = '1.00';

our $LOGIN_URL = 'https://my.som.uq.edu.au/MBBSTimetable/Login.aspx?ReturnUrl=%2fMBBSTimetable%2fHome.aspx';
our $TIMETABLE_URL = 'https://my.som.uq.edu.au/MBBSTimetable/MyTimetable.aspx';
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
	$mech->agent_alias( 'Windows IE 6' );
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
		'ctl00$ContentPlaceHolderMain$LoginASP$UserName' => $self->{username},
		'ctl00$ContentPlaceHolderMain$LoginASP$Password' => $self->{password},
	);
	$mech->click();
	if ($mech->content =~ m/Your login attempt was not successful./) {
		return 0;
	}
	return 1;
}

sub get_week {
	my ($self, $year, $month, $day) = @_;
	my $mech = $self->{mech};

	#
	# Get timetable
	#
	$mech->get( $TIMETABLE_URL );

	# Format it to match the website
	my $date = str2time("$year-$month-$day");
	my $mbbs_date = time2str("%d %B %Y", $date);

	# Get the correct link for the date
	my $count = 0;
	my $success = 0;
	my $link;
	foreach $link ($mech->find_all_links()) {
		my $attrs = $link->attrs();

		if (defined($$attrs{'title'}) && $$attrs{'title'} eq $mbbs_date) {
			#  This is next week!
			$success = 1;
			last;
		}
		$count++;
	}

	return 0 unless $success;

	# Extract the required form values
	$link = @{$mech->find_all_links()}[$count];
	my $attrs = $link->attrs();
	$$attrs{'href'} =~ m/javascript:__doPostBack\('(.+hrefWeek)',/;
	my $eventTarget = $1;

	# Set the form to send the XML post with the data
	$mech->form_number(1);
	$mech->set_fields('__EVENTTARGET' => $eventTarget);
	$mech->submit();

	#
	# Download the iCal file
	#
	$mech->get($ICAL_URL);

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
