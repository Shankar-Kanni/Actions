provider "google" {
    project = "terra-55091"
    region = "europe-west3" 
}

resource "google_compute_instance" "vm_instance" {
    name         = "gcptutorials-vm"
    machine_type = "f1-micro"
    zone = "europe-west3-a"

    boot_disk {
    initialize_params {
        image = "debian-cloud/debian-9"
    }
    }    
    network_interface {       
    network = "default"
    access_config {
    }
    }
}