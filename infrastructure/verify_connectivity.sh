#!/bin/bash
# Script to verify TCP 3306 connectivity between all MariaDB nodes

nodes=("mariadb-node1" "mariadb-node2" "mariadb-node3")
echo "Starting Node-to-Node TCP 3306 Connectivity Checks..."
echo "-----------------------------------------------------"

for source in "${nodes[@]}"; do
  for target in "${nodes[@]}"; do
    if [ "$source" != "$target" ]; then
      echo -n "Testing $source -> $target:3306 ... "
      # Attempt to connect using the MariaDB client
      if docker exec $source mysql -h $target -P 3306 -u root -prootpassword123 -e "SELECT 1" > /dev/null 2>&1; then
        echo "PASS"
      else
        echo "FAIL"
      fi
    fi
  done
done
echo "-----------------------------------------------------"
echo "Verification Complete."