output "ecs_service_arn" {
  description = "ARN for the ECS service."

  # Awful hack modified from https://github.com/hashicorp/terraform/issues/16726
  # Concatenate the two mostly-empty lists and take the first element.
  #
  # The old code indexed [0] directly, which assumed "exactly one of these has count > 0". That stops
  # being true with create_service = false: BOTH lists go empty and `[][0]` is a hard error ("Invalid
  # index: the given key does not identify an element in this collection"), which kills the plan before
  # it can even render a diff. try() makes the no-service case return null instead. Nothing in this repo
  # consumes ecs_service_arn, so null is safe.
  value = try(concat(aws_ecs_service.unmanaged-job.*.id, aws_ecs_service.job.*.id)[0], null)
}

output "ecs_task_definition_family" {
  description = "The family of the task definition defined for the given/generated container definition."
  value       = aws_ecs_task_definition.job.family
}
