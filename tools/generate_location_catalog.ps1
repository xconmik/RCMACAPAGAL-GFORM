$ErrorActionPreference = 'Stop'

$base = 'https://psgc.gitlab.io/api'
$target = 'assets/location_catalog.json'

$branchMap = [ordered]@{
  'Bulacan' = @('Bulacan')
  'DSO Talavera' = @('Nueva Ecija', 'Aurora')
  'DSO Tarlac' = @('Tarlac', 'Zambales')
  'DSO Pampanga' = @('Pampanga')
  'DSO Villasis' = @('Pangasinan')
  'DSO Bantay' = @('Ilocos Norte', 'Ilocos Sur', 'La Union')
}

$provinces = Invoke-RestMethod "$base/provinces.json"

$result = [ordered]@{ branches = @() }

foreach ($branchName in $branchMap.Keys) {
  $entries = @()

  foreach ($provinceName in $branchMap[$branchName]) {
    $province = $provinces | Where-Object { $_.name -eq $provinceName } | Select-Object -First 1
    if (-not $province) {
      throw "Province not found in PSGC: $provinceName"
    }

    $cityMunicipalities = Invoke-RestMethod "$base/provinces/$($province.code)/cities-municipalities.json"

    foreach ($cm in $cityMunicipalities) {
      $barangays = Invoke-RestMethod "$base/cities-municipalities/$($cm.code)/barangays.json"
      $barangayNames = @(
        $barangays |
          ForEach-Object { $_.name } |
          Where-Object { $_ -and $_.Trim().Length -gt 0 } |
          Sort-Object -Unique
      )

      $entries += [PSCustomObject]@{
        BaseName  = [string]$cm.name
        Province  = [string]$provinceName
        Barangays = $barangayNames
      }
    }
  }

  $duplicateNames = @{}
  $entries |
    Group-Object BaseName |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object { $duplicateNames[$_.Name] = $true }

  $municipalities = @()
  foreach ($entry in $entries) {
    $displayName = if ($duplicateNames.ContainsKey($entry.BaseName)) {
      "$($entry.BaseName) ($($entry.Province))"
    } else {
      $entry.BaseName
    }

    if ($branchName -eq 'Bulacan' -and $displayName -eq 'Baliuag') {
      $displayName = 'City of Baliwag'
    }

    $municipalities += [ordered]@{
      name      = $displayName
      barangays = $entry.Barangays
    }
  }

  $municipalities = @($municipalities | Sort-Object name)

  $result.branches += [ordered]@{
    name           = $branchName
    municipalities = $municipalities
  }
}

$json = $result | ConvertTo-Json -Depth 10
Set-Content -Path $target -Value $json -Encoding UTF8

Write-Host "Generated $target"
