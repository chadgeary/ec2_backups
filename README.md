# Reference
Backup EC2 instances with a rotational schedule using Lambda invoked via Cloudwatch scheduled expression.

## Steps (in reverse order)
1. Backup AWS EC2 instances as AMIs. Generation: Current
2. Move previous Generation: Current to Generation: Previous
3. Delete previous Generation: Previous

## Notes
- Requires/uses Terraform which uses environment AWS credentials (e.g. ~/.aws/credentials)
- Includes required IAM role/policy for Lambda function.
- Generations are managed via Tags
- Default schedule (in .tf) is 01:00 UTC on Sunday.

## Deploy
```
# begin terraform
terraform init
terraform apply

# answer terraform variable(s)
var.aws_profile
  Enter a value: default

var.aws_region
  Enter a value: us-east-2
```

## Output Example
```
START RequestId: 2e61afe8-1d2c-4a67-9858-6d4ea8ba49f0 Version: $LATEST
Deregistering AMIs: 
ami-03640102312b40e44
ami-054ae9fbcc986c11c
Rotating AMIs: 
ami-0233166832fd8ff7d
ami-067fe5ff4d8649201
Creating AMIs from Instances: 
Instance: i-04862db7a0741b727 , AMI: ami-0e14a86f6612b4293
Instance: i-03b48cb4caac5c961 , AMI: ami-0477c5d22c44b5fdd
END RequestId: 2e61afe8-1d2c-4a67-9858-6d4ea8ba49f0
REPORT RequestId: 2e61afe8-1d2c-4a67-9858-6d4ea8ba49f0	Duration: 7192.17 ms	Billed Duration: 7200 ms	Memory Size: 128 MB	Max Memory Used: 80 MB	Init Duration: 163.01 ms	
```
