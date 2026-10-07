# Final Report: MariaDB GTID-Based Replication Cluster

---

## 1. Executive Summary
This project involved designing, configuring, testing, and documenting a three-node MariaDB GTID replication cluster. The work focused on understanding GTID-based replication, validating replication behavior during different failure conditions, and testing a backup and restore strategy. 

The testing demonstrated that GTID replication simplifies recovery by allowing replicas to track transaction positions logically, rather than relying on brittle binary log file/position coordinates. It also identified critical operational boundaries around primary failure, network connectivity, GTID divergence, and logical backup restoration.

---

## 2. Cluster Architecture

The test environment consisted of three MariaDB 11.4.13 nodes running in Docker, connected via a dedicated bridge network.

```mermaid
graph TD
    subgraph Docker Network: mariadb-cluster-net (172.19.0.0/16)
        Node1["👑 Primary (mariadb-node1)<br/>IP: 172.19.0.2<br/>Server ID: 1<br/>GTID: 0-1-7"]
        Node2["📥 Replica 1 (mariadb-node2)<br/>IP: 172.19.0.3<br/>Server ID: 2<br/>GTID: 0-1-7"]
        Node3["📥 Replica 2 (mariadb-node3)<br/>IP: 172.19.0.4<br/>Server ID: 3<br/>GTID: 0-1-7"]
    end

    Node1 -- "GTID Stream (Domain 0)<br/>MASTER_USE_GTID=slave_pos" --> Node2
    Node1 -- "GTID Stream (Domain 0)<br/>MASTER_USE_GTID=slave_pos" --> Node3
    
    style Node1 fill:#d4edda,stroke:#28a745,stroke-width:2px
    style Node2 fill:#cce5ff,stroke:#007bff,stroke-width:2px
    style Node3 fill:#cce5ff,stroke:#007bff,stroke-width:2px