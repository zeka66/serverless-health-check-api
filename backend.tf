terraform {
  # Partial configuration: bucket and key are supplied per environment via
  #   terraform init -backend-config=envs/<env>.backend.hcl
  # so that staging and prod never share a state file.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
