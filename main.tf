
resource "yandex_vpc_address" "custom_addr" {
  name = "exampleAddress"

  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

locals {
  backend_instances  = [for v in yandex_compute_instance.backend : v.network_interface.0.ip_address]
  nginx_instances    = [for v in yandex_compute_instance.nginx : v.network_interface.0.ip_address]
  database_instances = [for v in yandex_compute_instance.database : v.network_interface.0.ip_address]
  database_ips       = "${yandex_compute_instance.database[0].network_interface.0.ip_address},${yandex_compute_instance.database[1].network_interface.0.ip_address},${yandex_compute_instance.database[2].network_interface.0.ip_address}"
  vault_instance     = yandex_compute_instance.vault.network_interface.0.ip_address
  admin_instance     = yandex_compute_instance.admin.network_interface.0.nat_ip_address
  vault_public       = yandex_compute_instance.vault.network_interface.0.nat_ip_address
  kms_id             = yandex_kms_symmetric_key.key-a.id
}

resource "local_file" "hosts-ini" {
  filename = "hosts.ini"
  content = templatefile("hosts.tftpl", {
    backend_instances  = local.backend_instances
    nginx_instances    = local.nginx_instances
    database_instances = local.database_instances
    admin_instance     = local.admin_instance
    vault_instance     = local.vault_instance
    private_key_path   = var.private_key_path
  })
}

resource "local_file" "vault-hcl" {
  filename = "vault.hcl"
  content = templatefile("vault.tftpl", {
    vault_public = local.vault_public
    kms_id       = local.kms_id
  })
}

resource "yandex_compute_instance" "backend" {
  platform_id = "standard-v1"
  hostname    = "backend-${count.index}"
  count       = 2

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8idfolcq1l43h1mlft" # ОС (Ubuntu, 22.04 LTS)
    }

  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.custom_subnet.id
    security_group_ids = [yandex_vpc_security_group.custom_sg.id]
    nat                = false
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${var.public_key}"
  }
}

resource "yandex_compute_instance" "vault" {
  platform_id = "standard-v1"
  hostname    = "vault"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8psv72sc6bu1a75ukc" # ОС (Vault)
    }

  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.custom_subnet.id
    security_group_ids = [yandex_vpc_security_group.custom_sg.id]
    nat                = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${var.public_key}"
  }
  service_account_id = yandex_iam_service_account.custom_sa.id
}

resource "yandex_compute_instance" "database" {
  platform_id = "standard-v1"
  hostname    = "database-${count.index}"
  count       = 3

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8idfolcq1l43h1mlft" # ОС (Ubuntu, 22.04 LTS)
    }

  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.custom_subnet.id
    security_group_ids = [yandex_vpc_security_group.custom_sg.id]
    nat                = false
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${var.public_key}"
  }
}

resource "yandex_compute_instance" "nginx" {
  platform_id = "standard-v1"
  hostname    = "nginx-${count.index}"
  count       = 2

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8idfolcq1l43h1mlft" # ОС (Ubuntu, 22.04 LTS)
    }

  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.custom_subnet.id
    security_group_ids = [yandex_vpc_security_group.custom_sg.id]
    nat                = false
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${var.public_key}"
  }
}

resource "yandex_compute_instance" "admin" {
  platform_id = "standard-v1"
  hostname    = "admin"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8idfolcq1l43h1mlft" # ОС (Ubuntu, 22.04 LTS)
    }

  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.custom_subnet.id
    security_group_ids = [yandex_vpc_security_group.custom_sg.id]
    nat                = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${var.public_key}"
  }
}

resource "yandex_vpc_network" "custom_vpc" {
  name = "custom_vpc"

}
resource "yandex_vpc_subnet" "custom_subnet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.custom_vpc.id
  v4_cidr_blocks = ["10.5.0.0/24"]
  route_table_id = yandex_vpc_route_table.custom_nat_route_table.id
}

resource "yandex_vpc_security_group" "custom_sg" {
  name        = "WebServer security group"
  description = "My Security group"
  network_id  = yandex_vpc_network.custom_vpc.id

  dynamic "ingress" {
    for_each = ["80", "443", "22", "3306", "33060", "4567", "4444", "4568", "6032", "6033", "8200", "8201", "5601"]
    content {
      protocol       = "TCP"
      v4_cidr_blocks = ["0.0.0.0/0"]
      port           = ingress.value
    }
  }

  egress {
    protocol       = "ANY"
    description    = "Outcoming traf"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = -1
  }
}

resource "yandex_vpc_gateway" "custom_nat_gateway" {
  name = "custom-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "custom_nat_route_table" {
  name       = "custom_nat_route_table"
  network_id = yandex_vpc_network.custom_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.custom_nat_gateway.id
  }
}

resource "yandex_alb_load_balancer" "custom_balancer" {
  name = "my-load-balancer"

  network_id = yandex_vpc_network.custom_vpc.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.custom_subnet.id
    }
  }

  listener {
    name = "my-listener"
    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.custom_addr.external_ipv4_address[0].address
        }
      }
      ports = [80]
    }
    stream {
      handler {
        backend_group_id = yandex_alb_backend_group.custom_backend_group.id
      }
    }
  }
}


resource "yandex_alb_backend_group" "custom_backend_group" {
  name = "my-backend-group"

  stream_backend {
    name             = "test-stream-backend"
    weight           = 1
    port             = 80
    target_group_ids = ["${yandex_alb_target_group.custom_target_group.id}"]
    load_balancing_config {
      panic_threshold = 0
    }
    healthcheck {
      timeout  = "1s"
      interval = "1s"
      stream_healthcheck {
        send = ""
      }
    }
  }
}


resource "yandex_alb_target_group" "custom_target_group" {
  name = "my-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.custom_subnet.id
    ip_address = yandex_compute_instance.nginx[0].network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.custom_subnet.id
    ip_address = yandex_compute_instance.nginx[1].network_interface.0.ip_address
  }
}

resource "yandex_kms_symmetric_key" "key-a" {
  name              = "example-symetric-key"
  description       = "description for key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" // equal to 1 year
}

resource "yandex_iam_service_account" "custom_sa" {
  name        = "vault-sa"
  description = "service account to manage vault"
}

resource "yandex_resourcemanager_cloud_iam_binding" "admin" {
  cloud_id = var.cloud_id_variable
  role     = "kms.keys.encrypterDecrypter"
  members = [
    "serviceAccount:${yandex_iam_service_account.custom_sa.id}",
  ]
}



resource "terraform_data" "run_ansible" {
  depends_on = [yandex_compute_instance.database, yandex_compute_instance.nginx, yandex_compute_instance.backend, yandex_compute_instance.admin, yandex_compute_instance.vault]
  provisioner "local-exec" {
    command = <<EOF
    ansible-playbook -u ubuntu -i hosts.ini --private-key ${var.private_key_path} web-service.yml --extra-var "public_ip=${yandex_vpc_address.custom_addr.external_ipv4_address[0].address} database_ips=${local.database_ips} private_key=${var.private_key_path}"
    rm -rf /tmp/fetched
    EOF
  }
}
