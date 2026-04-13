

# SNS topic for configuring S3 buckets to send notifications when new data arrives
# Copyright (C) 2022 Panther Labs, Inc.
#
# The Panther SaaS is licensed under the terms of the Panther Enterprise Subscription
# Agreement available at https://panther.com/enterprise-subscription-agreement/.
# All intellectual property rights in and to the Panther SaaS, including any and all
# rights to access the Panther SaaS, are governed by the Panther Enterprise Subscription Agreement.


# TODO(SecEng): implement Customer-Managed Key so that the Queue's contents are encrypted at rest
# Didn't pursue this immediately because we have to disentangle the SNS Key with the Bucket Key,
#  and test it consistently to make sure it works. 
# Also need to ask Panther what it means to "manage the KMS CMK for the SNS topic", and whether it's separate from bucket ingestion roles
# Panther Terraform reference: https://github.com/panther-labs/panther-auxiliary/blob/v1.59.0/terraform/panther_log_processing_notifications/variables.tf#L36-L44

# Learn more about SNS + KMS integration here: https://aws.amazon.com/blogs/compute/encrypting-messages-published-to-amazon-sns-with-aws-kms/

#####
# Sets up an SNS topic.

# This topic is used to notify the Panther master account whenever new data is written to the
# LogProcessing bucket.
resource "aws_sns_topic" "log_processing" {
  name = "${var.s3_bucket_name}-panther-subscription"
}

resource "aws_sns_topic_subscription" "panther_log_processing" {
  # Note(aku): This endpoint is on Panther's end. It only exists on us-west-2
  endpoint             = "arn:aws:sqs:us-west-2:${local.panther_account_id}:panther-input-data-notifications-queue"
  protocol             = "sqs"
  raw_message_delivery = false
  topic_arn            = aws_sns_topic.log_processing.arn
}

resource "aws_sns_topic_policy" "policy" {
  arn = aws_sns_topic.log_processing.arn

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      # Reference: https://amzn.to/2ouFmhK
      {
        Sid : "AllowS3EventNotifications",
        Effect : "Allow",
        Principal : {
          Service : "s3.amazonaws.com"
        },
        Action : "sns:Publish",
        Resource : aws_sns_topic.log_processing.arn
      },
      {
        Sid : "AllowCloudTrailNotification",
        Effect : "Allow",
        Principal : {
          Service : "cloudtrail.amazonaws.com"
        },
        Action : "sns:Publish",
        Resource : aws_sns_topic.log_processing.arn
      },
      {
        Sid : "AllowSubscriptionToPanther",
        Effect : "Allow",
        Principal : {
          AWS : "arn:aws:iam::${local.panther_account_id}:root"
        },
        Action : "sns:Subscribe",
        Resource : aws_sns_topic.log_processing.arn
      }
    ]
  })
}
