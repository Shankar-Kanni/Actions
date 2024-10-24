provider "google" {
    credntials = ${{ secrets.CREDENTIALS }}
    project = "My Project 73350"
    region = "europe-west3-a"
}

resource "google_compute_instance" "vm_instance" {
    name         = "gcptutorials-vm"
    machine_type = "f1-micro"

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