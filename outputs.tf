output "spark_master_endpoint" {
  description = "spark master endpoint with port"
  value       = "${cloudfoundry_route.spark-master.endpoint}:7077"
}

output "spark_master_id" {
  description = "App ID for spark master to add netowrk policies"
  value       = cloudfoundry_app.spark-master.id
}

output "spark_worker_id" {
  description = "Container Host IP addresses of Kafka instances"
  value       = cloudfoundry_app.spark-worker.id
}
