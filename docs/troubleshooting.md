# Troubleshooting

## Issue 1: SSH connection timeout
Reason:
- Security group not configured properly

Solution:
- Allow port 22 from Bastion SG

---

## Issue 2: Application not accessible
Reason:
- Port 8000 blocked

Solution:
- Allow port 8000 from ALB SG

---

## Issue 3: Java not found
Reason:
- Java not installed

Solution:
- Install OpenJDK 17