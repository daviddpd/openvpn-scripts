# openvpn-scripts

## Scripts for Importing dynamic routes and authentication to LDAP to OpenVPN on FreeBSD

### auth

openvpn-auth-ldap seemed to not work, and hasn't been maintained.  pfSense seemed to use 
external scripts.  

#### ldapauth.sh

basic script I was using to auth using `ldapwhoami`.  However this passes the password as 
plain text on the command line, so it could get exposed in process listing.

#### ldapauth.pl

A simple ldap auth script using cpan module Authen::Simple::LDAP. All LDAP options passed in on 
the command line ... newlines in for readability ... don't this is valid openvpn config syntax.

```
auth-user-pass-verify \
    "${PATH}/openvpn-scripts/ldapauth.pl \
    --uri=ldaps://ldap.example.com:636   \
    --binddn=uid=admin                   \
    --basedn=ou=people,dc=example,dc=com \
    --bindpw=xxxx"                       \
    via-env                              \

```

### ovpn.pl

And OpenVPN  `--client-connect` and `client-disconnect` script that allow giving clients 
dynamic routes - who's upstream may be OSPF or BGP or any other routing protocol that inserts
the routes into the kernel's table.

Super simple, openvpn.conf is :

```
client-connect "${PATH}/openvpn-scripts/ovpn.pl --connect "
client-disconnect "${PATH}/openvpn-scripts/ovpn.pl --disconnect "
```

For some reason, the `--ifconfig_pool_remote_ip` is not always set correctly on 
servers routing table (in topology=subnet).  So, this script's main goal was to set that.

In addition, it was convient to push the routes here as well, solving the restart/reload 
problem.

### generate-push-routes.pl

This script, reads in the OpenVPN configuration files, passes through all lines, and parses
the `push "route ..`, and then parses the routing table (highly dependent on --libxo from netstat,
so likely non-portable, and FreeBSD only).

Here is an example usage.

```
> sudo ./generate-push-routes.pl -c /usr/local/etc/openvpn/server1.conf --route 10.231.8.0/21
 [OK] No OpenVPN Route changes needed.

```

Using `--update` will back up the specified config, and generate a new one, and display
the unified diff. `--restart` and `--reload` will actually apply the changes, however, these
are fairly ungraceful.

This was used to develop the idea, then later discovered the dynamic client configs that are 
possible with `--client-connect` and `client-disconnect`, so this is here mainly for reference
and later for testing getting v6 routes.


