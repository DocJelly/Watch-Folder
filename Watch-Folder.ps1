<#
.SYNOPSIS
    Instantiates a FileSystemWatcher object and instructs it to monitor a specified folder.
    When a matching filetype is detected created, it will copy it to the backup folder, and
    compress and save as a zip file to the archive folder.
.DESCRIPTION
    Instantiates a FileSystemWatcher object and instructs it to monitor a specified folder.
    defaults to C:\incoming but you can change it in the code or at runtime by using 
    the -path parameter
.NOTES
    This only works on Windows.
    Based on code found on SuperUser:
    https://superuser.com/questions/226828/how-to-monitor-a-folder-and-trigger-a-command-line-action-when-a-file-is-created
.PARAMETER path
    specifies the folder you want to watch. default is C:\Incoming
    
.EXAMPLE
    Watch-Folder -path C:\SubFiles
    This example starts the Daemon and watches C:\SubFiles folder
.EXAMPLE
    Watch-Folder
    This folder starts the Daemon and watches the default folder defined in the param block
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $path = "C:\Incoming"
)

# Script path variables
$backup = "C:\BMXBackup";
$archive = "C:\BMXZipped";

# Instantiate watcher
$watcher = New-Object System.IO.FileSystemWatcher;
$watcher.Path = $path;
$watcher.Filter = "*.bmxraw";
$watcher.IncludeSubdirectories;
$watcher.EnableRaisingEvents = $true;

# Define actions when an event is detected
$actionCreate = { 
    $eventPath = $event.SourceEventArgs.FullPath;
    $changeType = $event.SourceEventArgs.ChangeType;
    $logline = "$(Get-Date), $changeType, $eventPath";
    # This line only outputs to the screen when you run with the -verbose parameter
    # usually only during testing. During normal runtime it won't output anything to the screen
    Write-Verbose $logline;
    # you could also write to a log file if you want to keep a "hard copy"
    # by un-commenting the next line
    # Add-Content .\logfile.txt -Value $logline;

    # This line copies from the watched folder to the backup folder, defined above
    # there is no error handling here, it just tries to copy and works or fails and doesn't care.
    Copy-Item -Path $eventPath -Destination $backup;

    # This line constructs the name of the zip file by changing the extension from bmxraw to zip
    $ArchiveName = [System.IO.Path]::ChangeExtension($event.SourceEventArgs.Name, "zip");

    # This line uses zip compression to compress the detected file and stores it in the archive
    # folder that is also defined above.
    # like the copy line, it has no error handling, it just does it's thing and doesn't care if
    # it worked or not.
    Compress-Archive -Path $eventPath -DestinationPath "$($archive)\$($ArchiveName)";

    # FTP Section: this is where you would add a couple lines of code to send this file to the 
    # client's FTP server. I'll leave this part up to you to figure out.


}
$actionDelete = {
    $eventPath = $event.SourceEventArgs.FullPath;
    $changeType = $event.SourceEventArgs.ChangeType;
    $logline = "$(Get-Date), $changeType, $eventPath";
    Write-Verbose $logline;
}

# Register event watcher
Register-ObjectEvent $watcher "Created" -Action $actionCreate;
Register-ObjectEvent $watcher "Deleted" -Action $actionDelete;

# Start an infinite loop to re-run this every 5 seconds until you close the window or press ctrl-c
try {
    while ($true) { Start-Sleep 5 }
}
catch {
    <#Do this if a terminating exception happens#>
}
finally {
    Get-EventSubscriber | Unregister-Event;
}
