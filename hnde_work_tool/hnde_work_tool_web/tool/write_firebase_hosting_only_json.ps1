# 인자: -PublicDir <웹 빌드 출력 폴더(절대 경로)>
# 현재 디렉터리의 firebase.hosting.deploy.tmp.json 에 hosting 블록만 기록합니다.
param(
  [Parameter(Mandatory = $true)]
  [string] $PublicDir
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PublicDir)) {
  throw "웹 빌드 출력 폴더가 없습니다: $PublicDir`n먼저 flutter build web ... -o 로 해당 경로에 빌드하세요."
}
$pub = ((Get-Item -LiteralPath $PublicDir).FullName).Replace('\', '/')
$obj = [ordered] @{
  hosting = [ordered] @{
    public   = $pub
    ignore   = @('firebase.json', '**/.*', '**/node_modules/**')
    rewrites = @(
      [ordered] @{ source = '**'; destination = '/index.html' }
    )
  }
}
$json = $obj | ConvertTo-Json -Depth 10
$out = Join-Path (Get-Location) 'firebase.hosting.deploy.tmp.json'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $json + "`n", $utf8NoBom)
