function Get-jtPip {
    $MyIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    $MyIP | Set-ClipBoard
    "IP: {0}`n`nSaved to clipboard." -f $MyIP
}
