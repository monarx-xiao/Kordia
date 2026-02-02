$shell = New-Object -ComObject Wscript.shell
$key = "{SCROLLLOCK}"

while($true){

    $time = Get-Date
    Write-Output "$time Run sendkeys : $key"
    $shell.sendkeys($key)
    Start-Sleep -Seconds 50
}