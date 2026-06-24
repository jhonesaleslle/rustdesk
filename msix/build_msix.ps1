# msix/build_msix.ps1
# Empacota a pasta de build do TecnoAssist Client num .msix para a Microsoft Store,
# usando makeappx.exe do Windows SDK (sem a MSIX Packaging Tool manual).
#
#   Não-assinado (para a Store; a Microsoft assina ao publicar):
#     ./build_msix.ps1 -Layout <pasta_build> -Manifest <Package.appxmanifest> `
#         -AssetsScript <gen_msix_assets.py> -SourceLogo <logo.png> -OutMsix <saida.msix>
#
#   Self-signed (SÓ para testar localmente; não serve para a Store):
#     ...mesmos parâmetros... -SelfSign
#     -> também emite o .cer; instale-o em "Pessoas Confiáveis"/"Autoridades de
#        Certificação Raiz Confiáveis" da máquina para conseguir instalar o .msix.
param(
  [Parameter(Mandatory = $true)][string]$Layout,        # pasta com tecnoassist.exe (ex.: ./rustdesk)
  [Parameter(Mandatory = $true)][string]$Manifest,      # msix/Package.appxmanifest
  [Parameter(Mandatory = $true)][string]$AssetsScript,  # msix/gen_msix_assets.py
  [Parameter(Mandatory = $true)][string]$SourceLogo,    # res/icon.png (512x512, commitado)
  [Parameter(Mandatory = $true)][string]$OutMsix,       # caminho do .msix de saída
  [switch]$SelfSign,
  [string]$TestPublisher = "CN=Tecnovetti-MSIX-Test",
  [string]$TestPfxPassword = "tecno-msix-test"
)
$ErrorActionPreference = "Stop"

# --- resolve o bin x64 do Windows SDK (makeappx/signtool) ---
$sdkRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
$verDir = Get-ChildItem $sdkRoot -Directory |
  Where-Object { $_.Name -match '^10\.' -and (Test-Path (Join-Path $_.FullName 'x64\makeappx.exe')) } |
  Sort-Object Name -Descending | Select-Object -First 1
if (-not $verDir) { throw "makeappx.exe não encontrado sob $sdkRoot" }
$bin = Join-Path $verDir.FullName "x64"
$makeappx = Join-Path $bin "makeappx.exe"
$signtool = Join-Path $bin "signtool.exe"
Write-Host "Windows SDK bin: $bin"

# --- trabalha numa CÓPIA isolada do layout ---
# Não poluímos a pasta de build original (./rustdesk) com Assets/ e AppxManifest.xml,
# senão o empacotador portátil (generate.py) os incluiria no .exe portátil.
$work = "$OutMsix.layout"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item (Join-Path $Layout '*') $work -Recurse -Force
Write-Host "Layout MSIX (cópia): $work"

# --- embarca o runtime VC++ app-local (causa nº1 do crash silencioso na cert.) ---
# Numa máquina LIMPA (como a da certificação da Store) sem o "VC++ Redistributable
# 2015–2022 x64", o LoadLibrary("librustdesk.dll") do runner falha (GetLastError=126)
# e o processo sai SEM janela e SEM erro. Embarcar as 3 DLLs ao lado do .exe (o
# Windows carrega DLL app-local antes da do sistema) elimina a dependência externa.
# Só afeta o pacote MSIX (esta cópia), não a pasta ./rustdesk nem o portátil.
$crtRoot = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" -Directory -ErrorAction SilentlyContinue |
  Sort-Object FullName | Select-Object -Last 1
if ($crtRoot) {
  foreach ($dll in @("vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll")) {
    Copy-Item (Join-Path $crtRoot.FullName $dll) $work -Force
  }
  Write-Host "Runtime VC++ embarcado (app-local) de: $($crtRoot.FullName)"
} else {
  Write-Warning "Redist VC++ (Microsoft.VC143.CRT) não encontrado — o MSIX pode dar crash silencioso em máquina limpa (GetLastError=126)."
}

# --- gera os assets dentro da cópia ---
$assets = Join-Path $work "Assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null
python $AssetsScript $SourceLogo $assets
if ($LASTEXITCODE -ne 0) { throw "geração de assets falhou" }

# --- coloca o manifesto na cópia com o nome que o makeappx espera ---
$manifestDst = Join-Path $work "AppxManifest.xml"
Copy-Item $Manifest $manifestDst -Force

if ($SelfSign) {
  # Para assinar localmente, o Publisher do manifesto TEM que bater com o Subject
  # do certificado self-signed. Sobrescrevemos só nesta cópia de teste.
  (Get-Content $manifestDst -Raw) -replace 'Publisher="[^"]*"', "Publisher=`"$TestPublisher`"" |
    Set-Content $manifestDst -Encoding UTF8
  Write-Host "Manifesto (teste) com Publisher=$TestPublisher"
}

# --- empacota ---
New-Item -ItemType Directory -Force -Path (Split-Path $OutMsix) | Out-Null
& $makeappx pack /d $work /p $OutMsix /o
if ($LASTEXITCODE -ne 0) { throw "makeappx pack falhou" }
Write-Host "MSIX gerado: $OutMsix"

if ($SelfSign) {
  $outDir = Split-Path $OutMsix
  $cert = New-SelfSignedCertificate -Type Custom -Subject $TestPublisher `
    -KeyUsage DigitalSignature -FriendlyName "TecnoAssist MSIX Test" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
  $pwd = ConvertTo-SecureString -String $TestPfxPassword -Force -AsPlainText
  $pfx = Join-Path $outDir "tecnoassist-msix-test.pfx"
  $cer = Join-Path $outDir "tecnoassist-msix-test.cer"
  Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $pwd | Out-Null
  Export-Certificate -Cert $cert -FilePath $cer | Out-Null
  & $signtool sign /fd SHA256 /a /f $pfx /p $TestPfxPassword $OutMsix
  if ($LASTEXITCODE -ne 0) { throw "signtool sign falhou" }
  Write-Host "MSIX self-signed pronto. Instale $cer em 'Autoridades de Certificação Raiz Confiáveis' (máquina) antes de instalar o .msix."
}
