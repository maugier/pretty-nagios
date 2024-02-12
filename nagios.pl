#!/usr/bin/perl

use strict;
use Term::ANSIColor;
use Data::Dumper;

my %hosts;

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

sub parse_file {
	while(<>) {
		&parse_host if /hoststatus\s[{]/;
		&parse_service if /servicestatus\s[{]/;
	}
}

sub parse_host {
	my $host;
	while(<>) {
		last if /}/;
		$host->{name} = $1 if /host_name=(\w+)/;
		$host->{state} = $1 if /current_state=(\d+)/;
	}
	$hosts{$host->{name}} = $host;
}

sub parse_service {
	my $srv;
	while(<>) {
		last if /}/;
		$srv->{host} = $1 if /host_name=(\w+)/;
		$srv->{service} = $1 if /service_description=(.*)/;
		$srv->{state} = $1 if /current_state=(\d+)/;
		$srv->{checked} = $1 if /has_been_checked=(\d+)/;
		$srv->{output} = $1 if /[^_]plugin_output=(.*)/;
	}
	$hosts{$srv->{host}}->{services}{$srv->{service}} = $srv;
}


sub display {

	my $output = '';

	my $host_width = 0;
	my $service_width = 0;

	my $term_columns = `tput cols`;

	for (values %hosts) {
		$host_width = &max($host_width, length $_->{name});
		for (values %{$_->{services}}) {
			$service_width = &max($service_width, length $_->{service});
		}
	}

	my $info_width = $term_columns - $host_width - $service_width - 12;
	
	for (sort { $a->{name} cmp $b->{name} } values %hosts) {
		my $h = $_;
		for (sort { $a->{service} cmp $b->{service} } values %{$_->{services}}) {

			$output .= ' ';
			if (defined $h) {
				$output .= colored( (pack "A$host_width", $h->{name}),
						$h->{state} ? 'bold red' : 'bold green' );
			} else {
				$output .= ' ' x $host_width;
			}
			$output .= ' ';
			$output .= pack "A$service_width", $_->{service};
			$output .= ' ';
			if ($_->{checked} == 0) {
				$output .= colored('[ .... ]', 'bold blue');
			} elsif ($_->{state} == 0) {
				$output .= colored('[  OK  ]', 'bold green');
			} elsif ($_->{state} == 1) {
				$output .= colored('[ WARN ]', 'black on_yellow');
			} elsif ($_->{state} == 2) {
				$output .= colored('[ CRIT ]', 'bold white on_red');
			} elsif ($_->{state} == 3) {
				$output .= colored('[ ???? ]', 'magenta');
			} else {
				$output .= ' UNKNOWN  ';
			}
			$output .= " ";
			$output .= substr($_->{output}, 0, $info_width);
			$output .= "\n";
			undef $h;
		}
	}

	print $output;
}

&parse_file;
$|=0;
&display;
