function PrepareVolumes ()
{
    $diskCount = (gwmi win32_DiskDrive).Count - 1
    $content = ''
    for ($i = 1; $i -le $diskCount; $i++)
    {
        $content += @"
        select disk $i
        online disk noerr 
        clean 
        attributes disk clear readonly noerr 
        convert MBR noerr

"@
    }

    $content | Out-File diskpart.txt -Encoding ascii
    Diskpart /s .\diskpart.txt > $null

    if ($LASTEXITCODE -ne 0) {
        'diskpart.txt content'
        cat diskpart.txt
        'Diskpart /s .\diskpart.txt > $null'
        throw "Dispart exited with error, LASTEXITCODE=$LASTEXITCODE"
    }
}

function CreateStrippedVolume ()
{
    $diskCount = (gwmi win32_DiskDrive).Count - 1
    $content = ''
    for ($i = 1; $i -le $diskCount; $i++)
    {
        $content += @"
        select disk $i
        online disk noerr 
        clean 
        attributes disk clear readonly noerr 
        convert dynamic noerr

"@
    }

    $content += @"
        create volume stripe disk=$(1..8 -join ',')
        format fs=ntfs label=scratch quick
        assign letter=z
        exit
"@

    $content | Out-File diskpart.txt -Encoding ascii
    Diskpart /s .\diskpart.txt
}


function Initialize ($file, $size) {
    $blockSize = 1KB
    $byte = [Byte[]] (,65 * $blockSize)
    $stream = New-Object System.IO.FileStream($file), Create
    $writer = New-Object System.IO.BinaryWriter($stream)
    $current = 0
    while ($current -lt $size) {
        $writer.write($byte)
        $current += $blockSize
    }
    $stream.Close()
    $writer.Close()
}

function runFIO ($file, $iniContent, $RepeatCount)
{
    $file
    $iniContent | Out-File "$file.ini" -Encoding ascii
    for ($i=1; $i -le $RepeatCount; $i++) {
        $output = . "$PSScriptRoot\fio.exe" "$file.ini" | tee "$file.results.txt" -Append | sls 'iops'
        $output
        $iops = ($output.ToString().split(', ') | sls 'iops').ToString().Split('=')[1]
        "#PSTEST# $($file)_iops=$iops"
    }
}

function fio (
    $BlockSize, 
    $TestType = 'randread', 
    $ThreadsPerDisk, 
    $IODepth = 4,
    $Direct, 
    $Ramptime = 5,
    $Runtime = 15,
    $RepeatCount = 1
)
{
    $fio = @"
    [global]
    blocksize=$BlockSize
    readwrite=$TestType
    numjobs=$ThreadsPerDisk
    iodepth=$IODepth
    ioengine=windowsaio
    direct=$Direct
    thread
    ramp_time=$Ramptime
    runtime=$Runtime
    group_reporting=1

"@
    $fio
    $basefile="$BlockSize-$TestType-threads_$($ThreadsPerDisk)-iodepth_$($IODepth)-direct_$($Direct)"
    $testfile = '\fiotest.dat'

    $iniContent = $fio
            $iniContent += @"
    [job$i]
    filename=$testfile
"@
    $file="$($basefile)_cdrive"
    
    if (! (Test-Path $testfile)) {
        Initialize $testfile 4GB
    }

    del "$file.results.txt" -ea 0

    runFIO $file $iniContent $RepeatCount 

    $diskCount = (gwmi win32_DiskDrive).Count - 1
    if ($diskCount -gt 0) {
        $file="$($basefile)_local"
        $iniContent = $fio
        for ($i = 1; $i -le $diskCount; $i++) {
            $iniContent += @"
        [job$i]
        filename=\\.\PhysicalDrive$i

"@
        }

        runFIO $file $iniContent $RepeatCount 
    }
}

PrepareVolumes

function FIOTest (
        $TestTypes = @('read', 'write', 'randread', 'randwrite', 'rw', 'randrw'),
        $BlockSizes = @('4k', '16mb'),
        $Directs = @(0, 1),
        $ThreadsPerDisks = @(1, 2),
        $IODepths = @(32),
        $RepeatCount = 3,
        $Ramptime = 5,
        $Runtime = 15
    )
{
    try
    {
        foreach ($testType in $TestTypes) {
          foreach ($blockSize in $BlockSizes) {
            foreach ($direct in $Directs) {
              foreach ($threadsPerDisk in $ThreadsPerDisks) {
                foreach ($ioDepth in $IODepths) {
                    fio -BlockSize $blockSize -TestType $TestType `
                        -ThreadsPerDisk $threadsPerDisk `
                        -IODepth $iODepth `
                        -Direct $direct `
                        -Ramptime $Ramptime `
                        -Runtime $Runtime `
                        -RepeatCount $RepeatCount
                } #iodepth
              } #threadsPerDisk
            } #direct
          } #blockSize
        } #testType
    }
    catch 
    {
        Write-Error "Error: $($_.Exception.Message)"
    }
}
