
# 2. Configuration de la connexion à ton Grafana
provider "grafana" {
  url  = "http://localhost:3000"
  auth = "glsa_mMoZ6MS8BAr6D0PCR8SQlOsUHZzwcd7G_47ac4983"
}

# 3. Déclaration des variables pour tes clés AWS Academy
variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }
variable "aws_session_token" { type = string }

resource "grafana_data_source" "cloudwatch" {
  type = "cloudwatch"
  name = "AWS-Academy-Auto"

  # On utilise le format 'encoded' pour éviter l'erreur 'Unsupported block type'
  json_data_encoded = jsonencode({
    defaultRegion           = "us-east-1"
    authType                = "keys"
    customMetricsNamespaces = "SessionToken:${var.aws_session_token}"
  })

  secure_json_data_encoded = jsonencode({
    accessKey = var.aws_access_key
    secretKey = var.aws_secret_key
  })
}

# 5. Injection de tes graphiques (Dashboard)
resource "grafana_dashboard" "monitoring" {
  config_json = file("dashboard.json")
}