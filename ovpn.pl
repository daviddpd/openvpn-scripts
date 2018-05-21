#!/usr/local/bin/perl

use strict;
use warnings;

use Getopt::Long::Descriptive;
use Data::Dumper::Simple;
use JSON;
use Net::IP;
use Net::IPv4Addr qw( :all );
use POSIX qw(strftime);

my ($opt, $usage) = describe_options(
	'%c %o',
	[ 'help|h', "help, print usage", ],
	[ 'connect', "Run the connect setup"  ], 
	[ 'disconnect', "Run the disconnect cleanup" ], 
	
);
my $dev = $ENV{'dev'};
my $ip = $ENV{'ifconfig_pool_remote_ip'};
my $pid = $ENV{'daemon_pid'} || 0;
my $log;

if ( $opt->{'connect'} ) { 
    $log = `route add $ip -iface $dev`;
    if ( -f "$ARGV[0]" ) {
        get_routes ($ARGV[0]);
    }
} elsif ( $opt->{'disconnect'}  ) {
    $log = `route delete $ip -iface $dev`;
} else {
    $log = 'No CLI arguements were given.';
}

`logger -p local0.notice -t "openvpn.opvn[$pid]" "$log"`;


sub get_routes {
    my $dynconf = shift;
    my $config = '';
    my $json_str = `netstat -rn --libxo json`;
    my $json = decode_json($json_str);
    my $r = $json->{'statistics'}->{'route-information'}->{'route-table'}->{'rt-family'};

    my %routes;
    foreach my $af ( @$r ) 
    {
        my $iv = 'n';
        my $afstr = %$af{'address-family'};

            if ( $afstr =~ m/Internet$/ )
            {
                $iv = "v4"; #internet version 
            } elsif ( $afstr =~ m/Internet6$/ ) 
            {
                $iv = "v6"; #internet version 
            }
    
             foreach my $x ( @{$af->{'rt-entry'}} ) 
             {
                foreach my $flag ( @{$x->{'flags_pretty'}} ) {
                    if ( $flag =~ m/proto1/ ) {
                     my $ip = new Net::IP ($x->{'destination'});
                     printf ( " %s %s %s \n", $x->{'interface-name'}, $x->{'destination'}, $ip->mask() )  if ($opt->{'verbose'});
                     $routes{$iv}{$x->{'destination'}} = 1;
                    }
                }
             }
    }
    
    my @v4_r = sort keys(%{$routes{'v4'}});

    foreach my $r ( @v4_r ) {
        my $ip = new Net::IP ($r);
        $config .= "push \"route " . $ip->ip() ." " . $ip->mask() . "\"\n"
    }
    
    open (FH, ">>", $dynconf );
    print FH $config;
    close FH;
    
}