output "ids" {
  description = "Private Endpoint IDs keyed by storage subresource."
  value = {
    for subresource, id in {
      blob  = one(module.blob[*].id)
      file  = one(module.file[*].id)
      queue = one(module.queue[*].id)
      table = one(module.table[*].id)
    } : subresource => id
    if contains(keys(var.endpoints), subresource)
  }
}
