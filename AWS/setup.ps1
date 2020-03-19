#Set-DefaultAWSRegion 'us-east-1'
$VerbosePreference='Continue'
trap { break } #This stops execution on any exception
$ErrorActionPreference = 'Stop'
. $PSScriptRoot\ssm\ssmcommon.ps1

#Define which accounts or AWS services can assume the role.
$assumePolicy = @"
{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid":"",
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }
    ]
}
"@

# Define which API actions and resources the application can use 
# after assuming the role
$policy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ds:CreateComputer",
                "ec2messages:*",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "s3:PutObject",
                "s3:GetObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts",
                "s3:ListBucketMultipartUploads",
                "ssm:DescribeAssociation",
                "ssm:ListAssociations",
                "ssm:GetDocument",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceInformation",
                "ec2:DescribeInstanceStatus",
                "ec2:CreateTags",
                "ec2:Describe*",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
"@

foreach ($region in (Get-AWSRegion)) {
    Write-Verbose ''
    Write-Verbose "Region=$($region.Region)($($region.Name))"
    Set-DefaultAWSRegion $region.Region

    SSMCreateRole
    SSMCreateKeypair
    SSMCreateSecurityGroup 
}


$VerbosePreference='SilentlyContinue'
