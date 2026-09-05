output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "zone" {
  description = "Zone of the VM."
  value       = var.zone
}

output "instance_name" {
  description = "VM name."
  value       = google_compute_instance.web.name
}

output "internal_ip" {
  description = "The VM's internal IP. There is no external one."
  value       = google_compute_instance.web.network_interface[0].network_ip
}

output "bucket_name" {
  description = "Bucket holding the Ansible assets."
  value       = google_storage_bucket.ansible.name
}

output "ssh_example" {
  description = "Reach the VM over IAP."
  value       = "gcloud compute ssh ${google_compute_instance.web.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "curl_via_iap_tunnel_example" {
  description = "Forward port 80 over IAP, then curl nginx from outside the VPC. The VM has no external IP."
  value       = "gcloud compute start-iap-tunnel ${google_compute_instance.web.name} 80 --local-host-port=localhost:8080 --zone=${var.zone} --project=${var.project_id} & sleep 5 && curl -s http://localhost:8080/healthz"
}

output "startup_log_example" {
  description = "The startup script's own log. Its line count is how first-boot-only behaviour is checked."
  value       = "gcloud compute ssh ${google_compute_instance.web.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id} --command='sudo wc -l /var/log/startup-ansible.log'"
}

output "rerun_playbook_example" {
  description = "Re-run Ansible on the existing VM. This is what a playbook edit needs, because the startup script will not run again."
  value       = "gcloud compute ssh ${google_compute_instance.web.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id} --command='sudo gcloud storage rsync -r gs://${google_storage_bucket.ansible.name}/ansible /opt/ansible && cd /opt/ansible && sudo ansible-playbook -i inventory.ini playbooks/site.yml -c local'"
}
