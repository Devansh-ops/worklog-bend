#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $BundlePath = (Join-Path $PSScriptRoot 'worklog-bend.bundle'),
    [string] $Destination = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'personal\tanmay\worklog-test'),
    [switch] $SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# PowerShell 7 can otherwise turn a nonzero native exit into a terminating error.
# This variable is harmless on Windows PowerShell 5.1.
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-CheckedCommand {
    param(
        [string] $Command,
        [string[]] $Arguments,
        [switch] $AllowFailure
    )
    $previousPreference = $ErrorActionPreference
    try {
        # In PowerShell 5.1, native stderr is an ErrorRecord even on success.
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Command @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    $result = [pscustomobject]@{ ExitCode = $code; Output = $lines }
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "$Command failed (exit $code).`n$($lines -join "`n")"
    }
    return $result
}

function Invoke-LocalGit {
    param([string[]] $Arguments, [switch] $AllowFailure)
    Invoke-CheckedCommand -Command $script:Git -Arguments (@('-C', $script:DestinationPath) + $Arguments) -AllowFailure:$AllowFailure
}

function Get-LocalSetting {
    param([string] $Name)
    $result = Invoke-LocalGit -Arguments @('config', '--local', '--get', $Name) -AllowFailure
    if ($result.ExitCode -eq 1) { return '' }
    if ($result.ExitCode -ne 0) { throw "Could not read local Git setting $Name." }
    return ($result.Output -join "`n").Trim()
}

function Get-GitHubRepository {
    param([string] $Owner)
    $result = Invoke-CheckedCommand -Command $script:Gh -Arguments @(
        'api', '--hostname', 'github.com', '--include', '--method', 'GET', "repos/$Owner/worklog-bend"
    ) -AllowFailure
    $response = $result.Output -join "`n"
    $status = [regex]::Match($response, '(?m)^HTTP/\S+\s+(\d{3})\b')
    if ($status.Success -and $status.Groups[1].Value -eq '404') { return $null }
    if ($result.ExitCode -ne 0 -or -not $status.Success -or $status.Groups[1].Value -ne '200') {
        throw 'Could not inspect the GitHub destination. Check gh auth status --hostname github.com and network access, then rerun.'
    }
    $parts = [regex]::Split($response, '\r?\n\r?\n', 2)
    if ($parts.Count -ne 2) { throw 'GitHub returned an unexpected response. No push was attempted.' }
    return ($parts[1] | ConvertFrom-Json)
}

try {
    $script:Git = (Get-Command git -CommandType Application -ErrorAction Stop).Source
    if (-not $SkipPush) {
        $script:Gh = (Get-Command gh -CommandType Application -ErrorAction Stop).Source
    }
    if (-not $PSBoundParameters.ContainsKey('BundlePath') -and -not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) {
        $BundlePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'worklog-bend.bundle'
    }
    if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) {
        throw "Bundle not found: $BundlePath. Extract both handoff files together, or supply -BundlePath."
    }
    $BundlePath = (Resolve-Path -LiteralPath $BundlePath).ProviderPath
    $script:DestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)

    # Verify a self-contained bundle in an empty object database before cloning.
    $verifyDirectory = Join-Path ([IO.Path]::GetTempPath()) ('worklog-bundle-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($verifyDirectory)
    try {
        $null = Invoke-CheckedCommand -Command $script:Git -Arguments @('init', '--bare', '--', $verifyDirectory)
        $null = Invoke-CheckedCommand -Command $script:Git -Arguments @('-C', $verifyDirectory, 'bundle', 'verify', $BundlePath)
        $heads = Invoke-CheckedCommand -Command $script:Git -Arguments @('bundle', 'list-heads', $BundlePath, 'refs/heads/main')
        $mainHeads = @($heads.Output | Where-Object { $_ -match '^[0-9a-f]{40,64} refs/heads/main$' })
        if ($mainHeads.Count -ne 1) { throw 'The bundle must contain exactly one refs/heads/main.' }
        $bundleCommit = ($mainHeads[0] -split ' ')[0]
    }
    finally {
        Remove-Item -LiteralPath $verifyDirectory -Recurse -Force
    }

    $reuse = $false
    if (Test-Path -LiteralPath $script:DestinationPath) {
        $target = Get-Item -LiteralPath $script:DestinationPath -Force
        if (-not $target.PSIsContainer -or ($target.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Destination must be an ordinary directory, not a file, junction, or symbolic link.'
        }
        $reuse = @(Get-ChildItem -LiteralPath $script:DestinationPath -Force).Count -gt 0
        if ($reuse) {
            $gitDirectory = Join-Path $script:DestinationPath '.git'
            if (-not (Test-Path -LiteralPath $gitDirectory -PathType Container)) {
                throw 'Destination is not empty. Choose an empty destination; this script will not overwrite it.'
            }
            $gitItem = Get-Item -LiteralPath $gitDirectory -Force
            if ($gitItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The destination Git directory must not be a link.' }
            if ((Get-LocalSetting 'worklogBend.handoffVersion') -ne '1' -or (Get-LocalSetting 'worklogBend.bundleCommit') -ne $bundleCommit) {
                throw 'Destination is not a checkout restored from this bundle by this script. No files were overwritten.'
            }
            $top = Invoke-LocalGit -Arguments @('rev-parse', '--show-toplevel')
            if (-not [string]::Equals([IO.Path]::GetFullPath(($top.Output -join '').Trim()), [IO.Path]::GetFullPath($script:DestinationPath), [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Destination is not the Git repository root.'
            }
            $branch = Invoke-LocalGit -Arguments @('symbolic-ref', '--short', 'HEAD')
            if (($branch.Output -join '').Trim() -ne 'main') { throw 'Switch this checkout to main before rerunning the handoff.' }
            $null = Invoke-LocalGit -Arguments @('merge-base', '--is-ancestor', $bundleCommit, 'refs/heads/main')
        }
    }

    $owner = ''
    $repository = $null
    if (-not $SkipPush) {
        $account = Invoke-CheckedCommand -Command $script:Gh -Arguments @('api', '--hostname', 'github.com', 'user')
        $user = ($account.Output -join "`n") | ConvertFrom-Json
        $owner = [string]$user.login
        if ($user.type -ne 'User' -or $owner -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$') {
            throw 'The authenticated GitHub account is not a supported personal account.'
        }
        $repository = Get-GitHubRepository -Owner $owner
        if ($null -ne $repository) {
            $recordedId = if ($reuse) { Get-LocalSetting 'worklogBend.githubRepositoryId' } else { '' }
            $recordedOwner = if ($reuse) { Get-LocalSetting 'worklogBend.githubOwner' } else { '' }
            if (-not $recordedId -or $recordedId -ne [string]$repository.id -or $recordedOwner -ne $owner) {
                throw "https://github.com/$owner/worklog-bend already exists without this checkout's creation record. Nothing was pushed. Review it before choosing another destination or asking for help."
            }
            if (-not $repository.private -or $repository.owner.login -ne $owner -or $repository.name -ne 'worklog-bend') {
                throw 'The recorded GitHub repository no longer matches the required private personal destination.'
            }
        }
    }

    if (-not $reuse) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $script:DestinationPath))
        $null = Invoke-CheckedCommand -Command $script:Git -Arguments @('clone', '--branch', 'main', '--single-branch', '--', $BundlePath, $script:DestinationPath)
        $null = Invoke-LocalGit -Arguments @('config', '--local', 'worklogBend.bundleCommit', $bundleCommit)
        # Git for Windows can normalize path separators in the stored URL.
        $clonedOrigin = Get-LocalSetting 'remote.origin.url'
        $null = Invoke-LocalGit -Arguments @('config', '--local', 'worklogBend.bundleOrigin', $clonedOrigin)
        $null = Invoke-LocalGit -Arguments @('config', '--local', 'worklogBend.handoffVersion', '1')
    }
    $null = Invoke-LocalGit -Arguments @('config', '--local', 'user.name', 'Devansh Sehgal')
    $null = Invoke-LocalGit -Arguments @('config', '--local', 'user.email', 'devanshsehgal02@gmail.com')
    $origin = Get-LocalSetting 'remote.origin.url'
    if ($origin -and $origin -eq (Get-LocalSetting 'worklogBend.bundleOrigin')) {
        $null = Invoke-LocalGit -Arguments @('remote', 'remove', 'origin')
        $origin = ''
    }
    $upstream = Get-LocalSetting 'remote.upstream.url'
    if ($upstream -and $upstream -ne 'https://github.com/tanmayagrawal21/worklog.git') {
        throw 'An unexpected upstream remote exists. Review it before rerunning.'
    }
    if (-not $upstream) {
        $null = Invoke-LocalGit -Arguments @('remote', 'add', 'upstream', 'https://github.com/tanmayagrawal21/worklog.git')
    }
    $null = Invoke-LocalGit -Arguments @('config', '--local', 'protocol.worklog-disabled.allow', 'never')
    $null = Invoke-LocalGit -Arguments @('config', '--local', '--replace-all', 'remote.upstream.pushurl', 'worklog-disabled://upstream')

    if ($SkipPush) {
        Write-Host "Restored and configured: $script:DestinationPath"
        Write-Host 'No GitHub access was requested. Rerun without -SkipPush when ready.'
        exit 0
    }

    $originUrl = "https://github.com/$owner/worklog-bend.git"
    if ($origin -and $origin -ne $originUrl) { throw 'An unexpected origin remote exists. Review it before rerunning.' }
    if ($null -eq $repository) {
        $null = Invoke-CheckedCommand -Command $script:Gh -Arguments @(
            'repo', 'create', "github.com/$owner/worklog-bend", '--private',
            '--description', 'Worklog source baseline and planned Bend rebuild'
        )
        $repository = Get-GitHubRepository -Owner $owner
        if ($null -eq $repository -or -not $repository.private -or $repository.owner.login -ne $owner -or $repository.name -ne 'worklog-bend') {
            throw 'Could not verify the newly created private repository. No push was attempted.'
        }
        $null = Invoke-LocalGit -Arguments @('config', '--local', 'worklogBend.githubOwner', $owner)
        $null = Invoke-LocalGit -Arguments @('config', '--local', 'worklogBend.githubRepositoryId', [string]$repository.id)
    }
    if (-not $origin) { $null = Invoke-LocalGit -Arguments @('remote', 'add', 'origin', $originUrl) }
    $pushUrls = Invoke-LocalGit -Arguments @('remote', 'get-url', '--push', '--all', 'origin')
    if ($pushUrls.Output.Count -ne 1 -or $pushUrls.Output[0].Trim() -ne $originUrl) {
        throw 'The effective origin push URL differs from the verified GitHub repository. Review Git URL rewrites and push URLs before rerunning.'
    }

    # Use the existing gh login for this push without changing global Git config.
    $oldPrompt = [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'Process')
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $null = Invoke-LocalGit -Arguments @(
            '-c', 'credential.helper=', '-c', 'credential.https://github.com.helper=!gh auth git-credential',
            'push', '--set-upstream', 'origin', 'refs/heads/main:refs/heads/main'
        )
    }
    finally {
        [Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', $oldPrompt, 'Process')
    }
    Write-Host "Restored: $script:DestinationPath"
    Write-Host "Pushed main to private repository: https://github.com/$owner/worklog-bend"
    Write-Host 'This is the source baseline. The full Bend implementation and checked proofs are pending.'
}
catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    Write-Host 'Stopped without force-pushing or overwriting an existing destination. Completed local work is preserved.'
    Write-Host 'If creation succeeded immediately before a connection failure, inspect worklog-bend on GitHub before retrying.'
    exit 1
}
