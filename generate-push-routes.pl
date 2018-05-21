#!/usr/local/bin/perl

use strict;
use warnings;

# Getopt::Long::Descriptive - 
#    Getopt::Long, but simpler and more powerful
# http://search.cpan.org/~rjbs/Getopt-Long-Descriptive-0.097/lib/Getopt/Long/Descriptive.pm

#
# I find that the Descriptive is cleaner to read, and 
# also self documenting on usage()
#

use Getopt::Long::Descriptive;
use Data::Dumper::Simple;
use JSON;
use Net::IP;
use Net::IPv4Addr qw( :all );
use POSIX qw(strftime);

# Type declarations are '=x' or ':x', 
# where = means a value is required and : means it is optional.
# x may be 's' to indicate a string is required, 
# 'i' for an integer, or 'f' for a number with a fractional part. 
# The type spec may end in @ to indicate that the option may 
# appear multiple times.


my ($opt, $usage) = describe_options(
	'%c %o',
	[ 'help|h', "help, print usage", ],
	[ 'config|c=s', "openVPN config", {required => 1},   ], 
	[ 'routes|r=s@', "Additional Local Routes"  ], 
	[ 'verbose|v', "Verbose"  ], 
	[ 'update|u', "Update the OpenVPN configuration as specificed above."  ], 
	[ 'restart', "Update the OpenVPN configuration as specificed above."  ], 
	[ 'reload', "Update the OpenVPN configuration as specificed above."  ], 
	
# FIXME: I haven't been able to figure out the syntax for multiple times.
#	[ 'debug|d:@', "file to copy",  ],
);


print($usage->text), exit if $opt->help;

my $buffer;
my $filename = $opt->{'config'};
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($filename);
open FH, "<$filename";
read (FH,$buffer,$size);
close FH;

my $config = '';
my %config_routes;

foreach my $l ( split (/\n/, $buffer) ) 
{

    if ( $l =~ m/^push "route/ ) {
        $l =~ s/"//g;
        my @p = split ( / /,  $l );
        my $ip1 = new Net::IP ($p[2]);
        if ( $ip1->version == 4 ) {
            my ($i,$cidr) = ipv4_parse ($p[2],$p[3]); 
            my $ip = new Net::IP ($i . "/" . $cidr );
            $config_routes{"v4"}{$ip->{'ip'} . "/" . $ip->{'prefixlen'}} = 1;
        }
    } else {
        $config .= $l . "\n";    
    }
    
}

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

foreach my $r ( @{$opt->{'routes'}} ) {
    my $ip = new Net::IP ($r);
    my $iv = "v" . $ip->version();
    $routes{$iv}{$ip->{'ip'} . "/" . $ip->{'prefixlen'}} = 1;
}

my @v4_r = sort keys(%{$routes{'v4'}});
my @v4_rc =sort keys(%{$config_routes{'v4'}});
my $update = 0;

foreach my $r ( @v4_r ) {
    if ( ! ( defined ($config_routes{'v4'}{$r})  &&  $config_routes{'v4'}{$r} ) ) 
    {
        printf ( " ===> [ ADD ] %s \n" , $r );
        $config_routes{'v4'}{$r} = 1;
        $update = 1;
    }
}
foreach my $r ( @v4_rc ) {
    if ( ! ( defined ($routes{'v4'}{$r})  &&  $routes{'v4'}{$r} ) ) 
    {
        printf ( " ===> [ DEL ] %s \n" , $r );
       delete $config_routes{'v4'}{$r};
       $update = 1;
    }
}


#print Dumper (%routes) if ($opt->{'verbose'});
#print Dumper (%config_routes) if ($opt->{'verbose'});

@v4_r = sort keys(%{$routes{'v4'}});
@v4_rc =sort keys(%{$config_routes{'v4'}});

#print Dumper (@v4_r) if ($opt->{'verbose'});
#print Dumper (@v4_rc) if ($opt->{'verbose'});

foreach my $r ( @v4_rc ) {
    my $ip = new Net::IP ($r);
    $config .= "push \"route " . $ip->ip() ." " . $ip->mask() . "\"\n"
}

if ( $update ) {
    print STDERR " [WARN] OpenVPN Routes need to be updated\n";
    if ( $opt->{'update'} ) 
    {
        my $time = strftime "%Y%m%d-%H%M%S", gmtime;
        printf ( " %s %s \n", $opt->{'config'}, $time );
        my $filebak = $opt->{'config'} . "." . $time;
        `mv $opt->{'config'} $filebak`;
        open FH, ">" .  $opt->{'config'};
        print FH $config;
        print FH "\n";
        close FH;
        print `diff -u $filebak $opt->{'config'}`;        
        if (  $opt->{'restart'} ) {
            system ("/usr/local/etc/rc.d/openvpn restart");
        } elsif (  $opt->{'reload'} ) {
            system ("/usr/local/etc/rc.d/openvpn reload");        
        }
    }
    exit 1; 
} else {
    print STDERR " [OK] No OpenVPN Route changes needed.\n";
    exit 0;
}


