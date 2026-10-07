# Subtask 3: Configure GTID Replication

## 1. Objective
Configure and validate GTID-based replication for the three-node MariaDB 11.4 cluster provisioned in Subtask 2. This stage establishes the primary/replica roles, applies the necessary configuration, creates a secure replication user, and verifies end-to-end data propagation.

## 2. Cluster Roles
| Node | Role | Server ID |
| :--- | :--- | :--- |
| `mariadb-node1` | Primary | 1 |
| `mariadb-node2` | Replica | 2 |
| `mariadb-node3` | Replica | 3 |

## 3. Configuration Applied
The following configuration was applied to the `[mariadb]` block of the `my.cnf` (or equivalent drop-in config) on all three nodes:

```ini
[mariadb]
server_id=<1, 2, or 3 depending on node>
log_bin=mariadb-bin
gtid_domain_id=0
gtid_strict_mode=ON
log_slave_updates=ON