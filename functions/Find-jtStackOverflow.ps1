function Find-jtStackOverflow {
<#
.SYNOPSIS
    Function that will query the StackExchange API for any questions which fit the given criteria.
.DESCRIPTION
    The Find-jtStackOverflow cmdlet will query the StackExchange API.

    See: https://api.stackexchange.com/docs/search.
.PARAMETER Query
    Specifies the query.
.PARAMETER Sort
    Specifies the sort criteria. The following fields can be selected: activity, creation, votes, relevance.

    relevance is the default sort.
.PARAMETER Tags
    Specifies the tags.
.PARAMETER After
    Specifies the fromdate criteria.
.PARAMETER Pagesize
    Specifies the pagesize criteria.
.PARAMETER Site
    Specifies the site criteria. Only the top 5 StackExchange sites with most traffic can be selected.
    
    See: https://stackexchange.com/sites?view=list#traffic.
.EXAMPLE
    - Example 1: Get the roles for an Availability Group -

    PS C:\> Find-jtStackOverflow -Query "powershell foreach" -Sort relevance -After (Get-Date).AddYears(-1)
.NOTES
    Author: Jeroen Trimbach
    Website: Https://jeroentrimbach.com
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Alias("Search")]
        [string[]]$Query,

        [Parameter(Mandatory=$false)]
        [ValidateSet('activity','creation','votes','relevance')]
        [string]$Sort = 'relevance',

        [Parameter(Mandatory=$false)]
        [datetime]$After = (Get-Date).AddYears(-5),

        [Parameter(Mandatory=$false)]
        [Alias("Count","Total")]
        [int]$MaxAnswers = 100,

        [Parameter(Mandatory=$false)]
        [ValidateSet('stackoverflow','superuser','askubuntu','math','serverfault')]
        [string]$Site = 'stackoverflow'
    )
    DynamicParam {
        $attributes = new-object System.Management.Automation.ParameterAttribute
        $attributes.Mandatory = $false

        $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)

        $tagsUrl = 'https://api.stackexchange.com/2.3/tags?pagesize=100&sort=popular&site=stackoverflow'
        $arrSet = (Invoke-RestMethod $tagsUrl).Items.Name

        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter('Tags', [string[]], $attributeCollection)
            
        $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add('Tags', $dynParam1)

        # https://community.spiceworks.com/topic/1295222-powershell-populate-a-validate-set-from-script?page=1#entry-5231850
        return $paramDictionary
    }

    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay)] 3..2..1.. GO! $($myinvocation.mycommand)"
        Add-Type -AssemblyName System.Web

        $tags = $PSBoundParameters['Tags'] -join ';'
        # remove special characters apart from ';'.
        # https://www.regular-expressions.info/unicode.html
        $tags = $tags -replace '[^\p{L}\p{Nd}/;]', ''
    } #begin

    Process {
        foreach ($item in $Query) {
            try {
                Write-Verbose "Creating collection for query: $item."
                # https://powershellmagazine.com/2019/06/14/pstip-a-better-way-to-generate-http-query-strings-in-powershell/
                $collection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
                $collection.Add('order','desc')
                $collection.Add('sort',$Sort)
                $collection.Add('pagesize',$MaxAnswers)
                if (!([string]::IsNullOrEmpty($After))) {
                    $fromdate = Get-Date ($After) -UFormat %s
                    $collection.Add('fromdate',$fromdate)
                } else {
                    Write-Verbose 'After not specified, excluding fromdate from api call.'
                }
                if (!([string]::IsNullOrEmpty($tags))) {
                    $collection.Add('tagged',$tags)
                } else {
                    Write-Verbose 'No tags specified, excluding tags from api call.'
                }
                # remove all special characters and replace multiple white spaces with a single white space.
                # https://www.regular-expressions.info/unicode.html
                $item = $item -replace '[^\p{L}\p{Nd}\p{Z}]', '' -replace '\s+',' '
                $collection.Add('intitle',$item)
                if (!([string]::IsNullOrEmpty($Site))) {
                    $collection.Add('site',$Site) 
                }

                $url = 'https://api.stackexchange.com/2.3/search?'
                $uriRequest = [System.UriBuilder]$url
                $uriRequest.Query = $collection.ToString()
                
                Write-Verbose "absolute uri is: $($uriRequest.Uri.AbsoluteUri)"
                $question = Invoke-RestMethod $uriRequest.Uri.AbsoluteUri

                # 'stackoverflow','superuser','askubuntu','math','serverfault'
                switch ($Site)
                {
                    'stackoverflow' { $questionsurl = 'https://stackoverflow.com/questions/'        }
                    'superuser'     { $questionsurl = 'https://superuser.com/questions/'            }
                    'askubuntu'     { $questionsurl = 'https://askubuntu.com/questions/'            }
                    'math'          { $questionsurl = 'https://math.stackexchange.com/questions/'   }
                    'serverfault'   { $questionsurl = 'https://serverfault.com/questions/'          }
                }
                Write-Verbose "Questions url is $questionsurl."

                $Answers = $question.Items | Where-Object {$_.is_answered -eq $true} | Foreach-Object {
                    $props = [ordered]@{
                        Question = $_.Title;
                        Link = $questionsurl + $_.question_id;
                        Tags = $_.tags;
                        Date = ([System.DateTimeOffset]::FromUnixTimeSeconds($_.last_activity_date)).DateTime.GetDateTimeFormats()[1];
                    }
                    $obj = New-Object -TypeName PSObject -Property $props
                    Write-Output $obj
                }
                Write-Output $Answers
            } catch {
                Write-Error $_.Exception.Message
            }
        } #foreach
    } #process

    End {
        Write-Verbose "Daily allowed API calls: $($question.quota_max). You have $($question.quota_remaining) API calls remaining for today."
        Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($myinvocation.mycommand)"
    }    
}