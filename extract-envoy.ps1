param(
  [switch]$Clean,     # Remove the Docker image at the end
  [switch]$Wait       # Wait for a key press before shutting down the Docker daemon
)

$dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-20.10.13.zip"
$dockerImage = "envoyproxy/envoy-windows:v1.25.1"

# Check for administrator
function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
  Write-Output "This script must be ran as an administrator"
  exit 1
}

Write-Output "Extracting from $dockerImage"

# Get full paths
$dockerPath = Join-Path -Path $PSScriptRoot -ChildPath "docker\docker.exe"
$envoyDestPath = Join-Path -Path $PSScriptRoot -ChildPath "envoy.exe"
$envoyZipDestPath = Join-Path -Path $PSScriptRoot -ChildPath "envoy.zip"

# Install static docker.exe and dockerd.exe
if (-not (Test-Path -Path $dockerPath)) {
  $destination = Join-Path -Path $PSScriptRoot -ChildPath "docker.zip"

  Write-Output "Downloading static docker.exe and dockerd.exe"
  Write-Output "* Source: $dockerUrl"
  Write-Output "* Destination: $destination"
  Invoke-WebRequest -Uri $dockerUrl -OutFile $destination

  Write-Output "Expanding archive"
  Expand-Archive -Path $destination -DestinationPath $PSScriptRoot -Force  

  $configPath =  Join-Path -Path $PSScriptRoot -ChildPath "docker\daemon.json"
  Write-Output "Creating daemon.json"
  Set-Content -Path $configPath -Value "{ `"experimental`": false, `"hosts`": [ `"npipe:////./pipe/docker_engine`" ] }"  
}

# Start dockerd in the background
$job = Start-Job -Arg $PSScriptRoot -Scriptblock {
  param($PSScriptRoot) 

  $dockerdPath = Join-Path -Path $PSScriptRoot -ChildPath "docker\dockerd.exe"
  $configPath =  Join-Path -Path $PSScriptRoot -ChildPath "docker\daemon.json"

  Write-Output "Starting Docker daemon..."
  & $dockerdPath --run-service --service-name docker -G Users --config-file $configPath    
}

# Wait until dockerd is running
Start-Sleep 10
& $dockerPath images *>$NULL
$result = $LastExitCode

while($result -ne 0) {
    Receive-Job $job
    Write-Output "Unable to connect to Docker daemon. Waiting 10 seconds before trying again..."
    Start-Sleep 10
    & $dockerPath images *>$NULL
    $result = $LastExitCode    
}

# Extract
Write-Output ""
Write-Output "Pulling $dockerImage"
& $dockerPath pull $dockerImage
Write-Output ""
Write-Output "Creating container"
& $dockerPath create -ti --name envoy $dockerImage powershell | Out-Null
Write-Output "Copying file to $envoyDestPath"
& $dockerPath cp envoy:"C:\Program Files\envoy\envoy.exe" $envoyDestPath
Write-Output "Compressing to $envoyZipDestPath"
Compress-Archive -Path $envoyDestPath -DestinationPath $envoyZipDestPath
Write-Output "Removing container"
& $dockerPath rm --force envoy | Out-Null

if ($clean) {
  Write-Output "Removing image"
  & $dockerPath image rm $dockerImage
  Write-Output ""
}

if ($wait) {
  Write-Host -NoNewLine 'Press any key to continue...';
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

Stop-Job -Job $job
