

$Region = Get-PSUtilDefaultIfNull -value (Get-DefaultAWSRegion) -defaultValue 'us-east-1'
Write-Verbose "Region=$Region"
Set-DefaultAWSRegion $Region

. "$PSScriptRoot\..\cfn\cfncommon.ps1" $Region

$stackName = 'siva-trail'
CFNDeleteStack $stackName

$cnfTemplate = @'
AWSTemplateFormatVersion: "2010-09-09"
Resources: 
  S3Bucket: 
    Type: AWS::S3::Bucket
    Properties: {}
  BucketPolicy: 
    Type: AWS::S3::BucketPolicy
    Properties: 
      Bucket: 
        Ref: S3Bucket
      PolicyDocument: 
        Version: "2012-10-17"
        Statement: 
          - 
            Sid: "AWSCloudTrailAclCheck"
            Effect: "Allow"
            Principal: 
              Service: "cloudtrail.amazonaws.com"
            Action: "s3:GetBucketAcl"
            Resource: 
              !Sub |-
                arn:aws:s3:::${S3Bucket}
          - 
            Sid: "AWSCloudTrailWrite"
            Effect: "Allow"
            Principal: 
              Service: "cloudtrail.amazonaws.com"
            Action: "s3:PutObject"
            Resource:
              !Sub |-
                arn:aws:s3:::${S3Bucket}/AWSLogs/${AWS::AccountId}/*
            Condition: 
              StringEquals:
                s3:x-amz-acl: "bucket-owner-full-control"
  myTrail: 
    DependsOn: 
      - BucketPolicy
    Type: AWS::CloudTrail::Trail
    Properties: 
      S3BucketName: 
        Ref: S3Bucket
      IsLogging: true
      IsMultiRegionTrail: false
'@

CFNCreateStack $stackName $cnfTemplate
