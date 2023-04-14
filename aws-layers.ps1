#requires -Version 7

$MugstechLibs = Get-ChildItem .\mugstech*

foreach ($Lib in $MugstechLibs) {
    Write-Output "===> $($Lib.Name) <==="
    Set-Location $Lib.Name
    # get layers config
    $LayersConfig = Get-Content aws-layers.config.json -Raw | ConvertFrom-Json
    $PackageDotJson = Get-Content package.json -Raw | ConvertFrom-Json
    $Publish = $true

    if (!(Test-Path aws-layers/nodejs)) {
        Write-Output "===> configuring derectories  ..."
        mkdir aws-layers/nodejs
    }

    Copy-Item ..\layers-package.json -Destination aws-layers/nodejs/package.json

    if ($LayersConfig.publish) {
        if (Test-Path "aws-layers\.version") {
            $Version = (Get-Content "aws-layers\.version" -Raw ).Trim()
            Write-Output "layer version: $($Version), package version: $($PackageDotJson.version)"
            if ($Version -eq $PackageDotJson.version) {
                $Publish = $false
            }
        }
    }
    else {
        $Publish = $false
    }

    if ($Publish) {

        if (Test-Path "aws-layers\layer.zip") {
            Remove-Item "aws-layers\layer.zip"
        }
        
        Write-Output "==> Installing layer dependencies ..."
        Set-Location "aws-layers\nodejs" && npm install "$($PackageDotJson.name)@latest" && `
            Write-Output "==> Generating layer archive..."
        Set-Location ..\
        Get-ChildItem -Path .\nodej* | Compress-Archive -DestinationPath ".\layer.zip" && `
            Write-Output "==> Publishing $($LayersConfig.name) ..." && `
            aws lambda publish-layer-version `
            --layer-name $LayersConfig.name `
            --description "$($LayersConfig.name) version $($PackageDotJson.version): $($LayersConfig.description)" `
            --zip-file "fileb://layer.zip" `
            --compatible-runtimes $LayersConfig.compatibleRuntimes `
            --region "eu-central-1" `
            --no-cli-pager && `
            Set-Content -Path .version -Value $PackageDotJson.version
        Set-Location ..
    }
    elseif ($LayersConfig.publish) {
        Write-Output "$($LayersConfig.name) is up to date."
    }
    else {
        Write-Output "$($Lib.Name) is configured not to be published."
    }
    Set-Location ..

    Write-Output "_______________________________________________________"
}
