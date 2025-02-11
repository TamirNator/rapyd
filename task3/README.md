# Troubleshooting & Debugging AWS Connectivity Issues

## 1. Troubleshooting Steps
Follow these steps to identify and resolve connectivity issues:

### ✅ Step 1: Check Application Logs
- Get logs from the failing pod to look for errors:
  ```sh
  kubectl logs <pod-name> -n <namespace>
  ```
- Look for **connection timeout, authentication failures, or DNS resolution issues**.

### ✅ Step 2: Test Connectivity from a Pod
- **Exec into the pod** and run a basic connectivity test:
  ```sh
  kubectl exec -it <pod-name> -- /bin/sh
  ```
- **Test network connectivity to RDS**:
  ```sh
  nc -zv <rds-endpoint> 5432  # PostgreSQL
  ```
  If this fails, it's likely a **network issue**.

### ✅ Step 3: Verify Kubernetes Service & DNS Resolution
- Ensure that the RDS endpoint is **resolving correctly**:
  ```sh
  nslookup <rds-endpoint>
  ```
- If using an **internal VPC endpoint**, check CoreDNS:
  ```sh
  kubectl logs -n kube-system -l k8s-app=kube-dns
  ```

### ✅ Step 4: Check Security Groups & Network ACLs
- Ensure that the **RDS security group** allows traffic from the **EKS worker node security group**:
  - **Inbound Rule (RDS SG)**:
    ```
    Protocol: TCP
    Port: 5432 (PostgreSQL)
    Source: EKS Worker Node SG
    ```
- Check **Network ACLs (NACLs)** to ensure they are not blocking traffic.

### ✅ Step 5: Verify IAM Role Permissions (If Using IAM Authentication)
- If IAM authentication is enabled for RDS:
  ```sh
  aws sts get-caller-identity
  ```
- Ensure the IAM role **attached to the pod** has `rds:Connect` permissions.

### ✅ Step 6: Monitor AWS CloudWatch & VPC Flow Logs
- **CloudWatch Logs for RDS**:
  - Go to **Amazon RDS Console > Logs & Events** and check for connection errors.
- **VPC Flow Logs**:
  - Look at VPC Flow Logs for dropped packets.
  ```sh
  aws ec2 describe-flow-logs --filter Name=resource-id,Values=<vpc-id>
  ```

### ✅ Step 7: Check Database Performance & Connection Limits
- If RDS **is overloaded**, it may refuse new connections.
- Check current connections:
  - **PostgreSQL**:
    ```sql
    SELECT * FROM pg_stat_activity;
    ```
- If too many connections are open, consider **optimizing connection pooling**.

---

## 2. Logs & Metrics to Check
| **Source**              | **What to Look For**                         | **Commands / Tools**            |
|------------------------|---------------------------------|---------------------------------|
| **Kubernetes Pod Logs**  | Connection errors, DNS failures  | `kubectl logs <pod>` |
| **EKS Worker Node Logs** | Network issues, crashes | **CloudWatch Logs** |
| **RDS Logs**  | Connection rejections, timeouts | **RDS Console > Logs** |
| **VPC Flow Logs**  | Dropped traffic, blocked connections | `aws ec2 describe-flow-logs` |
| **Database Connection Limits** | High active connections | `pg_stat_activity` (PostgreSQL), `SHOW PROCESSLIST` (MySQL) |

---

## 3. Improving Resilience
### ✅ Solution 1: Implement Connection Pooling
- **Use a connection pooler** such as **PgBouncer (PostgreSQL)** to reduce the number of direct connections to RDS.

### ✅ Solution 2: Enable Multi-AZ for High Availability
- **Enable Multi-AZ on RDS** to prevent downtime in case of database failover.
- Ensure the application handles **automatic failover** by setting **multiple database endpoints**.


### ✅ Solution 3: Use AWS PrivateLink for Secure & Reliable Connectivity
- **Avoids Public Exposure** by Keeping traffic within AWS without requiring a NAT Gateway.
- **Improves Security** by Ensuring only authorized VPCs can access RDS