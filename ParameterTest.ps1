
    [CmdletBinding(DefaultParameterSetName='p')]
    Param (
        # $p1 and $p2 must be used together. Can be used with all other parameters except $p3
        [Parameter(ParameterSetName = 'p1&p2', Mandatory)]
        [ValidateScript({
            $null -eq $PSCmdlet.MyInvocation.BoundParameters['p3'] 
        }, ErrorMessage = 'Cannot use p1 with p3')]
        $p1,
        [Parameter(ParameterSetName = 'p1&p2', Mandatory)]
        [ValidateScript({
            $null -eq $PSCmdlet.MyInvocation.BoundParameters['p3']
        }, ErrorMessage = 'Cannot use p2 with p3')]
        $p2,
        # $P3 cannot be used with $p1 and $p2. Can be used with all other parameters or alone.
        [Parameter(ParameterSetName='p3', Mandatory)]
        [Parameter(ParameterSetName = 'p7.1', Mandatory)]
        [Parameter(ParameterSetName = 'p8.1', Mandatory)]
        [ValidateScript({
            $Null -eq $PSCmdlet.MyInvocation.BoundParameters['p1'] -and $null -eq $psCmdlet.MyInvocation.BoundParameters['p2']
        }, ErrorMessage = 'Cannot use p3 with p1 or p2')]
        $p3,
        # independent parameters
        $p4,
        $p5,
        $p6,
        # $p7 and $p8 are exclusive to each other but can be used with other parameters, or alone
        [Parameter(ParameterSetName = 'p7', Mandatory)]
        [Parameter(ParameterSetName = 'p7.1', Mandatory)]
        [ValidateScript({
            $null -eq $PSCmdlet.MyInvocation.BoundParameters['p8']
        }, ErrorMessage = 'P7 cannot be used with P8')]
        $p7,
        [Parameter(ParameterSetName = 'p8', Mandatory)]
        [Parameter(ParameterSetName = 'p8.1', Mandatory)]
        [ValidateScript({
            $null -eq $PSCmdLet.MyInvocation.BoundParameters['p7']
        }, ErrorMessage = 'P8 Cannot be used with P7')]
        $p8
    )
    $PSCmdlet.ParameterSetName

    write-host "The parameters work"
