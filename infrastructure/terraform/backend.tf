terraform {
  backend "local" {
    path = "terraform.tfstate.local"
  }
}

# To use remote S3 state instead, change backend "local" {} to backend "s3" {}
# and run: terraform init -reconfigure -backend-config=backend-dev.hcl
# (gitignored backend-dev.hcl contains the S3 bucket/key/region settings)
