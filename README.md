# Java Application Deployment on Secured AWS VPC

> A production-style AWS infrastructure project deploying a Java-based application inside a secured custom VPC with subnet isolation, Auto Scaling, Application Load Balancer, Bastion Host access, and NAT Gateway.

---

## Architecture Overview

```
                        Internet / Users
                               │
                    ┌──────────▼──────────┐
                    │  Application Load   │
                    │  Balancer (Public)  │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │           VPC: vpc-cloud-security-vpc         │
        │              CIDR: 10.0.0.0/16               │
        │                                               │
        │  ┌─────────── Public Subnets ──────────────┐ │
        │  │  AZ: us-east-1a          us-east-1b     │ │
        │  │  ┌──────────────┐   ┌───────────────┐   │ │
        │  │  │     ALB      │   │ Bastion Host  │   │ │
        │  │  └──────────────┘   └───────────────┘   │ │
        │  │         NAT Gateway (Public Subnet)      │ │
        │  └─────────────────────────────────────────┘ │
        │                     │ SSH                     │
        │  ┌────────── Private Subnets ──────────────┐ │
        │  │  AZ: us-east-1a          us-east-1b     │ │
        │  │  ┌──────────────┐   ┌───────────────┐   │ │
        │  │  │   EC2 (Java) │   │  EC2 (Java)   │   │ │
        │  │  │  10.0.141.35 │   │  10.0.145.139 │   │ │
        │  │  └──────────────┘   └───────────────┘   │ │
        │  └─────────────────────────────────────────┘ │
        └───────────────────────────────────────────────┘
```

---

## Project Highlights

- Custom VPC with **4 subnets** across **2 Availability Zones** (us-east-1a & us-east-1b)
- **EC2 instances in private subnets only** — not directly reachable from the internet
- **Application Load Balancer** in public subnets as the single public-facing entry point
- **Bastion Host** for secure SSH jump-server access to private EC2 instances
- **NAT Gateway** enables outbound internet access for private instances (for updates/patches)
- **Auto Scaling Group** (`vpc-cloud-security`) with desired capacity of 2, scaling limits 1–4
- **Security Groups** restrict traffic at the instance level
- **Launch Template** (`vpc-cloud-security`) using AMI `ami-04680790a315cd58d` on `t2.micro`

---

## AWS Services Used

| Service | Name / ID | Purpose |
|---|---|---|
| VPC | `vpc-cloud-security-vpc` | Isolated network — CIDR 10.0.0.0/16 |
| Public Subnet 1 | `vpc-cloud-security-subnet-public1-us-east-1a` | ALB, Bastion Host |
| Public Subnet 2 | `vpc-cloud-security-subnet-public2-us-east-1b` | NAT Gateway |
| Private Subnet 1 | `vpc-cloud-security-subnet-private1-us-east-1a` | EC2 Java App instances |
| Private Subnet 2 | `vpc-cloud-security-subnet-private2-us-east-1b` | EC2 Java App instances |
| Internet Gateway | `vpc-cloud-security-igw` | Public internet access |
| NAT Gateway | `vpc-cloud-security-nat-public1-us-east-1` | Outbound internet for private subnets |
| Route Tables | 4 route tables (2 private, 1 public, 1 main) | Subnet traffic routing |
| EC2 Launch Template | `vpc-cloud-security` (`lt-0177dac044241ddb5`) | Standard config for all app instances |
| Auto Scaling Group | `vpc-cloud-security` | Automatically manages EC2 fleet |
| Application Load Balancer | Public subnets | Distributes HTTP traffic to private EC2s |
| Bastion Host | Public subnet | SSH jump-server for secure access |
| Security Group | `sg-0e646c48184b85155` | Inbound: TCP 8000 (app), SSH port 22 |

---

## Security Architecture

### Defense in Depth

```
Internet
   │
   ▼
[ALB Security Group]  — allows HTTP/HTTPS from 0.0.0.0/0
   │
   ▼
[EC2 Security Group: sg-0e646c48184b85155]
   ├── Inbound: TCP port 8000 from ALB SG only
   └── Inbound: SSH port 22 from Bastion SG only (sg-06fae327dca987777)

[Bastion Host Security Group: sg-06fae327dca987777]
   └── Inbound: SSH port 22 from trusted IP only
```

### Key Security Decisions

- EC2 instances have **no public IP** — private IPs only (`10.0.141.35`, `10.0.145.139`)
- SSH to private EC2s is done through the **Bastion Host** using key pair `aws-ec2`
- EC2 security group allows SSH **only from the Bastion's Security Group** (not open internet)
- App traffic on port 8000 is accessible only via the ALB
- NAT Gateway provides **one-way outbound** internet access (no inbound allowed)

---

## Infrastructure Details

### VPC Configuration

| Property | Value |
|---|---|
| VPC ID | `vpc-0509359afe57fd683` |
| Name | `vpc-cloud-security-vpc` |
| IPv4 CIDR | `10.0.0.0/16` |
| DNS Hostnames | Enabled |
| DNS Resolution | Enabled |
| Region | `us-east-1` (N. Virginia) |

### EC2 Launch Template

| Property | Value |
|---|---|
| Template ID | `lt-0177dac044241ddb5` |
| Name | `vpc-cloud-security` |
| AMI | `ami-04680790a315cd58d` |
| Instance Type | `t2.micro` |
| Key Pair | `aws-ec2` |
| Security Group | `sg-0e646c48184b85155` |

### Auto Scaling Group

| Property | Value |
|---|---|
| Group Name | `vpc-cloud-security` |
| Desired Capacity | 2 |
| Scaling Limits | Min: 1 / Max: 4 |
| Subnets | `subnet-046db9a5e4b052b3d` (AZ-1a), `subnet-0b3c699b449787955` (AZ-1b) |
| AZ Distribution | Balanced best effort |

---

## Deployment Steps

### 1. Create the VPC

```bash
# Done via AWS Console VPC Wizard
# - VPC name: vpc-cloud-security-vpc
# - CIDR: 10.0.0.0/16
# - 2 Public Subnets (us-east-1a, us-east-1b)
# - 2 Private Subnets (us-east-1a, us-east-1b)
# - 1 NAT Gateway
# - Internet Gateway auto-attached
```

### 2. Create Security Groups

```bash
# EC2 Security Group (sg-0e646c48184b85155)
# Inbound rules:
#   - TCP 8000 from 0.0.0.0/0     (application traffic)
#   - TCP 22 (SSH) from Bastion SG (sg-06fae327dca987777)

# Bastion Security Group (sg-06fae327dca987777)
# Inbound rules:
#   - TCP 22 (SSH) from your IP
```

### 3. Create Launch Template

```bash
# Name: vpc-cloud-security
# AMI: ami-04680790a315cd58d
# Instance type: t2.micro
# Key pair: aws-ec2
# Security group: sg-0e646c48184b85155
```

### 4. Create Auto Scaling Group

```bash
# Uses launch template: vpc-cloud-security
# VPC: vpc-cloud-security-vpc
# Subnets: Private subnet AZ-1a + Private subnet AZ-1b
# Desired: 2 | Min: 1 | Max: 4
```

### 5. Launch Bastion Host

```bash
# Instance in public subnet
# Public IP: 174.129.44.62
# Security group allows SSH from your IP only
```

### 6. SSH Access via Bastion (Jump Server)

```bash
# Step 1: Copy PEM key to Bastion Host
scp -i aws-ec2.pem aws-ec2.pem ubuntu@174.129.44.62:/home/ubuntu

# Step 2: SSH into Bastion
ssh -i aws-ec2.pem ubuntu@174.129.44.62

# Step 3: From Bastion, SSH into private EC2
ssh -i aws-ec2.pem ubuntu@10.0.145.139
```

### 7. Deploy Java Application

```bash
# On the private EC2 instance:
sudo apt update
sudo apt install openjdk-17-jdk -y

# Transfer JAR file from Bastion to private EC2
scp -i aws-ec2.pem app.jar ubuntu@10.0.145.139:/home/ubuntu/

# Run the application
java -jar app.jar --server.port=8000
```

---

## Troubleshooting Notes

| Issue | Root Cause | Fix Applied |
|---|---|---|
| Auto Scaling group could not be created | Security group was not linked to the correct VPC | Updated launch template SG to use VPC-specific SG |
| SSH connection timed out from Bastion to private EC2 | Security group allowed only `0.0.0.0/0` on SSH, not Bastion SG | Changed SSH rule source to Bastion's security group ID |
| SCP permission denied to Bastion | Used wrong home path | Used `/home/ubuntu` path |

---

## Repository Structure

```
java-app-secure-vpc-aws/
├── README.md
├── screenshots/
│   ├── 01-vpc-creation-workflow.png
│   ├── 02-vpc-details.png
│   ├── 03-vpc-resource-map.png
│   ├── 04-launch-template.png
│   ├── 05-auto-scaling-group-create.png
│   ├── 06-asg-review.png
│   ├── 07-asg-error-sg-mismatch.png
│   ├── 08-asg-capacity-overview.png
│   ├── 09-asg-network-details.png
│   ├── 10-ec2-private-instance.png
│   ├── 11-pem-key-local.png
│   ├── 12-scp-to-bastion.png
│   ├── 13-scp-copy-commands.png
│   ├── 14-ssh-from-bastion.png
│   ├── 15-sg-inbound-rules-edit.png
│   ├── 16-sg-rules-before.png
│   ├── 17-ssh-connection-timeout.png
│   ├── 18-sg-bastion-source.png
│   ├── 19-bastion-sg-rules.png
│   └── 20-bastion-networking.png
└── docs/
    └── deployment-guide.md
```

---

## Tech Stack

| Category | Technology |
|---|---|
| Cloud Provider | AWS (us-east-1) |
| Application | Java (t2.micro EC2) |
| OS | Ubuntu 22.04 LTS |
| Networking | VPC, IGW, NAT Gateway, Route Tables |
| Compute | EC2 with Auto Scaling Group |
| Load Balancing | Application Load Balancer (Layer 7) |
| Security | Security Groups, Bastion Host, Private Subnets |
| Access | SSH key pair (`aws-ec2.pem`), Jump server pattern |

---

## Author

**Lavit Tyagi**
- AWS Account: `026266492632`
- Region: `us-east-1` (N. Virginia)
- Project date: April 2026

---

## Key Learnings

1. **Security Groups must belong to the same VPC** as the Auto Scaling Group — mismatched SGs cause ASG creation failure
2. **Bastion Host pattern** — never expose private EC2 instances directly; always SSH through a jump server
3. **NAT Gateway** allows private instances to pull updates without being publicly accessible
4. **SCP before SSH** — copy the PEM key to Bastion first, then use it to hop into private instances
5. **Source SG in rules** — instead of allowing SSH from `0.0.0.0/0`, restrict it to the Bastion's Security Group ID for tighter security

---

> **Note:** All sensitive IDs (instance IDs, VPC IDs, security group IDs) in this README are from a learning/demo environment. Do not commit real production credentials or PEM files to any repository.