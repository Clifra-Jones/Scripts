# Copyright: (c) 2019, Jordan Borean (@jborean93) <jborean93@gmail.com>
# MIT License (see LICENSE or https://opensource.org/licenses/MIT)

# To use, copy the .psm1 file locally and run
# Import-Module -Name Get-SnapshotPath.psm1
# Get-SnapshotPath -Path "\\server\share"

Add-Type -TypeDefinition @'
using Microsoft.Win32.SafeHandles;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.AccessControl;

namespace Win32
{
    public class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct IO_STATUS_BLOCK
        {
            public UInt32 Status;
            public UInt32 Information;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct NT_Trans_Data
        {
            public UInt32 NumberOfSnapShots;
            public UInt32 NumberOfSnapShotsReturned;
            public UInt32 SnapShotArraySize;
            // Omit SnapShotMultiSZ because we manually get that string based on the struct results
        }
    }

    public class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern SafeFileHandle CreateFileW(
            string lpFileName,
            FileSystemRights dwDesiredAccess,
            FileShare dwShareMode,
            IntPtr lpSecurityAttributes,
            FileMode dwCreationDisposition,
            UInt32 dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("ntdll.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern UInt32 NtFsControlFile(
            SafeFileHandle hDevice,
            IntPtr Event,
            IntPtr ApcRoutine,
            IntPtr ApcContext,
            ref NativeHelpers.IO_STATUS_BLOCK IoStatusBlock,
            UInt32 FsControlCode,
            IntPtr InputBuffer,
            UInt32 InputBufferLength,
            IntPtr OutputBuffer,
            UInt32 OutputBufferLength);

        [DllImport("ntdll.dll")]
        public static extern UInt32 RtlNtStatusToDosError(
            UInt32 Status);
    }
}
'@

Function Get-LastWin32ExceptionMessage {
    <#
    .SYNOPSIS
    Converts a Win32 Status Code to a more descriptive error message.
    
    .PARAMETER ErrorCode
    The Win32 Error Code to convert
    
    .EXAMPLE
    $LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Get-LastWin32Exception -ErrorCode $LastError
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ErrorCode
    )

    $Exp = New-Object -TypeName System.ComponentModel.Win32Exception -ArgumentList $ErrorCode
    $ExpMsg = "{0} (Win32 ErrorCode {1} - 0x{1:X8})" -f $Exp.Message, $ErrorCode
    return $ExpMsg
}

Function Invoke-EnumerateSnapshots {
    <#
    .SYNOPSIS
    Invokes NtFsControlFile with the handle and buffer size specified.
    
    .DESCRIPTION
    This cmdlet is defined to invoke NtFsControlFile with the
    FSCTL_SRV_ENUMERATE_SNAPSHOTS control code.
    
    .PARAMETER Handle
    A SafeFileHandle of the opened UNC path. This should be retrieved with
    CreateFileW.
    
    .PARAMETER BufferSize
    The buffer size to initialise the output buffer. This should be a minimum
    of ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][Win32.NativeHelpers+NT_Trans_Data]) + 4).
    See Examples on how to invoke this
    
    .PARAMETER ScriptBlock
    The script block to invoke after the raw output buffer is converted to the
    NT_Trans_Data structure.
    
    .EXAMPLE
    $BufferSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][Win32.NativeHelpers+NT_Trans_Data]) + 4)
    Invoke-EnumerateSnapshots -Handle $Handle -BufferSize $BufferSize -ScriptBlock {
        $TransactionData = $args[1]

        if ($TransactionData.NumberOfSnapShots -gt 0) {
            $NewBufferSize = $BufferSize + $TransactionData.SnapShotArraySize

            Invoke-EnumerateSnapshots -Handle $Handle -BufferSize $NewBufferSize -ScriptBlock {
                $OutBuffer = $args[0]
                $TransactionData = $args[1]

                $SnapshotPtr = [System.IntPtr]::Add($OutBuffer, $TransDataSize)
                $SnapshotString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($SnapshotPtr,
                    $TransactionData.SnapShotArraySize / 2)

                $SnapshotString.Split([char[]]@("`0"), [System.StringSplitOptions]::RemoveEmptyEntries)
            }
        }
    }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.SafeHandles.SafeFileHandle]
        $Handle,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $BufferSize,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    # Allocate new memory based on the buffer size
    $OutBuffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($BufferSize)
    try {
        $IOBlock = New-Object -TypeName Win32.NativeHelpers+IO_STATUS_BLOCK

        # Call NtFsControlFile with the handle and FSCTL_SRV_ENUMERATE_SNAPSHOTS code
        $Result = [Win32.NativeMethods]::NtFsControlFile($Handle, [System.IntPtr]::Zero, [System.IntPtr]::Zero,
            [System.IntPtr]::Zero, [Ref]$IOBlock, 0x00144064, [System.IntPtr]::Zero, 0, $OutBuffer, $BufferSize)

        if ($Result -ne 0) {
            # If the result was not 0 we need to convert the NTSTATUS code to a Win32 code
            $Win32Error = [Win32.NativeMethods]::RtlNtStatusToDosError($Result)
            $Msg = Get-LastWin32ExceptionMessage -ErrorCode $Win32Error
            Write-Error -Message "NtFsControlFile failed - $Msg"
            return
        }

        # Convert the OutBuffer pointer to a NT_Trans_Data structure
        $TransactionData = [System.Runtime.InteropServices.Marshal]::PtrToStructure(
            $OutBuffer,
            [Type][Win32.NativeHelpers+NT_Trans_Data]
        )

        # Invoke out script block that parses the data and outputs whatever it needs. We pass in both the
        # OutBuffer and TransactionData as arguments
        &$ScriptBlock $OutBuffer $TransactionData
    } finally {
        # Make sure we free the unmanaged memory
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($OutBuffer)
    }
}

Function Get-SnapshotPath {
    <#
    .SYNOPSIS
    Get all VSS snapshot paths for the path specified.
    
    .DESCRIPTION
    Scans the UNC or Local path for a list of VSS snapshots and the path that
    can be used to reach these files.
    
    .PARAMETER Path
    The UNC or Local path to search. The local path will be automatically
    converted to \\localhost\<drive>$\<path> as the methods used inside this
    function are only available for UNC paths.
    
    .EXAMPLE
    Get-SnapshotPath -Path \\server\share
    Get-SnapshotPath -Path C:\Windows
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    if (-not $IsWindows) {
        Write-Error -Message "This function is only available on Windows" -Category NotSupported
        Throw
        return
    }

    # Automatically convert a local path to a UNC path
    if (-not ([Uri]$Path).IsUnc) {
        $Qualifier = Split-Path -Path $Path -Qualifier
        $UnqualifiedPath = Split-Path -Path $Path -NoQualifier
        $Path = '\\localhost\{0}${1}' -f $Qualifier.Substring(0, 1), $UnqualifiedPath
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error -Message "Could not find UNC path '$Path'" -Category ObjectNotFound
        return
    }

    # Create a SafeFileHandle of the path specified and make sure it is valid
    $Handle = [Win32.NativeMethods]::CreateFileW(
        $Path,
        [System.Security.AccessControl.FileSystemRights]"ListDirectory, ReadAttributes, Synchronize",
        [System.IO.FileShare]::ReadWrite,
        [System.IntPtr]::Zero,
        [System.IO.FileMode]::Open,
        0x02000000,  # FILE_FLAG_BACKUP_SEMANTICS
        [System.IntPtr]::Zero
    )
    if ($Handle.IsInvalid) {
        $LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $Msg = Get-LastWin32ExceptionMessage -ErrorCode $LastError
        Write-Error -Message "CreateFileW($Path) failed - $Msg"
        return
    }

    try {        
        # Set the initial buffer size to the size of NT_Trans_Data + 2 chars. We do this so we can get the actual buffer
        # size that is contained in the NT_Trans_Data struct. A char is 2 bytes (UTF-16) and we expect 2 of them
        $TransDataSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][Win32.NativeHelpers+NT_Trans_Data])
        $BufferSize = $TransDataSize + 4

        # Invoke NtFsControlFile at least once to get the number of snapshots and total size of the NT_Trans_Data
        # buffer. If there are 1 or more snapshots we invoke it again to get the actual snapshot strings
        Invoke-EnumerateSnapshots -Handle $Handle -BufferSize $BufferSize -ScriptBlock {
            $TransactionData = $args[1]

            if ($TransactionData.NumberOfSnapShots -gt 0) {
                # There are snapshots to retrieve, reset the buffer size to the original size + the return array size
                $NewBufferSize = $BufferSize + $TransactionData.SnapShotArraySize

                # Invoke NtFsControlFile with the larger buffer size but now we can parse the NT_Trans_Data
                Invoke-EnumerateSnapshots -Handle $Handle -BufferSize $NewBufferSize -ScriptBlock {
                    $OutBuffer = $args[0]
                    $TransactionData = $args[1]

                    $SnapshotPtr = [System.IntPtr]::Add($OutBuffer, $TransDataSize)
                    $SnapshotString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($SnapshotPtr,
                        $TransactionData.SnapShotArraySize / 2)

                    Write-Output -InputObject ($SnapshotString.Split([char[]]@("`0"), [System.StringSplitOptions]::RemoveEmptyEntries))
                }
            }
        } | ForEach-Object -Process { Join-Path -Path $Path -ChildPath $_ }
    } finally {
        # Technically not needed as a SafeFileHandle will auto dispose once the GC is called but it's good to be
        # explicit about these things
        $Handle.Dispose()
    }
}

Export-ModuleMember -Function Get-SnapshotPath
