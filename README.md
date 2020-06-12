# Reference
Maintain up-to-date backups for EC2 instances with a Cloudwatch scheduled expression executing Lambda (Python3/Boto3) built via Terraform. Two generations of EC2 AMIs (`Previous` and `Current`) are maintained.

## Lambda (ec2_backups.py)
Steps are in reverse order.
1. Create AMIs with tag `Generation:Current` and tag `Source:ec2_backups` from EC2 instances with tag:Backup:true
2. Modify AMIs with tag `Generation:Current` and tag `Source:ec2_backups` to tag `Generation:Previous`
3. Delete AMIs with tag `Generation:Previous` and tag `Source:ec2_backups` + associated snapshot(s).

## Notes
- Includes required IAM role/policy for Lambda function.
- Default schedule (in .tf) is 00:00 GMT on Sunday.

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

# confirm terraform action(s)
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

## Output Example
```
START RequestId: beda210d-f258-439e-9614-8ad4a4311080 Version: $LATEST

Deregistering "Previous" AMIs:
ami-0233866832fd8ff1a
ami-067ee5d4d8649204

Deleting Snapshots associated with "Previous" AMIs: 
snap-02c911235227e207b
snap-042919322ffdd611

Rotating "Current" AMIs to "Previous":
ami-05abc5d22c44b5fdd
ami-0d24a86f6602b4293

Creating "Current" AMIs from EC2 Instances:
Instance: i-07862db7a0741b757 , AMI: ami-0c2cdc82e02764277
Instance: i-08b58cb4caac5c9e9 , AMI: ami-0935dc03d8fd95874
END RequestId: beda210d-f258-439e-9614-8ad4a4311080
REPORT RequestId: beda210d-f258-439e-9614-8ad4a4311080	Duration: 8064.64 ms	Billed Duration: 8100 ms	Memory Size: 128 MB	Max Memory Used: 83 MB	Init Duration: 160.41 ms
```
