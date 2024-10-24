provider "google" {
    project = "terra-55091"
    region = "us-central1" 
}

resource "google_compute_instance" "vm_instance" {
    name         = "gcptutorials-vm"
    machine_type = "f1-micro"
    zone = "us-central1-a"

    boot_disk {
    initialize_params {
        image = "debian-cloud/debian-11"
    }
    }    
    network_interface {       
    network = "default"
    access_config {
    }
    }
}