# tflint configuration — https://github.com/terraform-linters/tflint
# Run locally with: tflint --init && tflint --recursive
config {
  format = "compact"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
