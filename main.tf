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

resource "cloudfoundry_app" "spark-master" {
  name         = "spark-master"
  space        = data.cloudfoundry_space.space.id
  memory       = 1024
  disk_quota   = 2048
  health_check_type = "process"
  docker_image = "gcr.io/google_containers/spark:1.5.2_v1"
  command      = "sleep 20 && /bin/bash -c \". /start-common.sh; /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master --ip ${cloudfoundry_route.spark-master.endpoint} --port 7077 --webui-port 8080\""

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
  memory       = 4096
  disk_quota   = 2048
  instances    = 3
  stopped      = true
  docker_image = "gcr.io/google_containers/spark:1.5.2_v1"
  command      = "sleep 20 && /bin/bash -c \". /start-common.sh; /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://${cloudfoundry_route.spark-master.endpoint}:7077 --port 7077 --webui-port 8080 -m 2G -c 2\""
  routes {
    route = cloudfoundry_route.spark-worker.id
  }
}

resource "cloudfoundry_route" "spark-worker" {
  domain   = data.cloudfoundry_domain.internal.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-worker" : "spark-worker-${var.name_postfix}"
}


resource "cloudfoundry_app" "spark-user" {
  name         = "spark-user"
  space        = data.cloudfoundry_space.space.id
  memory       = 1024
  disk_quota   = 2048
  health_check_type = "process"
  docker_image = "gcr.io/google_containers/spark:1.5.2_v1"
  command      = "sleep 36000"

  environment = {
    "MASTER" = "spark://${cloudfoundry_route.spark-master.endpoint}:7077"
  }

  routes {
    route = cloudfoundry_route.spark-user.id
  }
}

resource "cloudfoundry_route" "spark-user" {
  domain   = data.cloudfoundry_domain.internal.id
  space    = data.cloudfoundry_space.space.id
  hostname = var.name_postfix == "" ? "spark-user" : "spark-user-${var.name_postfix}"

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
    source_app      = cloudfoundry_app.spark-user.id
    destination_app = cloudfoundry_app.spark-master.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-user.id
    destination_app = cloudfoundry_app.spark-worker.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-master.id
    destination_app = cloudfoundry_app.spark-user.id
    port            = "1000-65353"
    protocol        = "tcp"
  }

    policy {
    source_app      = cloudfoundry_app.spark-worker.id
    destination_app = cloudfoundry_app.spark-user.id
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
