param(
    [string]$CodeRepository = (Join-Path $env:USERPROFILE 'kubernetes-kurssi')
)
$ErrorActionPreference = 'Stop'
$repositoryUrl = 'https://github.com/Aipera/kubernetes-kurssi-config.git'
function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    & git @args
    if ($LASTEXITCODE -ne 0) { throw 'Git command failed.' }
}
Push-Location (Join-Path $PSScriptRoot '..')
try {
    # Two commits are intentional: a configuration snapshot must already exist
    # before the production Application can be pinned to that commit.
    if (-not (Test-Path -LiteralPath '.git')) {
        Invoke-Git init --initial-branch=main
        Invoke-Git remote add origin $repositoryUrl
    }
    $origin = [string](Invoke-Git remote get-url origin)
    if ($origin.TrimEnd('/') -ne $repositoryUrl) {
        throw 'This directory must be the kubernetes-kurssi-config repository.'
    }
    if (([string](Invoke-Git branch --show-current)) -ne 'main') {
        throw 'Initialize the configuration repository on main.'
    }
    # Reuse the identity that already works in the code repository.
    foreach ($setting in @('user.name', 'user.email')) {
        $identity = [string](Invoke-Git -C $CodeRepository config --get $setting)
        if ([string]::IsNullOrWhiteSpace($identity)) { throw "Missing $setting in the code repository." }
        Invoke-Git config --local $setting $identity
    }
    $releasePath = Join-Path (Get-Location) 'gitops/todo-apps/production-release.json'
    $release = Get-Content -LiteralPath $releasePath -Raw | ConvertFrom-Json
    if ($release.spec.source.targetRevision -eq 'CONFIG_INITIAL_COMMIT') {
        Invoke-Git add --all
        Invoke-Git commit -m 'Move Todo configuration to its own repository'
        $snapshot = [string](Invoke-Git rev-parse HEAD)
        $release.spec.source.targetRevision = $snapshot
        $json = ($release | ConvertTo-Json -Depth 20) + "`n"
        [System.IO.File]::WriteAllText($releasePath, $json, (New-Object System.Text.UTF8Encoding($false)))
        Invoke-Git add -- gitops/todo-apps/production-release.json
        Invoke-Git commit -m 'Pin existing production to the configuration snapshot'
    }
    else {
        if ([string]$release.spec.source.targetRevision -notmatch '^[a-f0-9]{40}$') {
            throw 'Production must point to a configuration commit.'
        }
        Invoke-Git cat-file -e "$($release.spec.source.targetRevision)^{commit}"
        if (Invoke-Git status --porcelain) { throw 'Commit or save local changes before retrying the push.' }
    }
    Invoke-Git push --set-upstream origin main
    Write-Host 'Configuration repository published. Existing production images are preserved.'
}
finally { Pop-Location }
