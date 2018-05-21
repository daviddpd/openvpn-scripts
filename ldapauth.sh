#!/bin/sh
uri=$1
basedn=$2
username=`echo $username | sed -e 's/@.*$//g'`
ldapwhoami -H ${uri} -w "${password}" -D uid=${username},${basedn}
