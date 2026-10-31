mock_provider "azurerm" {
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-logic-test"
    }
  }
}

variables {
  name                       = "logic-test"
  service_plan_name          = "asp-logic-test"
  resource_group_name        = "rg-test"
  location                   = "swedencentral"
  storage_account_name       = "stlogictest"
  storage_account_access_key = "test-only-storage-key"
  content_share_name         = "logic-app-content"
  virtual_network_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/logic"
}

run "private_by_default" {
  command = plan

  assert {
    condition = (
      azurerm_logic_app_standard.this.public_network_access == "Disabled" &&
      azurerm_logic_app_standard.this.https_only &&
      !azurerm_logic_app_standard.this.ftp_publish_basic_authentication_enabled &&
      !azurerm_logic_app_standard.this.scm_publish_basic_authentication_enabled &&
      !azurerm_logic_app_standard.this.client_affinity_enabled &&
      azurerm_logic_app_standard.this.vnet_content_share_enabled &&
      azurerm_logic_app_standard.this.virtual_network_subnet_id == var.virtual_network_subnet_id &&
      azurerm_logic_app_standard.this.identity[0].type == "SystemAssigned"
    )
    error_message = "The Logic App must be private, HTTPS-only, without basic publishing authentication, with its content share over the VNet and a system-assigned identity."
  }

  assert {
    condition = (
      azurerm_logic_app_standard.this.site_config[0].ftps_state == "Disabled" &&
      azurerm_logic_app_standard.this.site_config[0].min_tls_version == "1.2" &&
      azurerm_logic_app_standard.this.site_config[0].scm_min_tls_version == "1.2" &&
      azurerm_logic_app_standard.this.site_config[0].http2_enabled &&
      !azurerm_logic_app_standard.this.site_config[0].use_32_bit_worker_process &&
      azurerm_logic_app_standard.this.site_config[0].vnet_route_all_enabled &&
      azurerm_logic_app_standard.this.site_config[0].dotnet_framework_version == "v8.0"
    )
    error_message = "site_config must disable FTP, require TLS 1.2, run 64-bit on .NET 8 and route all outbound traffic through the VNet."
  }

  assert {
    condition = (
      azurerm_logic_app_standard.this.version == "~4" &&
      azurerm_logic_app_standard.this.storage_account_name == "stlogictest" &&
      azurerm_logic_app_standard.this.storage_account_share_name == "logic-app-content" &&
      azurerm_logic_app_standard.this.app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet" &&
      azurerm_logic_app_standard.this.app_settings["WEBSITE_NODE_DEFAULT_VERSION"] == "~22" &&
      azurerm_logic_app_standard.this.app_settings["WEBSITE_DNS_SERVER"] == "168.63.129.16" &&
      !contains(keys(azurerm_logic_app_standard.this.app_settings), "APPLICATIONINSIGHTS_CONNECTION_STRING")
    )
    error_message = "The app must run on Functions host v4 with the dotnet worker, Node.js ~22, Azure DNS and the pre-created content share, and send no telemetry by default."
  }

  assert {
    condition = (
      length(azurerm_service_plan.this) == 1 &&
      azurerm_service_plan.this[0].os_type == "Windows" &&
      azurerm_service_plan.this[0].sku_name == "WS1"
    )
    error_message = "service_plan_name must create a Windows WS1 plan by default."
  }
}

run "existing_plan" {
  command = plan

  variables {
    service_plan_name = null
    service_plan_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared"
  }

  assert {
    condition = (
      length(azurerm_service_plan.this) == 0 &&
      azurerm_logic_app_standard.this.app_service_plan_id == var.service_plan_id &&
      output.service_plan_id == var.service_plan_id
    )
    error_message = "service_plan_id must run the app on the existing plan without creating one."
  }
}

run "larger_plan_and_node_version" {
  command = plan

  variables {
    service_plan_sku_name = "WS3"
    node_version          = "24"
  }

  assert {
    condition = (
      azurerm_service_plan.this[0].sku_name == "WS3" &&
      azurerm_logic_app_standard.this.app_settings["WEBSITE_NODE_DEFAULT_VERSION"] == "~24"
    )
    error_message = "service_plan_sku_name and node_version must be applied."
  }
}

run "additional_app_settings" {
  command = plan

  variables {
    app_settings = {
      "Workflows.RuntimeConfiguration.RetentionInDays" = "30"
      ORDERS_QUEUE_NAME                                = "orders"
    }
  }

  assert {
    condition = (
      azurerm_logic_app_standard.this.app_settings["Workflows.RuntimeConfiguration.RetentionInDays"] == "30" &&
      azurerm_logic_app_standard.this.app_settings["ORDERS_QUEUE_NAME"] == "orders" &&
      azurerm_logic_app_standard.this.app_settings["FUNCTIONS_WORKER_RUNTIME"] == "dotnet"
    )
    error_message = "Additional app settings must be added next to the managed ones."
  }
}

run "reject_managed_app_setting" {
  command = plan

  variables {
    app_settings = { FUNCTIONS_WORKER_RUNTIME = "node" }
  }

  expect_failures = [var.app_settings]
}

run "reject_storage_app_setting" {
  command = plan

  variables {
    app_settings = { AzureWebJobsStorage = "UseDevelopmentStorage=true" }
  }

  expect_failures = [var.app_settings]
}

run "reject_both_plan_inputs" {
  command = plan

  variables {
    service_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/asp-shared"
  }

  expect_failures = [var.service_plan_id]
}

run "reject_no_plan_input" {
  command = plan

  variables {
    service_plan_name = null
  }

  expect_failures = [var.service_plan_id]
}

run "reject_non_workflow_sku" {
  command = plan

  variables {
    service_plan_sku_name = "EP1"
  }

  expect_failures = [var.service_plan_sku_name]
}

run "reject_prefixed_node_version" {
  command = plan

  variables {
    node_version = "~22"
  }

  expect_failures = [var.node_version]
}
