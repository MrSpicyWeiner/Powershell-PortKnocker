
function Listen-Port ($port1=2001,$port2=2002,$port3=2003){
<#
.DESCRIPTION
Temporarily listen on a given port for connections dumps connections to the screen - useful for troubleshooting
firewall rules.

.PARAMETER Port
The TCP port that the listener should attach to

.EXAMPLE
PS C:\> listen-port 443
Listening on port 443, press CTRL+C to cancel

DateTime                                      AddressFamily Address                                                Port
--------                                      ------------- -------                                                ----
3/1/2016 4:36:43 AM                            InterNetwork 192.168.20.179                                        62286
Listener Closed Safely

.INFO
Created by Shane Wright. Neossian@gmail.com

#>
    $listener1 =[System.Net.Sockets.TcpListener]$port1
    $listener2 =[System.Net.Sockets.TcpListener]$port2
    $listener3 =[System.Net.Sockets.TcpListener]$port3

    Write-Host "Listening on port $port1, $port2, and $port3, press CTRL+C to cancel"
    try{
        $listener1.start();
    }catch{
        return
    }
    $listener2.start();
    $listener3.start();
    $client1 = $listener1.AcceptTcpClientAsync();
    $client2 = $listener2.AcceptTcpClientAsync();
    $client3 = $listener3.AcceptTcpClientAsync();
    $Clientlist=@{}
    $settime=$null
    While ($true){
        $netstatEst = Get-NetTCPConnection -LocalPort 2004 -State Established -ErrorAction SilentlyContinue
        $netstatList = Get-NetTCPConnection -LocalPort 2004 -State Listen -ErrorAction SilentlyContinue
        if($netstatEst -eq $null -and $netstatList -ne $null){
            if($settime -ne $null){
                if(($(Get-Date)-$settime).TotalSeconds -ge 30){
                    Write-Host "Deleting Rules..."
                    netsh interface portproxy reset | out-null
                    netsh advfirewall firewall delete rule "AllowRDPAfterKnockTCP" | Out-Null
                    netsh advfirewall firewall delete rule "AllowRDPAfterKnockUDP" | Out-Null
                }
            }else{
                netsh interface portproxy reset | out-null
            }
        }
        if($client1.IsCompleted){
            $result1 = $client1.Result.Client.RemoteEndPoint
            if ($result1){
                Write-host $result1
                $clientList[$result1.address]=1
                $Clientlist | format-table
                $client1.Result.Client.close()
                $listener1.stop()
                $listener1.start()
                $client1 = $listener1.AcceptTcpClientAsync()
            }
            $listener1.stop()
            $listener1.start()
            $client1 = $listener1.AcceptTcpClientAsync()
        }
        if($client2.IsCompleted){
            $result2 = $client2.Result.Client.RemoteEndPoint
            if ($result2 -and $clientList[$result2.address] -eq 1){
                Write-host $result2
                $clientList[$result2.address]=2
                $Clientlist | format-table
                $client2.Result.Client.close()
                $listener2.stop()
                $listener2.start()
                $client2 = $listener2.AcceptTcpClientAsync()
            }
            $listener2.stop()
            $listener2.start()
            $client2 = $listener2.AcceptTcpClientAsync()
        }
        if($client3.IsCompleted){
            $result3 = $client3.Result.Client.RemoteEndPoint
            if ($result3  -and $clientList[$result3.address] -eq 2){
                Write-host $result3
                $clientList[$result3.address]=3
                $Clientlist | format-table
                $client3.Result.Client.close()
                $listener3.stop()
                Write-Host "YOU DONE FAM"
                $settime = Get-Date
                netsh advfirewall firewall add rule name="AllowRDPAfterKnockTCP" dir=in action=allow protocol=TCP remoteip=$($result3.address) localport=2004 | Out-Null
                netsh advfirewall firewall add rule name="AllowRDPAfterKnockUDP" dir=in action=allow protocol=UDP remoteip=$($result3.address) localport=2004 | Out-Null
                netsh interface portproxy add v4tov4 listenaddress=10.1.1.2 listenport=2004 connectaddress=10.1.1.9 connectport=3389 | Out-Null
                                                                            
            }
            $listener3.stop()
            $listener3.start()
            $client3 = $listener3.AcceptTcpClientAsync()
        }
    }
    netsh interface portproxy reset
    $listener1.stop()
    $listener2.stop()
    $listener3.stop()
}

Listen-port