
$dir = $args[0]
$original = $args[1]
$new = $args[2]

if (-not $dir -or -not $original -or -not $new) {
    Write-Host "Usage: RenameFiles.ps1 <directory> <original> <new>"
    exit 1
}

function Rename-Some {
    param (
        [string]$path,
        [string]$original,
        [string]$new
    )
    
    Get-ChildItem $dir | 
    Foreach-Object {
        $isDir = $_.PSIsContainer
        $content = Get-Content $_.FullName
        $partial = $content.Substring($dir.Length)

        $newPartial = $partial -replace [regex]::Escape($original), $new

        if ($newPartial -ne $partial) {
            Write-Host "Renaming: $($_.FullName) to $newPartial"
            Rename-Item $_.FullName $dir + $newPartial
        }

        if ($isDir) {
            Rename-Some -path $dir + $newPartial -original $original -new $new
        }
    }
}

Rename-Some -path $dir -original $original -new $new