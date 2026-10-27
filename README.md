# Task Manager Infrastructure (Terraform)

Terraform-only AWS infrastructure for the Task Manager app in **ap-south-1 (Mumbai)**.

## Architecture

- VPC with public and private subnets across two Availability Zones
- Internet Gateway and one NAT Gateway for private-subnet outbound access
- Application Load Balancer (ALB) in public subnets
- ECS Fargate API service in private subnets
- ECR image supplied as a variable (build/push your API image separately)
- CloudWatch log group
- Private S3 bucket + CloudFront Origin Access Control (OAC) for the frontend
- CloudWatch alarms for ALB 5xx and ECS CPU

The frontend distribution is created with a default CloudFront certificate. For a custom domain, add an ACM certificate in `us-east-1` and configure an alternate domain name.

## Step 1 — Install prerequisites

- Terraform >= 1.10
- AWS CLI installed
- Permissions to create VPC, IAM, ECS, ECR, ALB, S3, CloudFront, CloudWatch resources
- Docker Desktop (or another running Docker Engine) and permission to build Linux containers
- ECR permissions for the identity publishing the image: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `ecr:PutImage`. Add `ecr:CreateRepository` if that identity will create the repository.
- An ECR repository in the same AWS account and `ap-south-1` region as the ECS deployment. The ECS task execution role must be able to pull from it; this configuration attaches `AmazonECSTaskExecutionRolePolicy`.
- Build the image for `linux/amd64`, which matches the default Fargate task architecture in this configuration.

Run the PowerShell commands below in the same session, starting from the repository root. Step 3 defines `$RepoRoot`, which later steps use to locate the infrastructure and frontend directories.

## Step 2 — Connect to AWS

Use an authenticated AWS CLI session rather than putting access keys in project files. With a recent AWS CLI that supports console-based login, run:

```powershell
aws login
```

Otherwise, use the authentication method configured for your account, such as IAM Identity Center:

```powershell
aws configure sso
aws sso login
```

Verify which account and region the CLI will use:

```powershell
aws sts get-caller-identity
aws configure get region
```

Set the default region to Mumbai if needed:

```powershell
aws configure set region ap-south-1
```

Run the identity check again before creating resources. Ensure it reports the intended AWS account and that the configured region is `ap-south-1`.

## Step 3 — Build and publish the backend Docker image

ECS needs the backend image in ECR before Terraform can start the API service. From the repository root, inspect the backend and confirm its Dockerfile exists:

```powershell
$RepoRoot = (Get-Location).Path
$ApiPath = Join-Path $RepoRoot "task-manager-api"
Get-ChildItem $ApiPath
if (-not (Test-Path (Join-Path $ApiPath "Dockerfile"))) {
  throw "task-manager-api\Dockerfile was not found. Create and verify the API Dockerfile before deploying."
}
docker version
```

Create the ECR repository once:

```powershell
$Region = "ap-south-1"
$Repository = "task-manager-api"
aws ecr create-repository `
  --repository-name $Repository `
  --image-scanning-configuration scanOnPush=true `
  --region $Region
```

If AWS reports that the repository already exists, retrieve its details and continue:

```powershell
aws ecr describe-repositories `
  --repository-names task-manager-api `
  --region ap-south-1
```

Get the account ID and authenticate Docker to the matching ECR registry:

```powershell
$AccountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { throw "Could not identify the AWS account. Check your CLI login." }
$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$ImageTag = "dev"
$ImageUri = "$Registry/$Repository`:$ImageTag"

aws ecr get-login-password --region $Region |
  docker login --username AWS --password-stdin $Registry
if ($LASTEXITCODE -ne 0) { throw "Docker could not authenticate to ECR." }
```

Build and push the Linux image:

```powershell
docker build --platform linux/amd64 -t $ImageUri -f (Join-Path $ApiPath "Dockerfile") $ApiPath
if ($LASTEXITCODE -ne 0) { throw "Image build failed. Fix the Docker build before provisioning ECS." }

docker push $ImageUri
if ($LASTEXITCODE -ne 0) { throw "Image push to ECR failed." }

Write-Output "API image: $ImageUri"
```

If the build fails, stop here and fix it before provisioning ECS. For production, use a unique release tag or image digest rather than reusing `dev`.

## Step 4 — Bootstrap remote state (one time)

Run from the repository root. This creates the S3 bucket used to store Terraform state:

```powershell
Set-Location .\task-manager-infra-complete\bootstrap
terraform init
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Bootstrap state itself is initially local; store/back it up safely after successful creation.

## Step 5 — Configure the dev environment

Copy the example variables file:

```powershell
Set-Location (Join-Path $RepoRoot "task-manager-infra-complete\environments\dev")
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set `api_image` to the exact URI printed in the previous step, for example:

```hcl
api_image = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/task-manager-api:dev"
mongodb_uri_secret_arn = "arn:aws:secretsmanager:ap-south-1:123456789012:secret:task-manager-dev/mongodb-abcdef:MONGODB_URI::"
```

Set `mongodb_uri_secret_arn` to the ECS `valueFrom` ARN for the existing Secrets Manager secret. The `:MONGODB_URI::` suffix tells ECS to read the `MONGODB_URI` key from the secret's JSON value; store the actual MongoDB URI in Secrets Manager, not in `terraform.tfvars`.

Terraform grants `secretsmanager:GetSecretValue` on the underlying secret ARN to the ECS **execution role** (the selector suffix is removed for the IAM resource) and injects the selected value into the container as `MONGODB_URI` at startup. The API image must listen on port 4000 and provide `GET /health` (or change `health_check_path`).

### Optional remote backend

After bootstrap finishes, copy `backend.tf.example` to `backend.tf` and update the bucket/key/region to match the bootstrap output. Then migrate state:

```powershell
terraform init -migrate-state
```

Do not put backend credentials in this file. AWS credentials should come from your normal AWS CLI/profile/environment.

## Step 6 — Plan and deploy

```powershell
Set-Location (Join-Path $RepoRoot "task-manager-infra-complete\environments\dev")
terraform init
terraform validate
terraform plan -out dev.tfplan
terraform apply dev.tfplan
```

Review the plan before applying. `api_image` must point to the image already pushed to ECR.

## Step 7 — Deploy frontend files

After Terraform completes, use the `frontend_bucket_name` output to upload the built Vite site:

```powershell
Set-Location (Join-Path $RepoRoot "task-manager-frontend")
npm install
npm run build
aws s3 sync dist/ s3://YOUR_FRONTEND_BUCKET/ --delete --region ap-south-1
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

Replace the bucket and distribution IDs with the Terraform outputs. `VITE_API_BASE_URL` is an API origin and must not include `/api/v1`; the frontend adds that prefix to task API calls.

The current ALB listener is HTTP-only, while CloudFront serves the frontend over HTTPS. Browsers block frontend requests from that HTTPS site to the HTTP ALB as mixed content. The current CloudFront distribution also has no API origin or API path behavior. Before deploying the frontend/API integration, either add an HTTPS API endpoint and allow the exact frontend origin in the API's `CORS_ORIGIN`, or configure CloudFront to proxy the API and health paths to the ALB and use the CloudFront origin as the frontend API base URL.

## Important notes

- This is a production-oriented baseline, not a fully hardened enterprise landing zone.
- One NAT Gateway is used to reduce cost; it is a single-AZ egress dependency. Use one per AZ for higher availability.
- NAT Gateway, ALB, ECS, CloudFront, and S3 may incur charges even at low usage.
- MongoDB Atlas remains external. Store its connection string in the configured Secrets Manager JSON key `MONGODB_URI`; Terraform injects it into the ECS container at startup. If the secret uses a customer-managed KMS key, also grant the execution role `kms:Decrypt` for that key. Configure the matching Cognito pool/client IDs for authenticated task routes as well. Do not commit credentials, and restrict Atlas network access appropriately.
- Cognito integration is not provisioned by this baseline; add it when auth integration is ready.
- Review all plans before applying. Never commit `terraform.tfvars`, state files, secrets, or plan files.
