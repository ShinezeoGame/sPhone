# Télécharge scrcpy (avec adb) dans le dossier voulu, après avoir vérifié son empreinte.
#
# La version, l'adresse et l'empreinte SHA-256 attendue sont dans tools/scrcpy.json :
# pour changer de version, c'est ce fichier qu'on modifie (avec `scrcpyVersion` dans
# lib/data/scrcpy.dart).
#
#     .\tools\scrcpy.ps1                         # dans build\scrcpy
#     .\tools\scrcpy.ps1 -Destination C:\outils\scrcpy
#
# En développement, indiquez ensuite ce dossier à l'application :
#     $env:SPHONE_SCRCPY_DIR = "$PWD\build\scrcpy" ; flutter run -d windows

param([string]$Destination = "build/scrcpy")

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$pin = Get-Content (Join-Path $PSScriptRoot 'scrcpy.json') -Raw | ConvertFrom-Json
$work = Join-Path ([IO.Path]::GetTempPath()) "sphone-scrcpy-$($pin.version)"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

$zip = Join-Path $work 'scrcpy.zip'
Write-Host "Téléchargement de scrcpy $($pin.version)…"
Invoke-WebRequest -Uri $pin.url -OutFile $zip

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $pin.sha256) {
    throw "Empreinte SHA-256 inattendue pour scrcpy : $hash (attendue : $($pin.sha256)). Archive refusée."
}

Expand-Archive -Path $zip -DestinationPath (Join-Path $work 'contenu')
$inner = Get-ChildItem (Join-Path $work 'contenu') -Directory | Select-Object -First 1
if (-not $inner -or -not (Test-Path (Join-Path $inner.FullName 'scrcpy.exe'))) {
    throw "L'archive de scrcpy n'a pas la structure attendue."
}

if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
Copy-Item (Join-Path $inner.FullName '*') $Destination -Recurse

# Lanceurs manuels de scrcpy : sans objet ici, c'est sPhone qui le lance.
Get-ChildItem $Destination -File | Where-Object { $_.Extension -in '.bat', '.vbs' } | Remove-Item -Force

Remove-Item $work -Recurse -Force
Write-Host "scrcpy $($pin.version) prêt dans $Destination"
