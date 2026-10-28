mock_provider "azurerm" {}

variables {
  name                = "stpremiumtest"
  resource_group_name = "rg-premium-test"
  location            = "swedencentral"
  file_shares = {
    premium = { quota_gb = 100 }
  }
  file_share_names = {
    premium = "share-premium-test"
  }
}

run "accept_defaults" {
  command = plan
}

run "accept_zrs_replication" {
  command = plan
  variables {
    replication_type = "ZRS"
  }
}

run "reject_unsupported_replication" {
  command = plan
  variables {
    replication_type = "GRS"
  }
  expect_failures = [var.replication_type]
}

run "reject_invalid_share_label" {
  command = plan
  variables {
    file_shares = {
      Invalid_Label = { quota_gb = 100 }
    }
    file_share_names = {
      Invalid_Label = "share-premium-test"
    }
  }
  expect_failures = [var.file_shares]
}

run "reject_quota_below_minimum" {
  command = plan
  variables {
    file_shares = {
      premium = { quota_gb = 99 }
    }
  }
  expect_failures = [var.file_shares]
}

run "reject_fractional_quota" {
  command = plan
  variables {
    file_shares = {
      premium = { quota_gb = 100.5 }
    }
  }
  expect_failures = [var.file_shares]
}

run "reject_mismatched_share_names" {
  command = plan
  variables {
    file_share_names = {}
  }
  expect_failures = [var.file_share_names]
}

run "reject_blank_share_name" {
  command = plan
  variables {
    file_share_names = {
      premium = " "
    }
  }
  expect_failures = [var.file_share_names]
}

run "reject_share_name_with_consecutive_hyphens" {
  command = plan
  variables {
    file_share_names = {
      premium = "premium--share"
    }
  }
  expect_failures = [var.file_share_names]
}

run "reject_duplicate_share_names" {
  command = plan
  variables {
    file_shares = {
      one = { quota_gb = 100 }
      two = { quota_gb = 100 }
    }
    file_share_names = {
      one = "share-premium-test"
      two = "SHARE-PREMIUM-TEST"
    }
  }
  expect_failures = [var.file_share_names]
}
