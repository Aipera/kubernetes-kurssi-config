param(
    [string]$Context = 'gke_project-e08f1dba-8ab7-491a-90a_europe-north1-b_dwk-cluster',
    [int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
$repositoryUrl = 'https://github.com/Aipera/kubernetes-kurssi-config.git'
function Invoke-Kube {
    $ErrorActionPreference = 'Continue'
    & kubectl "--context=$Context" @args
    if ($LASTEXITCODE -ne 0) { throw 'Kubernetes command failed.' }
}
function Wait-Application {
    param([string]$Name, [string]$Revision)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $json = Invoke-Kube -n argocd get application $Name -o json
        $app = ($json | Out-String) | ConvertFrom-Json
        # A previously Healthy status can be stale after applying a new source.
        # Require the new repository AND the expected configuration revision.
        if ($app.status.sync.comparedTo.source.repoURL -eq $repositoryUrl -and
            $app.status.sync.revision -eq $Revision -and
            $app.status.sync.status -eq 'Synced' -and
            $app.status.health.status -eq 'Healthy') {
            Write-Host "${Name}: Synced and Healthy from the configuration repository."
            return
        }
        Write-Host ("Waiting for {0}: sync={1}, health={2}" -f $Name, $app.status.sync.status, $app.status.health.status)
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    Invoke-Kube -n argocd get application $Name
    throw "Timed out waiting for $Name. Existing workloads have not been deleted."
}
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $mainRevision = & git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Run this script from the initialized configuration repository.' }
    $remote = & git ls-remote origin refs/heads/main
    if ($LASTEXITCODE -ne 0 -or -not $remote -or ($remote -split '\s+')[0] -ne $mainRevision) {
        throw 'Push this configuration commit to main before connecting Argo CD.'
    }
    $release = Get-Content -LiteralPath 'gitops/todo-apps/production-release.json' -Raw | ConvertFrom-Json
    $productionRevision = [string]$release.spec.source.targetRevision
    if ($productionRevision -notmatch '^[a-f0-9]{40}$') { throw 'Initialize the repository before connecting Argo CD.' }
    Invoke-Kube kustomize gitops/todo-apps | Out-Null
    # Update the existing parent Application. Keep child names, namespaces,
    # Secrets and PVCs so Argo CD continues managing the same workloads.
    Invoke-Kube apply -f gitops/todo-application.yaml
    Invoke-Kube -n argocd annotate application todo-environments argocd.argoproj.io/refresh=hard --overwrite | Out-Null
    Wait-Application -Name 'todo-environments' -Revision $mainRevision
    Wait-Application -Name 'todo-staging' -Revision $mainRevision
    Wait-Application -Name 'todo-project' -Revision $productionRevision
    Invoke-Kube -n argocd get application todo-environments todo-staging todo-project
}
finally { Pop-Location }
