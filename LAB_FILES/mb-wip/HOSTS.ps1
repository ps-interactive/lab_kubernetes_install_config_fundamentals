$data = get-content "$env:windir\system32\drivers\etc\hosts"
$data += "172.16.94.10 c1-cp1","172.16.94.11 c1-node1","172.16.94.12 c1-node2","172.16.94.13 c1-node3"
$data | Out-File "$env:windir\system32\drivers\etc\hosts" -Force