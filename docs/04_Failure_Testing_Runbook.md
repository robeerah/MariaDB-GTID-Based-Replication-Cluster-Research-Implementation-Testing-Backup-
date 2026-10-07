# Subtask 4: Failure Testing & Incident Runbook

## 1. Objective
Validate the resilience of the MariaDB GTID replication cluster under real-world failure conditions. This document records the test scenarios, observed symptoms, recovery procedures, and the resulting incident runbook for operational use.

**Test Environment Baseline:**
*   **Primary:** `mariadb-node1` (Server ID: 1)
*   **Replicas:** `mariadb-node2`, `mariadb-node3` (Server IDs: 2, 3)
*   **Network:** `mariadb-cluster-net` (Docker Bridge)
*   **GTID Mode:** `gtid_strict_mode=ON`, `MASTER_USE_GTID=slave_pos`

---

## 2. Tested Failure Scenarios

### Scenario A: Replica Unexpectedly Stops
*   **Test:** `docker stop mariadb-node2` while the primary continues to accept writes.
*   **Detection:** Container status shows `Exited`. Primary continues to advance its `gtid_current_pos`.
*   **Recovery:** `docker start mariadb-node2`.
*   **Observed Behavior:** Upon restart, the replica automatically reconnected to the primary. Because it was configured with `MASTER_USE_GTID=slave_pos`, it used its stored `gtid_slave_pos` to request only the missing transactions. No manual log coordinate calculation was required.
*   **Recovery Time:** ~65 seconds.
*   **Result:** **PASS** (Successful automatic recovery).

### Scenario B: Primary Unexpectedly Stops
*   **Test:** `docker stop mariadb-node1`.
*   **Detection:** Replicas reported `Slave_IO_Running: Connecting`, `Seconds_Behind_Master: NULL`, and `Last_IO_Error: Can't connect to server`. The `Slave_SQL_Running` thread remained `Yes`, processing any remaining relay logs.
*   **Recovery:** `docker start mariadb-node1`.
*   **Observed Behavior:** Once the primary became available, the replica IO threads automatically reconnected. Because the replicas already knew their last executed GTID position, they seamlessly resumed replication from that exact point.
*   **Recovery Time:** ~102 seconds.
*   **Result:** **PASS** (Successful automatic reconnection).

### Scenario C: Network Isolation (Node Disconnect)
*   **Test:** `docker network disconnect mariadb-cluster-net mariadb-node2` (Database process remains running).
*   **Detection:** `Slave_IO_Running: Connecting`, `Last_IO_Error: Unknown server host`. DNS resolution (`getent hosts`) fails.
*   **Recovery:** 
    1. Restore network: `docker network connect --ip 172.19.0.3 mariadb-cluster-net mariadb-node2`
    2. Reset hung threads: `STOP SLAVE; START SLAVE;`
*   **Observed Behavior:** Unlike a container crash, the database process was healthy, but the IO thread was permanently hung waiting for a timeout. Restarting the replication threads was required to force a fresh DNS/TCP handshake.
*   **Result:** **PASS** (Successful network recovery).

### Scenario D: GTID State Divergence (Strict Mode Validation)
*   **Test:** Isolate `mariadb-node2` from the network, then execute a local write (`CREATE DATABASE divergence_test;`), advancing its `gtid_binlog_pos` independently of its `gtid_slave_pos`. Reconnect and restart replication.
*   **Detection:** `gtid_current_pos` on the replica diverges from the primary's sequence. 
*   **Observed Behavior:** Because `gtid_strict_mode=ON` is enforced, attempting to resume replication with a divergent, locally-generated GTID sequence triggers an explicit replication error rather than silently overwriting or skipping data. 
*   **Result:** **PASS** (Strict mode successfully prevented silent data divergence, flagging the anomaly for controlled reconciliation).

---

## 3. Incident Runbook

Use this runbook for rapid diagnosis and recovery of replication issues.

### A. Replica is Down
1. Check container status: `docker ps --filter "name=mariadb-node"`
2. Restart the replica: `docker start <container_name>`
3. Verify health: 
   ```sql
   SHOW SLAVE STATUS\G
   -- Confirm: Slave_IO_Running: Yes, Slave_SQL_Running: Yes, Seconds_Behind_Master: 0