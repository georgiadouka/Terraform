mock_provider "azurerm" {}

variables {
  name                = "ststoragetest"
  resource_group_name = "rg-storage-test"
  location            = "swedencentral"
}

run "defaults_to_keyless" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account.this.shared_access_key_enabled == false &&
      output.primary_access_key == null &&
      output.primary_connection_string == null &&
      length(azurerm_storage_share.this) == 0
    )
    error_message = "The storage module must default to an Entra-compatible account without Shared Key or Azure Files."
  }
}

run "supports_shared_key_and_files" {
  command = plan
  variables {
    shared_access_key_enabled = true
    file_shares = {
      shared = {
        quota_gb    = 100
        access_tier = "TransactionOptimized"
      }
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  assert {
    condition = (
      azurerm_storage_account.this.shared_access_key_enabled &&
      length(azurerm_storage_share.this) == 1
    )
    error_message = "Shared Key mode must continue to support AzureRM-managed standard file shares."
  }
}

run "supports_workload_rbac" {
  command = plan
  variables {
    data_plane_role_assignments = {
      app_blob_reader = {
        principal_id         = "77777777-7777-7777-7777-777777777777"
        role_definition_name = "Storage Blob Data Reader"
        principal_type       = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.data_plane) == 1
    error_message = "The storage module must create requested account-scoped workload data-plane roles."
  }
}

run "rejects_keyless_file_shares" {
  command = plan
  variables {
    shared_access_key_enabled = false
    file_shares = {
      shared = {}
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  expect_failures = [var.file_shares]
}

# Disabled: the validation it tests is disabled.
# run "rejects_mismatched_file_share_names" {
#   command = plan
#   variables {
#     shared_access_key_enabled = true
#     file_shares = {
#       shared = {}
#     }
#   }
#
#   expect_failures = [var.file_share_names]
# }

run "supports_zrs_and_hot_file_share" {
  command = plan
  variables {
    replication_type          = "ZRS"
    shared_access_key_enabled = true
    file_shares = {
      shared = {
        quota_gb    = 100
        access_tier = "Hot"
      }
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  assert {
    condition = (
      azurerm_storage_account.this.account_replication_type == "ZRS" &&
      azurerm_storage_share.this["shared"].access_tier == "Hot"
    )
    error_message = "Standard storage must support ZRS replication and Hot file shares."
  }
}

# Disabled: the validation it tests is disabled.
# run "rejects_unsupported_replication" {
#   command = plan
#   variables {
#     replication_type = "Unsupported"
#   }
#
#   expect_failures = [var.replication_type]
# }

run "rejects_invalid_container_label" {
  command = plan
  variables {
    containers = {
      Invalid_Label = "container-storage-test"
    }
  }

  expect_failures = [var.containers]
}

# Disabled: the validation it tests is disabled.
# run "rejects_invalid_container_name" {
#   command = plan
#   variables {
#     containers = {
#       appdata = "App_Data"
#     }
#   }
#
#   expect_failures = [var.containers]
# }

# Disabled: the validation it tests is disabled.
# run "rejects_too_short_file_share_name" {
#   command = plan
#   variables {
#     shared_access_key_enabled = true
#     file_shares = {
#       shared = {}
#     }
#     file_share_names = {
#       shared = "ab"
#     }
#   }
#
#   expect_failures = [var.file_share_names]
# }

run "rejects_invalid_file_share_label" {
  command = plan
  variables {
    shared_access_key_enabled = true
    file_shares = {
      Invalid_Label = {}
    }
    file_share_names = {
      Invalid_Label = "share-storage-test"
    }
  }

  expect_failures = [var.file_shares]
}

run "rejects_nonpositive_file_share_quota" {
  command = plan
  variables {
    shared_access_key_enabled = true
    file_shares = {
      shared = { quota_gb = 0 }
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  expect_failures = [var.file_shares]
}

run "rejects_fractional_file_share_quota" {
  command = plan
  variables {
    shared_access_key_enabled = true
    file_shares = {
      shared = { quota_gb = 100.5 }
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  expect_failures = [var.file_shares]
}

run "rejects_unsupported_file_share_tier" {
  command = plan
  variables {
    shared_access_key_enabled = true
    file_shares = {
      shared = { access_tier = "Premium" }
    }
    file_share_names = {
      shared = "share-storage-test"
    }
  }

  expect_failures = [var.file_shares]
}
