#!/bin/bash

#  Copyright 2017 Matt Hanley
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

if echo $* | grep -v -e '--skip-networking' | grep -v -e '--help'; then

  export IP_ADDRESS=`getent hosts | grep $HOSTNAME | awk '{print $1}'`

  echo "Cluster peers:"
  echo `getent hosts tasks.$SERVICE_NAME`

  if [ -n "$SERVICE_NAME" ]; then
    CLUSTER_MEMBERS=`getent hosts tasks.$SERVICE_NAME | grep -v $IP_ADDRESS | awk '{print $1}'`
    # Check we can see enough peers to form a Primary Component
    if [ `getent hosts tasks.$SERVICE_NAME | wc -l` -lt $(((${CLUSTER_NODES}+1)/2)) ]; then
      RESTART_DELAY=$(((1 + $RANDOM % 10)*6))
      echo "Can't see enough peers to form a cluster; restarting in ${RESTART_DELAY} seconds."
      sleep $RESTART_DELAY
      exit 1
    fi
    # If we're the first node then bootstrap the cluster
    if [ `getent hosts tasks.$SERVICE_NAME | sort -V | head -n 1 | awk '{print $1}'` = $IP_ADDRESS ]; then
      echo "Looks like we're the first member. Testing for an established cluster between other nodes..."
      # Check to see if the other nodes have an established cluster
      for MEMBER in $CLUSTER_MEMBERS
      do
        echo "Testing $MEMBER..."
        if echo "SHOW STATUS LIKE 'wsrep_local_state_comment';" | mysql -u root -p$MYSQL_ROOT_PASSWORD -h $MEMBER | grep "Synced"; then
          # Connect to existing cluster
          echo "Success! 😁"
          export CLUSTER_ADDRESS="gcomm://$MEMBER?pc.wait_prim=yes"
          break
        else
          echo "Failed 😫"
        fi
      done
      # Can't connect to any other hosts; we need to bootstrap
      if [ -z $CLUSTER_ADDRESS ]; then
        echo "** No cluster found; bootstrapping on this node **"
        export CLUSTER_ADDRESS="gcomm://"
      fi
    fi

    # Join existing cluster
    if [ -z $CLUSTER_ADDRESS ]; then
      # Fetch IPs of service members
      CLUSTER_MEMBERS=`echo $CLUSTER_MEMBERS | tr ' ' ','`
      export CLUSTER_ADDRESS="gcomm://$CLUSTER_MEMBERS?pc.wait_prim=yes"
      export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
      # Prevent entrypoint trying to (re)create the users
      unset MYSQL_USER
      export MYSQL_ROOT_HOST="localhost"
    fi
  fi

  echo "Cluster address is $CLUSTER_ADDRESS"

  mv /etc/mysql/conf.d/galera.cnf.template /etc/mysql/conf.d/galera.cnf

  echo "`env`" | while IFS='=' read -r NAME VALUE
  do
      sed -i "s#{{${NAME}}}#${VALUE}#g" /etc/mysql/conf.d/galera.cnf
  done

  chmod 660 /etc/mysql/conf.d/galera.cnf

  echo "Running config:"
  echo "==============="
  cat /etc/mysql/conf.d/galera.cnf
  echo "==============="

fi

exec /usr/sbin/mysqld "$@"
