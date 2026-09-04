function Invoke-MoveApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Header,

        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [object]$Body
    )

    $RequestHeaders = @{
        Accept = 'application/json'
    }

    foreach ($key in $Header.Keys) {
        $RequestHeaders[$key] = [string]$Header[$key]
    }

    $Parameters = @{
        Uri                  = $Uri
        Method               = $Method
        Headers              = $RequestHeaders
        ContentType          = 'application/json'
        SkipCertificateCheck = $true
        ErrorAction          = 'Stop'
    }

    if ($null -ne $Body) {
        $Parameters.Body = $Body | ConvertTo-Json -Depth 100 -Compress
    }

    $attempt = 0
    while ($true) {
        try {
            return Invoke-RestMethod @Parameters
        }
        catch {
            $statusCode = $null
            $responseBody = $null

            try {
                if ($null -ne $_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                    $stream = $_.Exception.Response.GetResponseStream()
                    if ($null -ne $stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        try {
                            $responseBody = $reader.ReadToEnd()
                        }
                        finally {
                            $reader.Dispose()
                        }
                    }
                }
            }
            catch {
                # Preserve the original exception if the response cannot be read.
            }

            # Move V2 access tokens expire. If a normal Move API call returns
            # 401, obtain a fresh token from the documented Login API and retry
            # the original request exactly once. Never retry the Login endpoint.
            $isMoveRequest = $Uri -match '/move/v2/'
            $isLoginRequest = $Uri -match '/move/v2/users/login(?:\?|$)'
            if ($statusCode -eq 401 -and $isMoveRequest -and -not $isLoginRequest -and $attempt -eq 0) {
                try {
                    $uriBuilder = [System.Uri]$Uri
                    $script:MoveLoginEndpoint = "{0}://{1}/move/v2/users/login" -f $uriBuilder.Scheme, $uriBuilder.Authority
                    [Environment]::SetEnvironmentVariable('Authorization-Token', $null, 'Process')
                    $freshHeader = Set-NtnxApiHeader -EndPoint 'Move'
                    if ($null -eq $freshHeader -or [string]::IsNullOrWhiteSpace([string]$freshHeader.Authorization)) {
                        throw 'Move Login API did not return an authorization token.'
                    }

                    $RequestHeaders.Authorization = [string]$freshHeader.Authorization
                    $attempt++
                    continue
                }
                catch {
                    throw "Move API request failed [401] $Method $Uri. Token refresh failed: $($_.Exception.Message)"
                }
            }

            if ($statusCode) {
                if ($responseBody) {
                    throw "Move API request failed [$statusCode] $Method $Uri. Response: $responseBody"
                }
                throw "Move API request failed [$statusCode] $Method $Uri. $($_.Exception.Message)"
            }

            throw "Move API request failed $Method $Uri. $($_.Exception.Message)"
        }
    }
}
