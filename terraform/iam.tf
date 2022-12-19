
# You need to start with a service account called "terraform" which has both the 'editor' and 'owner' basic permissions.
# This allows it to assign permissions to resources per https://cloud.google.com/iam/docs/understanding-roles


resource "google_service_account" "operating_service_account" {
  account_id   = "${var.resource_affix}-${var.environment}-server"
  display_name = "${var.resource_affix}-${var.environment}-server"
  description  = "Operate the example server in the cloud or local environment"
  project      = var.project
}


resource "google_project_iam_binding" "operating_service_account_user" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${google_service_account.operating_service_account.email}",
  ]
}


resource "google_service_account" "github_actions_service_account" {
    account_id   = "github-actions-ci"
    description  = "Allow GitHub Actions to deploy code onto resources"
    display_name = "github-actions-ci"
    project      = var.project
}


resource "google_project_iam_binding" "github_actions_service_account_user" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${google_service_account.github_actions_service_account.email}",
  ]
}


resource "google_project_iam_binding" "github_actions_artifactregistry_writer" {
  project = var.project
  role    = "roles/artifactregistry.writer"
  members = [
    "serviceAccount:${google_service_account.github_actions_service_account.email}",
  ]
}


resource "google_iam_workload_identity_pool" "github_actions_pool" {
    display_name              = "github-actions-pool"
    project                   = var.project
    workload_identity_pool_id = "github-actions-pool"
}


resource "google_iam_workload_identity_pool_provider" "github_actions_provider" {
    attribute_mapping                  = {
        "attribute.actor"            = "assertion.actor"
        "attribute.repository"       = "assertion.repository"
        "attribute.repository_owner" = "assertion.repository_owner"
        "google.subject"             = "assertion.sub"
    }
    display_name                       = "Github Actions Provider"
    project                            = var.project_number
    workload_identity_pool_id          = "github-actions-pool"
    workload_identity_pool_provider_id = "github-actions-provider"

    oidc {
        allowed_audiences = []
        issuer_uri        = "https://token.actions.githubusercontent.com"
    }
}

data "google_iam_policy" "github_actions_workload_identity_pool_policy" {
  binding {
    role = "roles/iam.workloadIdentityUser"
    members = [
      "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_actions_pool.workload_identity_pool_id}/attribute.repository_owner/${var.github_organisation}"
    ]
  }
}

resource "google_service_account_iam_policy" "github_actions_workload_identity_service_account_policy" {
  service_account_id = google_service_account.github_actions_service_account.name
  policy_data        = data.google_iam_policy.github_actions_workload_identity_pool_policy.policy_data
}
