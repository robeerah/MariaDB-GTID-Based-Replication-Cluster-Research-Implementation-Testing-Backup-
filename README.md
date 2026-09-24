# MariaDB GTID Replication: Internal Research & Concepts

**Author:** Rofiat Ahmed Sholagberu

**Date:** September 23, 2026

**DevOps Intern**

## 1. Executive Summary
This document outlines the theoretical foundations of MariaDB's Global Transaction Identifier (GTID) based replication. It is intended to provide the DevOps and Engineering teams with a clear understanding of how GTIDs work, how they differ from legacy replication, and how to configure them safely for our upcoming cluster implementation.

## 2. What is a GTID and Why Do We Use It?
Historically, database replication relied on tracking binary log file names and byte positions (e.g., `mysql-bin.000003`, position `1540`). This approach made failovers and crash recoveries highly complex, as calculating exactly where a replica left off was error-prone.

**GTID (Global Transaction Identifier)** solves this by assigning a unique, globally identifiable ID to every single transaction committed on the primary server. 
*   **The Benefit:** Replicas no longer track file positions; they track GTIDs. If a replica restarts, it simply tells the primary, "I have everything up to GTID X." This makes automated failovers, crash recovery, and consistency checks vastly simpler and more reliable.

## 3. Anatomy of a MariaDB GTID
A MariaDB GTID is structured as a three-part string: 
`domain_id-server_id-sequence_number` *(Example: `0-1234-56789`)*

*   **`domain_id`**: Identifies the replication domain (usually `0` for standard setups).
*   **`server_id`**: The unique integer ID of the server that *originally generated* the transaction.
*   **`sequence_number`**: A sequential counter maintained by the originating server for its own transactions.

## 4. Internal State Tracking
To manage replication, a MariaDB server tracks its state using specific system variables. Because a server can act as both a replica (receiving data) and a primary (sending data), tracking more than one value is critical:

*   **`gtid_binlog_pos`**: The highest GTID written to this server's *own* binary log (transactions it generated).
*   **`gtid_slave_pos`**: The highest GTID *applied* from an upstream primary (transactions it received).
*   **`gtid_current_pos`**: The maximum of the two above. 

*Why this matters:* If our primary fails, we look at a replica's `gtid_slave_pos` to see what it received, and `gtid_binlog_pos` to see what it generated. This combined state ensures we can promote the replica to primary without losing transactions.

## 5. Understanding "Domains"
The `domain_id` (the first part of the GTID) defaults to `0`. However, MariaDB supports multiple domains.
*   **When to use them:** Multiple domains are utilized in advanced topologies, such as **Multi-Master replication** or when using routing proxies like MariaDB MaxScale. 
*   **Why:** If two separate masters are writing to a cluster, assigning them to different domains (e.g., Domain 1 and Domain 2) keeps their sequence numbers isolated. This prevents sequence collisions and simplifies conflict resolution.

## 6. Strict vs. Non-Strict GTID Handling
Controlled by the `gtid_strict_mode` variable (which is OFF by default for backward compatibility), this dictates how a replica handles anomalous GTIDs.

*   **Non-Strict (OFF):** If an event creates an out-of-order or duplicate sequence number, MariaDB tolerates it and executes it anyway.
*   **Strict (ON):** The same event stops replication immediately with an explicit error naming the conflicting GTID.

**Important Clarifications:**
1.  **Not a Security Feature:** Strict mode should not be thought of as a general security mode. It is strictly a **consistency and ordering safeguard** to detect anomalous GTID sequences (e.g., from redundant replication paths).
2.  **The MySQL Difference:** MySQL handles this differently by design. If MySQL encounters an already-applied GTID, it *silently skips* it. MariaDB's strict mode *raises an explicit error*. We prefer MariaDB's approach because it converts "silent divergence discovered weeks later" into "replication halts right now with a clear error."

## 7. Comparison: MariaDB vs. MySQL GTID
While both databases use GTIDs to solve the same replication-tracking problem, **they are NOT interchangeable.**

| Feature | MariaDB GTID | MySQL GTID |
| :--- | :--- | :--- |
| **Format** | `domain-server-sequence` (e.g., `0-1-45`) | `UUID:transaction_id` (e.g., `3E11FA...:23`) |
| **Server ID Type**| Plain Integer | Universally Unique Identifier (UUID) |
| **Data Types** | Domain (32-bit int), Server (int), Sequence (64-bit int) | UUID string + Integer |
| **Setup** | Enabled automatically | Requires explicit `gtid_mode=ON` configuration |

**The Asymmetric Compatibility Rule:**
It is worth noting that while *GTID formats* are strictly incompatible, standard binary log replication has an asymmetric relationship: a MariaDB server *can* replicate from a MySQL primary using standard file/position tracking, but a MySQL server *cannot* replicate from a MariaDB primary. However, when using **GTID-based replication**, the two are completely incompatible and cannot be mixed.

## 8. How GTID Supports Failover and Recovery
GTID is particularly useful when a replication topology changes. Because replication progress is represented through logical transaction identifiers rather than physical binary-log coordinates, an administrator can easily reason about which transactions a server has already processed.

**Simplified Recovery Flow:**
1. Primary fails / topology changes.
2. Choose a new replication source (e.g., promote a replica).
3. Use the replica's `gtid_current_pos` to determine exactly which transactions it lacks.
4. Resume replication seamlessly without manual log file hunting.

*Note: GTID enables transaction-level reasoning for recovery, but it does not automatically provide High Availability (HA). Topology, monitoring, and promotion logic (like MaxScale or Keepalived) are still required.*

## 9. References & Citations
*   [MariaDB Official Documentation: GTID](https://mariadb.com/kb/en/gtid/)
*   [MariaDB Official Documentation: gtid_strict_mode](https://mariadb.com/kb/en/gtid/#gtid_strict_mode)
*   [MariaDB vs MySQL Replication Differences](https://mariadb.com/kb/en/differences-in-mariadb-and-mysql/)