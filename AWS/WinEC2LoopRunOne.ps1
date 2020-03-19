function WinEC2LoopRunOne
{
    param ($file, $count, $retryCount, [Hashtable]$parameterSet)
    $failures = 0

    function log ([string]$st)
    {
        $time = (Get-date).ToLongTimeString()
        "$time - $st" | tee -FilePath $logfile -Append
    }
    function logCSV ([string]$st)
    {
        $st | tee -FilePath $file -Append
    }

    function logexception ([Exception] $exception)
    {
        log 'Exception:'
        log $exception.ToString()
    }

    function NewObject ($type)
    {
        $obj = New-Object 'system.collections.generic.dictionary[[string],[object]]'
        $obj.Add('Type', ('{0,-6}' -f $type))
        $obj.Add('Guid', $guid)
        $obj
    }

    $guid = [Guid]::NewGuid()
    $obj = NewObject 'Single'
    $sum = NewObject 'Sum'
    $min = NewObject 'Min'
    $max = NewObject 'Max'
    
    function AddTimeEvent ([string]$key, [Timespan]$timespan)
    {
        if (-not $obj.ContainsKey($key))
        {
            $obj.Add($key, [Timespan]0)
            $sum.Add($key, [Timespan]0)
            $min.Add($key, $timespan)
            $max.Add($key, $timespan)
        }
        $obj[$key] = $timespan
        $sum[$key] += $timespan
        if ($min[$key] -gt $timespan)
        {
            $min[$key] = $timespan
        }
        if ($max[$key] -lt $timespan)
        {
            $max[$key] = $timespan
        }
    }

    #depends on $startTime and $consoleLog
    function AddTimeEventFromConsoleLog ([string]$key, [string]$token)
    {
        $st = $consoleLog | ? { $_ -like "*$token*"} | select -First 1
        if ($st -eq $null)
        {
            AddTimeEvent $key ([Timespan]0)
        }
        else
        {
            AddTimeEvent $key ([Datetime]$st.SubString(0,20) - $startTime)
        }
    }

    function GetString ($obj)
    {
        $st = ''
        foreach ($key in $obj.Keys)
        {
            if ($obj[$key] -is [Timespan])
            {
                $value = '{0:hh\:mm\:ss}' -f $obj."$key"
            }
            else
            {
                $value = [string]$obj[$key]
            }
            $st = "$st`t$key=$value"
        }
        $st
    }
   
    $logfile = $file.Replace('.csv', '.log')
    
    Set-DefaultAWSRegion $parameters['region']

    del $logfile -ea 0
    del $file -ea 0

    $paramstring = ''
    foreach ($key in $parameterSet.Keys)
    {
        $value = $parameterSet[$key]
        $paramstring += "`t$key=$value"
    }

    $sumRunning = $sumPing = $sumPassword = $sumRemote = 0
    $sumsysprepStartTime  = $sumsysprepEndTime = $sumsysprepTime = $sumConsolePasswordTime = $sumReadyTime = 0
    $sumcount = 0
        
    for($i=0; $i -lt $Count; )
    {
        try
        {
            $startTime = [DateTime]::Now

            $a = New-WinEC2Instance @parameterSet
            $consoleLog = (Get-EC2ConsoleOutput $a.instanceid).Output
            $consoleLog = [System.Text.Encoding]::ascii.GetString([System.Convert]::FromBase64String($consoleLog)).Split("`n")
            $consoleLog

            AddTimeEvent 'Running' $a.Time.Running
            AddTimeEvent 'Ping' $a.Time.Ping
            AddTimeEvent 'Password' $a.Time.Password
            AddTimeEvent 'Remote' $a.Time.Remote

            AddTimeEventFromConsoleLog 'Origin' 'Origin'
            AddTimeEventFromConsoleLog 'SysprepStart' 'Sysprep Start'
            AddTimeEventFromConsoleLog 'SysprepEnd' 'Sysprep End'
            AddTimeEvent 'Sysprep' ($obj.SysprepEnd - $obj.SysprepStart )
            AddTimeEventFromConsoleLog 'ConsolePassword' 'Password'
            AddTimeEventFromConsoleLog 'Ready' 'Ready'
            AddTimeEvent 'EC2ConfigRunTime' ($obj.Ready - $obj.Origin)

            $obj.'InstanceId' = $a.InstanceId
            $obj.'StartTime' = $startTime

            $sumcount++
            $i++

            $st = GetString $obj
            $index = '{0,-3}' -f $i 
            logCSV " `tIndex=$index$st`tFailures=$failures$paramstring"

            log "Number=$i, Failures=$failures Max retry=$RetryCount New-WinEC2Instance $($a.instanceid) completed"
            Remove-WinEC2Instance $a.instanceid 
            log "Remove-WinEC2Instance $($a.instanceid) completed"
            $a = $null
        }
        catch
        {
            $failures++
            logexception $_.Exception
            log "Failures=$failures Max retry=$RetryCount, Instanceid=$($a.instanceid)"
        }
        if ($failures -ge $retryCount)
        {
            log "Max retry reached (RetrCount=$RetryCount), so will exit now"
            break
        }
    }

    if ($sumcount -gt 1)
    {
        $st = GetString $min
        logCSV "MIN`tCount=$i$st`tFailures=$failures$paramstring"

        $st = GetString $max
        logCSV "MAX`tCount=$i$st`tFailures=$failures$paramstring"

        foreach ($key in $obj.Keys)
        {
            if ($sum[$key] -is [Timespan])
            {
                $sum[$key] = New-TimeSpan -Seconds ($sum[$key].TotalSeconds/$sumcount)
            }
        }
        $st = GetString $sum
        logCSV "AVG`tCount=$i$st`tFailures=$failures$paramstring"
    }
}

<#
$parameters = @{
    Region='us-east-1'
    ImagePrefix='Windows_Server-2012-R2_RTM-English-64Bit-Base'
    gp2=$True
    IOPS='0'
    InstanceType='m3.xlarge'
}
WinEC2LoopRunOne -file "c:\temp\y.csv" -count 1 -retryCount 1 -parameterSet $parameters
#>