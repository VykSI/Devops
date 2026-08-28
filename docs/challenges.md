## Challenges Faced

### 1. GitHub Actions OIDC Trust Policy Configuration

One of the more significant challenges was configuring GitHub Actions to authenticate with AWS securely using OIDC instead of long-lived AWS access keys.

The deployment initially failed with:

```text
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The issue required carefully aligning the GitHub OIDC claims with the AWS IAM role trust policy.

The final configuration restricts role assumption based on the GitHub repository and deployment environment, ensuring that only the intended GitHub Actions workflows can assume the AWS deployment role.

This issue was caused by github's new repo policy on how sub was supposed to be added (Was applicable only for new repos).

This provided short-lived AWS credentials while avoiding storing permanent AWS access keys in GitHub.

---

### 2. ECS IAM Permissions and Role Separation

After OIDC authentication was working, the deployment encountered authorization failures when GitHub Actions attempted to interact with ECS.

For example:

```text
not authorized to perform:
ecs:DescribeTaskDefinition
```

and later:

```text
not authorized to perform:
ecs:RegisterTaskDefinition
```

The deployment role initially did not have all the permissions required by the ECS deployment workflow.

Another important distinction was identifying the difference between:

* The GitHub Actions deployment role
* The ECS task execution role
* The ECS task role

The GitHub Actions role needs permission to perform deployment operations such as registering task definitions and updating the ECS service, while ECS itself uses its execution/task roles at runtime.

The IAM policies were therefore refined to follow the principle of least privilege while still allowing the CI/CD workflow to perform the required deployment operations.

---

### 3. IAM PassRole During ECS Task Definition Registration

Registering the ECS task definition introduced another important IAM dependency.

The deployment failed with:

```text
not authorized to perform:
iam:PassRole
```

This occurs because the ECS task definition references IAM roles that ECS must use when running the task.

GitHub Actions therefore needs permission to pass the appropriate ECS execution/task role while registering the new task definition.

The deployment role was updated to allow `iam:PassRole` only for the required ECS role rather than granting broad IAM permissions.

This highlighted an important security principle: **deployment permissions and runtime permissions are separate concerns.**

---

### 4. ARM64 Container Build and GitHub Actions Runner Architecture

The application was intentionally built for ARM64:

```text
GOARCH=arm64
--platform linux/arm64
```

During CI/CD, the Docker build encountered an architecture-related failure:

```text
exec format error
```

The issue occurred because Docker was attempting to execute ARM64 instructions while the GitHub-hosted runner was running on an x86_64 architecture.

The solution was to ensure that the Docker build used the appropriate platform/emulation configuration so that ARM64 images could be built correctly on the GitHub Actions environment.

This was particularly important because the ECS deployment target was configured around ARM64 workloads.

---

### 5. Environment-Specific Infrastructure and Deployment Configuration

The infrastructure needed to support separate staging and production environments while keeping the Terraform configuration reusable.

Instead of duplicating the infrastructure, environment-specific values are supplied through Terraform variable files and GitHub environments.

The deployment flow follows:

```text
develop → staging
main    → production
```

The GitHub Actions workflow dynamically selects the corresponding GitHub environment, allowing environment-specific configuration such as:

* AWS region
* ECR repository
* ECS cluster
* ECS service
* ECS task family
* Deployment credentials

This keeps the infrastructure reusable while maintaining a clear separation between staging and production deployments.

---

### 6. Coordinating Terraform Infrastructure with CI/CD

Another architectural challenge was establishing the correct dependency between infrastructure provisioning and application deployment.

Terraform is responsible for creating the AWS infrastructure:

```text
VPC
 ├── Networking
 ├── Security Groups
 ├── ALB
 ├── ECS
 ├── ECR
 ├── RDS
 ├── IAM
 └── CloudWatch
```

GitHub Actions then operates on top of that infrastructure:

```text
Git Push
   ↓
Tests
   ↓
Docker Build
   ↓
ECR
   ↓
ECS Task Definition
   ↓
ECS Service Deployment
```

This separation prevents the CI/CD pipeline from becoming responsible for creating the underlying infrastructure while allowing Terraform to remain the source of truth for infrastructure.

---

## Key Takeaway

The most important challenges were not simply getting individual AWS services running, but **connecting the security, infrastructure, container, and CI/CD layers correctly**.

The final deployment flow provides:

```text
Developer
   │
   ▼
GitHub
   │
   ▼
GitHub Actions
   │
   ├── Tests
   │
   ├── Docker Build
   │
   ├── ECR Push
   │
   └── AWS OIDC
          │
          ▼
      IAM Role
          │
          ▼
         ECS
          │
          ├── ALB
          └── RDS
```

The experience reinforced that cloud deployments are rarely about configuring one service in isolation. The challenging part is correctly integrating **IAM, networking, container architecture, deployment automation, and runtime health** into one reliable system.
