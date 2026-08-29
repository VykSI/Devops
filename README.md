# DevOps Assignment — Go Application on AWS

A production-oriented deployment of a Go application on AWS using **Terraform, Amazon ECS Fargate, Amazon ECR, Amazon RDS PostgreSQL, Application Load Balancer, CloudWatch, and GitHub Actions**.

The project demonstrates infrastructure-as-code, containerized application deployment, secure AWS authentication from GitHub Actions using OIDC, environment separation, automated testing, and application/infrastructure monitoring.

---

## Architecture

```text
                           GitHub Repository
                                  │
                                  │ Push
                                  ▼
                         GitHub Actions
                    ┌─────────────────────────┐
                    │                         │
                    │    Docker Build         │
                    │          │              │
                    │          ▼              │
                    │       ECR Push          │
                    │          │              │
                    │          ▼              │
                    │     ECS Deployment      │
                    └────────────┬────────────┘
                                 │
                         GitHub OIDC
                                 │
                                 ▼
                         AWS IAM Role
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
             ECR                ECS               CloudWatch
         Docker Images       Fargate Tasks       Logs/Metrics
                                 │
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
              Application ALB           RDS PostgreSQL
                    │                         │
                    │                    Private DB
                    │                       Subnets
                    ▼
              Go Application
                 :8080
```

### AWS Network Architecture

```text
                              Internet
                                  │
                                  ▼
                        ┌──────────────────┐
                        │  Application LB  │
                        │   Public Subnets │
                        └────────┬─────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │      ECS Fargate        │
                    │    Private App Subnets  │
                    │                         │
                    │      Go Application     │
                    │        Port 8080        │
                    └────────────┬────────────┘
                                 │
                                 │ PostgreSQL :5432
                                 ▼
                    ┌─────────────────────────┐
                    │      RDS PostgreSQL     │
                    │    Private DB Subnets   │
                    └─────────────────────────┘
```

The application is not directly exposed to the public internet. Internet traffic enters through the Application Load Balancer, while ECS tasks and the database are deployed inside private subnets.

---

# Technology Stack

| Component              | Technology                |
| ---------------------- | ------------------------- |
| Application            | Go                        |
| Containerization       | Docker                    |
| Infrastructure as Code | Terraform                 |
| Compute                | Amazon ECS Fargate        |
| Container Registry     | Amazon ECR                |
| Database               | Amazon RDS PostgreSQL     |
| Load Balancer          | Application Load Balancer |
| Secrets                | AWS Secrets Manager       |
| Monitoring             | Amazon CloudWatch         |
| Application Metrics    | Prometheus                |
| CI/CD                  | GitHub Actions            |
| AWS Authentication     | GitHub Actions OIDC       |
| Cloud Platform         | AWS                       |

---

# Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yaml
│       └── deploy.yml
│
├── app/
│   ├── cmd/
│   │   └── server/
│   ├── internal/
│   │   └── metrics/
│   ├── go.mod
│   ├── go.sum
│   └── ...
│
├── terraform/
│   ├── environments/
│   │   ├── staging.tfvars
│   │   └── production.tfvars
│   │
│   ├── ecr.tf
│   ├── ecs.tf
│   ├── iam.tf
│   ├── github-oidc.tf
│   ├── monitoring.tf
│   ├── rds.tf
│   ├── networking.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── ...
│
├── Dockerfile
└── README.md
```

---

# Application

The application is a Go HTTP service running on port `8080`.

The service exposes:

```text
GET /health
GET /metrics
```

### Health Check

The application provides a health endpoint used by the ECS container health check and the Application Load Balancer.

```text
GET /health
```

### Prometheus Metrics

Application-level metrics are exposed through:

```text
GET /metrics
```

The application currently records HTTP request count and request duration.

Example metrics include:

```text
http_requests_total
http_request_duration_seconds
```

Metrics are labelled by request method, path, and status where applicable.

---

# AWS Infrastructure

All AWS infrastructure is managed using Terraform.

## VPC

The infrastructure creates a dedicated VPC with separate subnet tiers:

```text
Public Subnets
    └── Application Load Balancer

Private Application Subnets
    └── ECS Fargate Tasks

Private Database Subnets
    └── RDS PostgreSQL
```

This provides network isolation between the public entry point, application workloads, and database.

---

## Application Load Balancer

The Application Load Balancer is deployed in the public subnets.

Responsibilities:

* Accept incoming HTTP traffic
* Forward traffic to ECS
* Perform health checks
* Provide a stable public endpoint

The ECS service is registered with the ALB target group on port `8080`.

---

## ECS Fargate

The application runs on Amazon ECS using Fargate.

The ECS configuration includes:

* `awsvpc` networking
* ARM64 architecture
* Private subnets
* Security groups
* Application Load Balancer integration
* Container health checks
* CloudWatch logging
* ECS Container Insights

The application container listens on:

```text
8080
```

The ECS service is configured to use the Docker image stored in ECR.

---

## Amazon ECR

Docker images are stored in an environment-specific ECR repository.

Example:

```text
staging-app
```

GitHub Actions builds the application image and pushes it to ECR using the commit SHA as the image tag.

This provides immutable version identification for deployments.

---

## Amazon RDS PostgreSQL

The application uses Amazon RDS PostgreSQL as its database.

The database is deployed in private database subnets and is not publicly accessible.

Application connectivity follows:

```text
ECS Task
   │
   │ PostgreSQL :5432
   ▼
RDS PostgreSQL
```

The database endpoint is managed through Terraform outputs rather than hard-coded application configuration.

---

# Secrets Management

The database password is stored in **AWS Secrets Manager**.

The ECS task definition references the secret rather than embedding the database password directly into the Docker image or source code.

```text
AWS Secrets Manager
        │
        │ Secret reference
        ▼
ECS Task Definition
        │
        ▼
Go Application
```

This keeps credentials outside the application repository and container image.

---

# IAM and Security

The infrastructure follows least-privilege principles where practical.

Separate IAM roles are used for:

* ECS task execution
* ECS application task
* GitHub Actions deployment

The ECS execution role provides permissions required to start the task, retrieve required resources, and send logs.

The GitHub Actions deployment role has permissions required for:

* ECR authentication and image publishing
* ECS task definition registration
* ECS service updates
* ECS deployment operations
* Passing the ECS task role

---

# GitHub Actions OIDC

GitHub Actions does not use long-lived AWS access keys.

Instead, the workflow authenticates to AWS using **OpenID Connect (OIDC)**.

```text
GitHub Actions
      │
      │ OIDC token
      ▼
AWS IAM OIDC Provider
      │
      │ AssumeRoleWithWebIdentity
      ▼
GitHub Actions IAM Role
      │
      ├── ECR
      └── ECS
```

The IAM trust policy restricts which GitHub repository and deployment environment can assume the role.

This avoids storing permanent AWS access keys in GitHub secrets.

The only AWS credential-related secret required by the deployment workflow is the IAM role ARN used by the workflow.

---

# Why These Technologies?

The architecture was intentionally designed to be **simple, cost-effective, secure, and appropriate for the scale of the application**, rather than introducing infrastructure that adds operational complexity without providing a meaningful benefit.

## Why ECS Fargate instead of EKS?

Amazon EKS is a powerful managed Kubernetes platform, but Kubernetes introduces significantly more operational complexity than is necessary for this application.

EKS would be more appropriate when the platform requires capabilities such as:

* Multiple complex microservices
* Kubernetes-native workloads
* Custom Kubernetes operators
* Advanced scheduling requirements
* A broader Kubernetes ecosystem
* Existing organizational expertise and tooling around Kubernetes

For this application, the requirement is primarily to run and deploy a containerized Go service reliably.

**ECS Fargate provides exactly that without requiring Kubernetes cluster management.**

With ECS Fargate:

* No EC2 worker nodes need to be managed
* No Kubernetes control-plane configuration is required
* Task networking integrates directly with AWS VPC
* IAM integrates naturally with ECS
* ALB integration is straightforward
* CloudWatch integration is native
* Deployment configuration remains relatively small and easy to maintain

Therefore, ECS Fargate provides a better **complexity-to-value ratio** for this workload.

---

## Why GitHub Actions instead of Jenkins?

Jenkins is a mature and highly capable CI/CD platform, but it requires additional infrastructure and operational maintenance.

A Jenkins deployment would typically require managing:

```text
Jenkins Controller
       │
       ├── Agents
       ├── Credentials
       ├── Plugins
       ├── Persistent Storage
       └── Upgrades / Maintenance
```

For this project, GitHub is already the source-code platform, so GitHub Actions provides CI/CD directly within the same ecosystem.

The workflow can therefore be:

```text
Git Push
   ↓
GitHub Actions
   ↓
Tests
   ↓
Docker Build
   ↓
ECR
   ↓
ECS
```

GitHub Actions also integrates directly with GitHub repositories and supports **OIDC authentication with AWS**, allowing the deployment to assume an AWS IAM role without storing long-lived AWS access keys.

This significantly reduces the infrastructure and credential-management overhead compared with operating a dedicated Jenkins server.

Jenkins would become more attractive if the organization already had a large Jenkins ecosystem, complex cross-platform pipelines, extensive on-premise integrations, or requirements that specifically depended on Jenkins plugins.

---

## Why Fargate instead of ECS on EC2?

ECS can run containers using either Fargate or EC2 capacity.

For this application, Fargate was selected because the workload does not require dedicated host management.

With Fargate:

* AWS manages the underlying compute
* There are no EC2 instances to patch
* Capacity management is simplified
* ECS tasks can be scaled independently
* Infrastructure configuration is smaller

Using ECS on EC2 would provide more control over the underlying hosts, but that control is not required for this workload.

---

## Why RDS instead of running PostgreSQL inside ECS?

The database is a stateful component, while ECS is primarily being used to run the stateless application.

Running PostgreSQL inside an ECS task would introduce additional responsibilities around:

* Persistent storage
* Database backups
* Failover
* Recovery
* Database maintenance
* Storage management

Amazon RDS provides these capabilities as a managed database service.

Therefore, the architecture separates the application and database responsibilities:

```text
ECS Fargate
   │
   │ PostgreSQL
   ▼
RDS PostgreSQL
```

This allows ECS to remain focused on running the application while RDS handles database-specific operational concerns.

---

## Why Terraform instead of manually creating AWS resources?

The infrastructure contains multiple interconnected AWS resources:

```text
VPC
 ├── Subnets
 ├── Route Tables
 ├── Security Groups
 ├── ALB
 ├── ECS
 ├── ECR
 ├── RDS
 ├── IAM
 ├── Secrets Manager
 └── CloudWatch
```

Creating these manually through the AWS Console would make the environment harder to reproduce and maintain.

Terraform provides:

* Infrastructure as Code
* Version control
* Reproducible environments
* Dependency management
* Change tracking
* Consistent staging/production configuration

The same Terraform configuration can therefore be used to create both environments while changing only environment-specific variables.

---

## Why GitHub OIDC instead of AWS Access Keys?

Long-lived AWS access keys stored in GitHub would create unnecessary credential-management and security risks.

Instead, GitHub Actions obtains an OIDC token and uses it to assume a restricted AWS IAM role.

```text
GitHub Actions
      │
      │ OIDC Token
      ▼
AWS IAM OIDC Provider
      │
      ▼
Deployment IAM Role
      │
      ├── ECR
      └── ECS
```

This provides short-lived credentials and allows the AWS trust policy to restrict which repository and environment can perform deployments.

---

## Why separate staging and production environments?

Staging and production have different purposes.

### Staging

Used for:

* Testing deployments
* Validating application changes
* Verifying infrastructure changes
* Catching deployment issues before production

### Production

Used for:

* Serving the production application
* Running with production-specific configuration
* Controlled deployments from the `main` branch

The GitHub Actions workflow maps:

```text
develop → staging
main    → production
```

This provides a straightforward promotion model while keeping the environments logically separated.

---

## Overall Technology Selection

The final architecture deliberately favors **managed AWS services and native GitHub integration**:

| Requirement         | Selected Technology | Reason                                                 |
| ------------------- | ------------------- | ------------------------------------------------------ |
| Infrastructure      | Terraform           | Reproducible Infrastructure as Code                    |
| Containers          | ECS Fargate         | Managed container execution without server management  |
| Kubernetes          | Not used            | Unnecessary operational complexity for this workload   |
| CI/CD               | GitHub Actions      | Native GitHub integration and no CI server to maintain |
| Jenkins             | Not used            | Avoids maintaining a separate CI/CD platform           |
| Registry            | ECR                 | Native AWS integration with ECS                        |
| Database            | RDS PostgreSQL      | Managed relational database                            |
| Secrets             | Secrets Manager     | Secure credential storage                              |
| Load Balancing      | ALB                 | Native ECS integration                                 |
| Monitoring          | CloudWatch          | Native AWS observability                               |
| Application Metrics | Prometheus client   | Application-level request metrics                      |
| AWS Authentication  | GitHub OIDC         | Short-lived credentials without AWS access keys        |

The goal was not to select the largest or most feature-rich technology for every component, but to select the **simplest architecture that satisfies the requirements while remaining secure, reproducible, and extensible**.

---

## Engineering Practices & Differentiators

The implementation focuses not only on getting the application deployed, but also on security, reproducibility, maintainability, and operational visibility.

### Infrastructure as Code

All AWS infrastructure is provisioned through Terraform, including networking, security groups, ECS, ECR, RDS, IAM, ALB, and CloudWatch resources.

Environment-specific configuration is separated from the reusable infrastructure definitions, allowing the same architecture to support staging and production.

### Secure CI/CD Authentication

GitHub Actions authenticates with AWS using OpenID Connect (OIDC) rather than storing long-lived AWS access keys.

The GitHub OIDC trust policy restricts which repository and environment can assume the deployment role.

### Least-Privilege IAM

The GitHub Actions deployment role is granted only the permissions required for:

* Pushing images to the application ECR repository
* Reading and registering ECS task definitions
* Updating the ECS service
* Passing the required ECS IAM role

Runtime ECS roles are kept separate from the CI/CD deployment role.

### Private Application and Database Layers

The architecture separates the public and private layers:

```text
Internet
   │
   ▼
Application Load Balancer
   │
   ▼
ECS Fargate
   │
   ▼
RDS PostgreSQL
```

The ALB resides in public subnets, while ECS application tasks and RDS are deployed into private subnets.

Security groups restrict communication between the individual layers.

### Secure Container Design

The Docker image uses a multi-stage build so the runtime image contains only the application binary and required runtime components.

The application runs as a dedicated non-root user rather than as root.

A container health check is also configured so ECS can determine whether the application is healthy.

### CI/CD Quality Gates

Deployment is dependent on successful application validation.

The pipeline performs:

```text
Go Tests
   ↓
go vet
   ↓
Docker Build
   ↓
ECR Push
   ↓
ECS Task Definition
   ↓
ECS Deployment
```

This prevents a failed test or static analysis check from proceeding to deployment.

### Immutable Container Versions

Container images are tagged using the Git commit SHA rather than relying exclusively on mutable tags such as `latest`.

This provides traceability between:

```text
Git Commit
     ↓
Docker Image
     ↓
ECR
     ↓
ECS Task Definition
```

A deployed ECS task can therefore be traced back to the exact source revision that produced it.

### Application-Level Observability

The Go application exposes Prometheus-compatible metrics including request counts and request duration.

This provides visibility into application behavior in addition to infrastructure-level metrics.

### Environment Isolation

The deployment workflow maps branches to environments:

```text
develop → staging
main    → production
```

GitHub Environments are used to separate environment-specific deployment configuration and credentials.

### Architectural Simplicity

The solution intentionally uses managed services rather than introducing unnecessary operational complexity.

ECS Fargate was selected instead of EKS because Kubernetes cluster management is not required for this workload.

GitHub Actions was selected instead of Jenkins because the source code already resides in GitHub and the project does not require a separately managed CI/CD platform.

RDS was selected instead of running PostgreSQL inside ECS because the database is stateful and benefits from a managed database service.

The overall design aims to use the **simplest architecture that satisfies the requirements while remaining secure, reproducible, and extensible.**

# CI/CD Pipeline

The deployment workflow is triggered when changes are pushed to:

```text
main
develop
```

The workflow contains two major stages.

## 1. Test

The test job:

1. Checks out the repository
2. Installs Go
3. Downloads dependencies
4. Runs unit tests
5. Runs `go vet`

Commands:

```bash
go test ./...
go vet ./...
```

A deployment cannot proceed if the test or vet job fails. Pull requests targeting `main` or `develop` also run the separate [ci.yaml](.github/workflows/ci.yaml) workflow, which adds `govulncheck ./...` for Go dependency vulnerability scanning. The PR workflow performs checks only and never deploys.

---

## 2. Build and Deploy

After successful tests:

```text
GitHub Push
     │
     ▼
Run Tests
     │
     ▼
Go Vet
     │
     ▼
Docker Build
     │
     ▼
Push Image → ECR
     │
     ▼
ECR Image Scan
   │
   ▼
Retrieve Current ECS Task Definition
     │
     ▼
Update Container Image
     │
     ▼
Register New Task Definition
     │
     ▼
Update ECS Service
     │
     ▼
Wait for ECS Stability
```

Docker images are built for the ARM64 platform to match the ECS Fargate runtime architecture.

The image tag is based on:

```text
Git commit SHA
```

This allows every deployment to be traced back to a specific source revision.

ECR scan-on-push is enabled for each environment repository. The deployment waits for the scan to complete and blocks on HIGH or CRITICAL findings. ECR scans the container image and its OS/packages; `govulncheck` scans Go dependencies.

---

# Environment Management

The project supports separate staging and production environments.

Terraform environment-specific variables are stored under:

```text
terraform/environments/
```

Example:

```text
staging.tfvars
production.tfvars
```

The environment controls values such as:

```hcl
environment       = "staging"
ecs_desired_count = 1
image_tag         = "latest"
```

Look at variables.tf in terraform folder and add whatever is required as enviroment variables in .tfvars files.

Production uses its own environment configuration.

The GitHub Actions workflow maps branches to environments:

```text
develop → staging
main    → production
```

This provides a controlled promotion path from development to production.

---

# Terraform

Initialize Terraform:

```bash
cd terraform
terraform init -backend-config=backend-staging.hcl
```

Staging and production use separate state objects in the same encrypted S3 state bucket:

```text
staging/terraform.tfstate
production/terraform.tfstate
```

Initialize production from the same Terraform directory with:

```bash
terraform init -reconfigure -backend-config=backend-production.hcl
```

Switch back to staging with:

```bash
terraform init -reconfigure -backend-config=backend-staging.hcl
```

Run `terraform init -reconfigure` only after confirming the selected state key. Do not use the production backend for staging or vice versa.

Validate configuration:

```bash
terraform validate
```

Format configuration:

```bash
terraform fmt -recursive
```

Create a staging plan:

```bash
terraform plan \
  -var-file=environments/staging.tfvars
```

Apply staging infrastructure:

```bash
terraform apply \
  -var-file=environments/staging.tfvars
```

Terraform outputs provide useful infrastructure information such as:

```text
VPC ID
Subnet IDs
ECR repository URL
ALB DNS name
RDS endpoint
ECS cluster name
ECS service name
GitHub Actions IAM role ARN
```

---

# Docker

The application uses a multi-stage Docker build.

The build stage compiles the Go application, while the runtime stage contains only the compiled binary and the minimal runtime environment.

This reduces the final container image size and avoids including the Go toolchain in the production container.

The application is compiled for:

```text
linux/arm64
```

which matches the ECS task architecture.

Build locally:

```bash
docker build --platform linux/arm64 -t devops-app .
```

---

# Monitoring and Observability

The infrastructure includes CloudWatch monitoring for AWS resources and ECS.

## CloudWatch Logs

ECS container logs are sent to CloudWatch Logs.

Log group:

```text
/ecs/<environment>-app
```

This provides centralized application logging without requiring direct access to the ECS host.

The Go application writes structured JSON startup, shutdown, database, and HTTP request logs to stdout. HTTP entries include method, path, status, and duration, while request bodies and credentials are excluded. Fargate host OS logs are not collected because those hosts are managed by AWS.

The ALB writes access logs to an environment- and account-specific S3 bucket. The bucket blocks public access, enforces bucket ownership, uses AES-256 encryption, and has versioning enabled. Terraform also uses `force_destroy` so object versions and delete markers are removed before the bucket during `terraform destroy`.

---

## ECS Container Insights

ECS Container Insights is enabled for the ECS cluster.

This provides infrastructure-level visibility into:

* ECS tasks
* CPU utilization
* Memory utilization
* Container activity
* Cluster/service performance

---

## CloudWatch Alarms

Two dashboards are provisioned per environment. The application dashboard includes ALB requests, 4xx/5xx responses, latency, ECS CPU and memory, and running tasks. The infrastructure dashboard includes RDS CPU, database connections, free storage, and ECS service health.

The infrastructure includes CloudWatch alarms for important application infrastructure signals:

* ECS CPU utilization and low running task count
* Application Load Balancer HTTP 5xx responses and high p95 latency
* RDS CPU utilization and low free storage

These alarms publish to an environment-specific SNS topic. Set the Terraform `alarm_email` variable to create an email subscription, then confirm the subscription from the AWS email before notifications are delivered. Thresholds are configurable through Terraform variables.

---

# Security Architecture

The deployment follows several security principles:

### Network Isolation

```text
Internet
   │
   ▼
ALB
   │
   ▼
Private ECS
   │
   ▼
Private RDS
```

The database is not publicly exposed.

### Secrets

Database credentials are stored in AWS Secrets Manager rather than source control.

ECS receives the password from Secrets Manager. The password remains in local Terraform state because Terraform currently manages both the RDS password and secret version; state and backups must therefore be treated as sensitive. Moving to an AWS-managed RDS password would require a broader credential-contract change.

### IAM

AWS access is provided through dedicated IAM roles rather than sharing broad credentials.

### GitHub OIDC

GitHub Actions uses short-lived AWS credentials through OIDC instead of long-lived access keys.

### Container

The application runs as a non-root user inside the runtime container.

Terraform state remains local intentionally. A safe remote-state migration requires a private, encrypted, versioned S3 state bucket with restricted access, a locking mechanism, a state backup, and a reviewed `terraform init -migrate-state`. No automatic migration is performed.

---

# Deployment Flow

## Staging

Changes pushed to:

```text
develop
```

follow:

```text
develop
   ↓
Tests
   ↓
Docker Build
   ↓
ECR
   ↓
ECS Staging
```

## Production

Changes pushed to:

```text
main
```

follow:

```text
main
   ↓
Tests
   ↓
Docker Build
   ↓
ECR
   ↓
ECS Production
```

Production uses a separate GitHub environment and Terraform variable configuration.

There are no live database integration tests. The Go test suite uses HTTP tests and `pgxmock`, so it runs without PostgreSQL, AWS, or containers. A future integration layer could use a disposable PostgreSQL service if database integration coverage becomes necessary.

---

# Useful Commands

### Terraform

```bash
terraform init
terraform validate
terraform fmt -recursive
terraform plan
terraform apply
terraform output
terraform destroy
```

### Go

```bash
cd app

go mod download
go test ./...
go vet ./...
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...
go run ./cmd/server
```

### Docker

```bash
docker build --platform linux/arm64 -t devops-app .
```

### AWS

Check the current AWS identity:

```bash
aws sts get-caller-identity
```

Check ECS service:

```bash
aws ecs describe-services \
  --cluster staging-cluster \
  --services staging-app
```

Check ECR:

```bash
aws ecr describe-repositories \
  --repository-names staging-app
```

---

# Design Decisions

### Terraform for Infrastructure

Terraform provides repeatable, version-controlled infrastructure and allows staging and production environments to be managed using the same infrastructure definitions.

### ECS Fargate

Fargate removes the need to manage EC2 instances while providing container orchestration and service-level deployment capabilities.

### Private Application and Database Subnets

Only the ALB is exposed publicly. Application and database workloads remain inside private network segments.

### GitHub OIDC

OIDC eliminates the need for permanent AWS credentials in GitHub Actions and provides an identity-based trust relationship between GitHub and AWS.

### Commit-Based Image Tags

Using the Git commit SHA as the Docker image tag provides traceability between:

```text
Source Code
    ↓
Git Commit
    ↓
Docker Image
    ↓
ECS Deployment
```

This makes deployments easier to audit and roll back.

---

# Future Improvements

Potential improvements for a production-scale deployment include:

* HTTPS using ACM certificates
* Route 53 DNS configuration
* Auto Scaling for ECS tasks
* WAF integration with the ALB
* Expanded SNS routing and on-call integration
* Prometheus/Grafana integration for application metrics
* Terraform remote state using S3 with state locking
* Automated Terraform plan/apply workflows
* Additional container scanning beyond the ECR scan-on-push gate
* Blue/green or canary deployments
* Automated database backup and disaster recovery strategy
* Separate AWS accounts for staging and production

---

# Conclusion

This project demonstrates an end-to-end cloud deployment workflow for a containerized Go application.

The resulting architecture combines:

```text
Terraform
    +
AWS VPC
    +
ALB
    +
ECS Fargate
    +
ECR
    +
RDS PostgreSQL
    +
Secrets Manager
    +
CloudWatch
    +
GitHub Actions
    +
OIDC
```

The result is a reproducible, secure, and automated deployment pipeline with separate staging and production environments and infrastructure managed entirely through code.
