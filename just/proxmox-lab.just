# Start the local Proxmox lab, creating missing components.
lab-up:
  @nix run path:.#proxmox-lab -- up

# Gracefully stop all lab guests and Proxmox, retaining disks.
lab-down:
  @nix run path:.#proxmox-lab -- down

# Show lab addresses, state and diagnostics.
lab-status:
  @nix run path:.#proxmox-lab -- status

# Archive the stopped lab and rebuild a clean environment.
lab-reset:
  @nix run path:.#proxmox-lab -- reset

# Activate the configured bridge with automatic NetworkManager rollback.
lab-network:
  @nix run path:.#proxmox-lab -- network

# Print the lab settings without changing anything.
lab-plan:
  @nix run path:.#proxmox-lab -- plan

# Build the transferable Forgejo system disk.
forgejo-image:
  @nix run path:.#proxmox-lab -- image

# Deploy the current Nix configuration to the local Forgejo VM.
forgejo-deploy:
  @nix run path:.#proxmox-lab -- deploy

# Create a consistent, stopped-VM backup and copy it to wodan.
forgejo-backup:
  @nix run path:.#proxmox-lab -- backup

# Restore a backup into a separate VM on an isolated network.
forgejo-restore archive:
  @nix run path:.#proxmox-lab -- restore {{quote(archive)}}

# Verify login and Git push/clone with a dedicated test repository.
forgejo-smoke:
  @nix run path:.#proxmox-lab -- smoke

# Display the initial Forgejo administrator password locally.
forgejo-password:
  @nix run path:.#proxmox-lab -- password

# Boot the real guest image and check rejected disks, Git, persistence and recovery.
forgejo-image-check:
  @nix run path:.#proxmox-lab -- test-image

# Test controller boundaries without changing the lab.
lab-controller-check:
  @nix run path:.#proxmox-lab -- test-controller
