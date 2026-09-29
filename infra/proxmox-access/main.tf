terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.104.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
}

locals {
  group_dn = "cn=groups,cn=accounts,dc=powerlan,dc=empire"
}

resource "proxmox_realm_ldap" "freeipa" {
  realm                 = "freeipa"
  server1               = "ldap.powerlan.empire"
  port                  = 636
  base_dn               = "cn=users,cn=accounts,dc=powerlan,dc=empire"
  user_attr             = "uid"
  user_classes          = "inetOrgPerson"
  filter                = "(|(memberOf=cn=grp-ro-monitor,${local.group_dn})(memberOf=cn=grp-proxmox-admin,${local.group_dn})(memberOf=cn=grp-vm-operator,${local.group_dn}))"
  group_dn              = local.group_dn
  group_classes         = "groupOfNames"
  group_name_attr       = "cn"
  group_filter          = "(|(cn=grp-ro-monitor)(cn=grp-proxmox-admin)(cn=grp-vm-operator))"
  sync_attributes       = "email=mail,firstname=givenName,lastname=sn"
  bind_dn               = "uid=proxmox-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire"
  bind_password         = trimspace(file(pathexpand(var.ldap_bind_password_path)))
  mode                  = "ldaps"
  verify                = true
  ca_path               = "/etc/pve/priv/freeipa-ca.crt"
  comment               = "FreeIPA identities and access groups; managed by nixcfg"
  sync_defaults_options = "scope=both,enable-new=1,remove-vanished=entry;acl"
}

resource "terraform_data" "freeipa_policy" {
  input = filesha256("../freeipa/policy.toml")
}

resource "proxmox_realm_sync" "freeipa" {
  realm           = proxmox_realm_ldap.freeipa.realm
  scope           = "both"
  enable_new      = true
  remove_vanished = "entry;acl"

  lifecycle {
    replace_triggered_by = [terraform_data.freeipa_policy]
  }
}

resource "proxmox_acl" "infra_reader" {
  path       = "/"
  group_id   = "grp-ro-monitor-freeipa"
  role_id    = "PVEAuditor"
  propagate  = true
  depends_on = [proxmox_realm_sync.freeipa]
}

resource "proxmox_acl" "platform_admin" {
  path       = "/"
  group_id   = "grp-proxmox-admin-freeipa"
  role_id    = "Administrator"
  propagate  = true
  depends_on = [proxmox_realm_sync.freeipa]
}
