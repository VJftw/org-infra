resource "google_service_account" "github_repository_pr" {
  provider = google-beta
  project  = google_project.github_actions.project_id


  for_each = local.github_repository_roles

  account_id   = "gha-pr-${lower(replace(each.key, "/\\.|//", "-"))}"
  display_name = "GitHub Actions PRs: ${each.key}"
  description  = "GitHub Actions service account for Pull Requests on ${each.key}"
}

resource "google_organization_iam_member" "github_repository_pr" {
  provider = google-beta

  for_each = toset(flatten([
    for gh_repo, config in local.github_repository_roles : [
      for role in lookup(lookup(config, "pull_request", {}), "organization", []) : [
        "${gh_repo}:${role}"
      ]
    ]
  ]))

  org_id = trimprefix(data.google_organization.org.id, "organizations/")

  role   = split(":", each.key)[1]
  member = "serviceAccount:${google_service_account.github_repository_pr[split(":", each.key)[0]].email}"
}

resource "google_project_iam_member" "github_repository_pr" {
  provider = google-beta

  for_each = toset(flatten([
    for gh_repo, config in local.github_repository_roles : [
      for project, roles in lookup(lookup(config, "pull_request", {}), "projects", {}) : [
        for role in roles : ["${gh_repo}:${project}:${role}"]
      ]
    ]
  ]))


  project = split(":", each.key)[1]

  role = split(":", each.key)[2]

  member = "serviceAccount:${google_service_account.github_repository_pr[split(":", each.key)[0]].email}"
}


resource "google_service_account_iam_member" "github_repository_pr" {
  provider = google-beta

  for_each = local.github_repository_roles

  service_account_id = google_service_account.github_repository_pr[each.key].name
  role               = "roles/iam.workloadIdentityUser"

  # member = "principal://iam.googleapis.com/projects/${google_project.github_actions.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_actions.workload_identity_pool_id}/subject/${each.key}"

  member = join("/", [
    "principal://iam.googleapis.com/projects/${google_project.github_actions.number}",
    "locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_actions.workload_identity_pool_id}",
    # repo:octo-org/octo-repo:pull_request
    # limit to only PRs
    "subject/repo:${each.key}:pull_request",
  ])

}

resource "google_billing_account_iam_member" "github_actions_pr" {
  provider = google-beta

  for_each = local.github_repository_roles

  billing_account_id = data.google_billing_account.billing.id
  role               = "roles/billing.viewer"

  # member = "principal://iam.googleapis.com/projects/${google_project.github_actions.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_actions.workload_identity_pool_id}/subject/${each.key}"

  member = join("/", [
    "principal://iam.googleapis.com/projects/${google_project.github_actions.number}",
    "locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_actions.workload_identity_pool_id}",
    # repo:octo-org/octo-repo:pull_request
    # limit to only PRs
    "subject/repo:${each.key}:pull_request",
  ])
}
