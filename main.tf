data "cloudfoundry_org" "org" {
  name = var.cf_org
}
data "cloudfoundry_space" "space" {
  org  = data.cloudfoundry_org.org.id
  name = var.cf_space
}

data "cloudfoundry_domain" "external" {
  name = var.cf_domain
}

data "cloudfoundry_domain" "internal" {
  name = "apps.internal"
}

locals {
  spark_docker_image = var.spark_docker_image
}

resource "cloudfoundry_app" "spark-master" {
  name         = "spark-master"
  space        = data.cloudfoundry_space.space.id
  memory       = 1024
  disk_quota   = 2048
  health_check_type = "process"
  docker_image = local.spark_docker_image

  environment = {
    "SPARK_MODE"                              = "master"
    "SPARK_RPC_AUTHENTICATION_ENABLED"        = "no"
    "SPARK_RPC_ENCRYPTION_ENABLED"            = "no"
    "SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED"  = "no"
    "SPARK_SSL_ENABLED"                       = "no"
    "SPARK_MASTER_HOST"                       = cloudfoundry_route.spark-master.endpoint
  }

  routes {
    route = cloudfoundry_route.spark-master.id
  }
}

resource "cloudfoundry_route" "spark-master" {
  domain   = data.cloudfoundry_domain.internal.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-master" : "spark-master-${var.name_postfix}"
}

resource "cloudfoundry_app" "spark-worker" {
  name         = "spark-worker"
  space        = data.cloudfoundry_space.space.id
  memory       = 3072
  disk_quota   = 5120
  instances    = var.workers_size
  docker_image = local.spark_docker_image
  stopped      = false
  health_check_type = "process"

  environment = {
    "SPARK_MODE"                              = "worker"
    "SPARK_RPC_AUTHENTICATION_ENABLED"        = "no"
    "SPARK_RPC_ENCRYPTION_ENABLED"            = "no"
    "SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED"  = "no"
    "SPARK_SSL_ENABLED"                       = "no"
    "SPARK_MASTER_URL"                        = "spark://${cloudfoundry_route.spark-master.endpoint}:7077"
    "SPARK_WORKER_CORES"                      = "5"
    "SPARK_WORKER_MEMORY"                     = "3G"
  }

  routes {
    route = cloudfoundry_route.spark-worker.id
  }
}

resource "cloudfoundry_route" "spark-worker" {
  domain   = data.cloudfoundry_domain.internal.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-worker" : "spark-worker-${var.name_postfix}"
}


resource "cloudfoundry_app" "spark-history-server" {
  name         = "spark-history-server"
  space        = data.cloudfoundry_space.space.id
  memory       = 512
  disk_quota   = 2048
  health_check_type = "process"
  docker_image = local.spark_docker_image
  command      = "/opt/bitnami/spark/sbin/start-history-server.sh"

  environment = {
    "MASTER" = "spark://${cloudfoundry_route.spark-master.endpoint}:7077"
    "SPARK_MODE"                              = "worker"
    "SPARK_RPC_AUTHENTICATION_ENABLED"        = "no"
    "SPARK_RPC_ENCRYPTION_ENABLED"            = "no"
    "SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED"  = "no"
    "SPARK_SSL_ENABLED"                       = "no"
    "SPARK_MASTER_URL"                        = "spark://${cloudfoundry_route.spark-master.endpoint}:7077"
    "SPARK_WORKER_CORES"                      = "2"
    "SPARK_WORKER_MEMORY"                     = "3G"
    "SPARK_NO_DAEMONIZE"                      = true
    "SPARK_HISTORY_OPTS"                      = "-Dspark.history.fs.logDirectory=s3a://${var.s3_event_log_details.bucket_name}/${var.s3_event_log_details.event_log_dir} -Dspark.hadoop.fs.s3a.access.key=${var.s3_event_log_details.access_key} -Dspark.hadoop.fs.s3a.secret.key=${var.s3_event_log_details.secret_key} -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.ui.port=8080"
  }

  routes {
    route = cloudfoundry_route.spark-history-server.id
  }
}

resource "cloudfoundry_route" "spark-history-server" {
  domain   = data.cloudfoundry_domain.external.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-history-server" : "spark-history-server-${var.name_postfix}"

}

resource "cloudfoundry_route" "spark-history-server_p" {
  domain   = data.cloudfoundry_domain.external.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-history-server" : "spark-history-${var.name_postfix}"

}

resource "cloudfoundry_app" "spark-ui-proxy" {
  name         = "spark-ui-proxy"
  space        = data.cloudfoundry_space.space.id
  memory       = 1024
  disk_quota   = 2048
  health_check_type = "process"
  docker_image = "ursuad/spark-ui-proxy:v1.0.0"
  command      = "python /spark-ui-proxy.py ${cloudfoundry_route.spark-master.endpoint}:8080"

  routes {
    route = cloudfoundry_route.spark-ui-proxy.id
  }
}

resource "cloudfoundry_route" "spark-ui-proxy" {
  domain   = data.cloudfoundry_domain.external.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "sup" : "sup-${var.name_postfix}"
}

resource "cloudfoundry_network_policy" "my_policy" {
  policy {
    source_app      = cloudfoundry_app.spark-master.id
    destination_app = cloudfoundry_app.spark-worker.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

  policy {
    source_app      = cloudfoundry_app.spark-worker.id
    destination_app = cloudfoundry_app.spark-master.id
    port            = "1000-65353"
    protocol        = "tcp"
  }


  policy {
    source_app      = cloudfoundry_app.spark-worker.id
    destination_app = cloudfoundry_app.spark-worker.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

  policy {
    source_app      = cloudfoundry_app.spark-history-server.id
    destination_app = cloudfoundry_app.spark-master.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-history-server.id
    destination_app = cloudfoundry_app.spark-worker.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-master.id
    destination_app = cloudfoundry_app.spark-history-server.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-worker.id
    destination_app = cloudfoundry_app.spark-history-server.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

  policy {
    source_app      = cloudfoundry_app.spark-ui-proxy.id
    destination_app = cloudfoundry_app.spark-worker.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

  policy {
    source_app      = cloudfoundry_app.spark-ui-proxy.id
    destination_app = cloudfoundry_app.spark-master.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

}
