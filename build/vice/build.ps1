param(
	[string]$SourceDir = "third_party/vice",
	[string]$DestDir = "artifacts/vice/win10-x64",
	[int]$Jobs = 4,
	[string]$ViceRepo = "https://svn.code.sf.net/p/vice-emu/code/trunk",
	[string]$ViceRevision = ""
)

Write-Host "Build VICE (Windows mingw64)"
Write-Host "SourceDir: $SourceDir"
Write-Host "DestDir: $DestDir"

# Auto-checkout VICE via SVN if missing or empty
if (-not (Test-Path $SourceDir) -or -not (Get-ChildItem -Path $SourceDir -Recurse -Force | Where-Object { $_.PSIsContainer -or $_.Name -ne '.gitkeep' })) {
	Write-Host "VICE source not found or empty at '$SourceDir'. Checking out from $ViceRepo"
	# Prefer git-svn if available (allows cloning into a git repo with svn history)
	$useGitSvn = $false
	try { & git svn --version > $null 2>&1; $useGitSvn = $true } catch { $useGitSvn = $false }

	Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Path $SourceDir
	New-Item -ItemType Directory -Force -Path $SourceDir | Out-Null

	if ($useGitSvn) {
		Write-Host "Using git-svn to clone VICE (git svn clone)"
		if ($ViceRevision -ne "") {
			$allArgs = @("svn", "clone", "-r", $ViceRevision, $ViceRepo, $SourceDir)
		} else {
			$allArgs = @("svn", "clone", $ViceRepo, $SourceDir)
		}
		$procClone = Start-Process -FilePath "git" -ArgumentList $allArgs -NoNewWindow -Wait -PassThru
		if ($procClone.ExitCode -ne 0) {
			Write-Error "git-svn clone failed with exit code $($procClone.ExitCode); attempting SVN checkout fallback"
		} else {
			$gitCloneSucceeded = $true
		}
	}

	if (-not $useGitSvn -or -not ($gitCloneSucceeded)) {
		try {
			svn --version > $null 2>&1
		} catch {
			Write-Error "Neither git-svn nor svn are available on PATH. Please install git with git-svn or Subversion (svn) on the runner."
			exit 4
		}

		if ($ViceRevision -ne "") {
			$procCheckout = Start-Process -FilePath "svn" -ArgumentList @("checkout", "-r", $ViceRevision, $ViceRepo, $SourceDir) -NoNewWindow -Wait -PassThru
		} else {
			$procCheckout = Start-Process -FilePath "svn" -ArgumentList @("checkout", $ViceRepo, $SourceDir) -NoNewWindow -Wait -PassThru
		}

		if ($procCheckout.ExitCode -ne 0) {
			Write-Error "SVN checkout failed with exit code $($procCheckout.ExitCode)"
			exit $procCheckout.ExitCode
		}
	}
}

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

$msysBash = "C:\\msys64\\usr\\bin\\bash.exe"
if (-not (Test-Path $msysBash)) {
	Write-Error "MSYS2 bash not found at $msysBash. Please install MSYS2 and run this script from an MSYS2 MinGW64 shell or ensure bash.exe is available."
	exit 3
}

$uSource = (& $msysBash -lc "cygpath -u \"$(Resolve-Path $SourceDir)\"").Trim()
$uDest = (& $msysBash -lc "cygpath -u \"$(Resolve-Path $DestDir)\"").Trim()

$bashInner = "cd '$uSource' && (./autogen.sh || true) && ./configure --host=x86_64-w64-mingw32 --prefix=/mingw64 && make -j$Jobs && make install DESTDIR='$uDest'"

Write-Host "Invoking MSYS2 bash to build VICE..."
Write-Host $bashInner

$proc = Start-Process -FilePath $msysBash -ArgumentList @('-lc', $bashInner) -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
	Write-Error "VICE build failed with exit code $($proc.ExitCode)"
	exit $proc.ExitCode
}

Write-Host "VICE build completed. Artifacts installed to: $DestDir"
exit 0
