#!/usr/local/bin/perl 
#use strict;
#use warnings;

use Authen::Simple::LDAP;
use Getopt::Long::Descriptive;

my ($opt, $usage) = describe_options(
	'%c %o',
	[ 'help|h', "help, print usage", ],
	[ 'uri=s', "ldap server uri ", {required => 1},   ], 
	[ 'basedn=s', "Base DN"  ], 
	[ 'binddn=s', "Bind DN"  ], 
	[ 'bindpw=s', "Bind PW"  ], 
	[ 'username=s', "Username to auth"  ], 
	[ 'password=s', "Password to auth"  ], 
	
);

my $username = $ENV{'username'} || $opt->{'username'};
my $password = $ENV{'password'} || $opt->{'password'};

$username =~ s/@.*$//g;

my $ldap = Authen::Simple::LDAP->new(
    host    => $opt->{'uri'},
    basedn  => $opt->{'basedn'},
    binddn  => $opt->{'binddn'},
    bindpw => $opt->{'bindpw'},
);

if ( $ldap->authenticate( $username, $password ) ) {
	print STDERR "[OK] $username\n";
	exit(0);
} else {
	print STDERR "[ERR] $username\n";
	exit(1);
}

