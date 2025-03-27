

resource "aws_cloudwatch_dashboard" "hipaa_dashboard" {
  dashboard_name = "HIPAA"

  dashboard_body = jsonencode({
    "widgets" : [
      local.widget_users_added_to_projects,
      local.widget_users_created_by_idseq_admins,
      local.widget_text_cloudtrail_logs
    ]
  })
}

locals {
  widget_users_added_to_projects = {
    "type" : "log",
    "x" : 0,
    "y" : 0,
    "width" : 24,
    "height" : 6,
    "properties" : {
      "region" : var.region,
      "title" : "Users added to projects"
      "query" : (
        <<-EOT
            source "${local.source_log_group}"
            | fields @timestamp, user_id, params.id as project_id, params.user_email_to_add
            | filter method == 'PUT'
            | filter controller == 'ProjectsController'
            | filter action == 'add_user'
            | order by @timestamp desc
        EOT
      )
    }
  }

  widget_users_created_by_idseq_admins = {
    "type" : "log",
    "x" : 0,
    "y" : 6,
    "width" : 24,
    "height" : 6,
    "properties" : {
      "region" : var.region,
      "title" : "Users created by idseq admins"
      "query" : (
        <<-EOT
            source "${local.source_log_group}"
            | fields @timestamp, action, user_id as created_by, params.id as target_user_id, params.user.email, params.user.role, status as http_status
            | filter controller == 'UsersController'
            | filter method in ["PATCH", "PUT", "POST", "DELETE"]
            | sort by @timestamp desc
        EOT
      )
    }
  }

  widget_text_cloudtrail_logs = {
    "type" : "text",
    "x" : 0,
    "y" : 12,
    "width" : 24,
    "height" : 11,
    "properties" : {
      "markdown" : (
        <<-EOT
            Security reports based on CloudTrail logs are managed by shared-infra and available in Snowflake.

            Instructions:
            - Create a new Worksheet in IDseq [Snowflake](https://czi_idseq.snowflakecomputing.com/console#/internal/worksheet), and select the following parameters for that worksheet:
              - Role: `SNOWALERT`
              - Warehouse: `FIVETRAN (XS)`
              - Database: `FIVETRAN`
              - Schema: `SNOWALERT_AUDIT`

            - Query one of the following views:
              - `ADMIN_IAM_ROLES_EC2_INSTANCES_LAUNCHED`: All events related to launch/connect/terminate EC2 instances with individual attribution
              - `ADMIN_IAM_ROLES_FILES_FETCHED_ON_S3`: Files fetched from S3 using one of the admin IAM roles (`poweruser`/`idseq-on-call`/`idseq-comp-bio`)
              - `"SNOWALERT"."czi_idseq_SHARE"."CLOUDTRAIL"` contain ALL cloudtrail events for `idseq-dev` and `idseq-prod` accounts.

            - Sample query:
            ```SQL
            /* Fetch files accessed by admin roles in the production account in the last 8 hours */
            SELECT *
            FROM "FIVETRAN"."SNOWALERT_AUDIT"."ADMIN_IAM_ROLES_FILES_FETCHED_ON_S3"
            WHERE 
              RECIPIENT_ACCOUNT_ID = 745463180746 /* prod account */
              EVENT_TIME > dateadd(hour, -8, current_timestamp) /* last 8 hours /
            ```
          EOT
      )
    }
  }

}
