#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

use MBBS::SINetCalendar;

my $USERNAME = shift;
my $PASSWORD = shift;

my $uqcal = MBBS::SINetCalendar->new(username => $USERNAME,
				     password => $PASSWORD);

	unless($uqcal->login()) {
		die "Login failed.";
	}

	# Get calendar
	my $ical = $uqcal->get_semester(2017, 2, 2) or die "Couldn't get calendar.\n";
	
    print $ical;
