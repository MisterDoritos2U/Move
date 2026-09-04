function New-ValidationDynamicParam {
    [CmdletBinding()]
    [OutputType('System.Management.Automation.RuntimeDefinedParameter')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [array]
        $ValidateSetOptions,
        [Parameter()]
        [switch]
        $Mandatory = $false,
        [Parameter()]
        [string]
        $ParameterSetName = '__AllParameterSets',
        [Parameter()]
        [switch]
        $ValueFromPipeline = $false,
        [Parameter()]
        [switch]
        $ValueFromPipelineByPropertyName = $false
        )

        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = $Mandatory.IsPresent
        $ParamAttrib.ParameterSetName = $ParameterSetName
        $ParamAttrib.ValueFromPipeline = $ValueFromPipeline.IsPresent
        $ParamAttrib.ValueFromPipelineByPropertyName = $ValueFromPipelineByPropertyName.IsPresent
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($Param.ValidateSetOptions)))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter($Param.Name, [string], $AttribColl)
        $RuntimeParam

}