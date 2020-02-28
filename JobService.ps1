
 param
 (
 #**some rows are deleted***
 )


        Import-Module  ".\Packed_Module\Invoke-WinService.ps1"
        Import-Module  ".\Packed_Module\Invoke-Sql.ps1"
        Import-Module  ".\Packed_Module\Email.ps1"



###############################################################################
 Function  Replace-Rejex-PatternInFile($File,$AppName,$AppSrvName)
 {
        $fullContent =  Get-Content $File
        $control='<add key="serverUrl"'
        $result = Get-Content $File | Select-String $control | select-string -pattern "^\*" -notmatch  

        if($result -ne $null)
        {   
                 $NewContent = '<add key="serverUrl" value="' + $AppSrvName + "/"+ $Appname  +  '"/>' 
                 $NewContent= $result -replace '\<add\s+key=\"serverUrl"\s+value=\".*\/\>', $NewContent
                 $fullContent = $fullContent -replace [regex]::escape($result), $NewContent
        }
        $fullContent | Set-Content $File
  }

#################################################################################
Try
{
        $SqlQuery = "select * from bld.fn_GetJobserviceReq()"
        $SqlResult = Invoke-Sql_DataTable -DataSource $dataSource -database $AutoBuildDB -SqlQuery $SqlQuery

   if ($SqlResult.Version -gt 0)
     {
     
        foreach ($row in  $SqlResult)
                {
                    $GetService= Get-Service -targetServer $row.TestServerName -serviceName $row.appname 
                    if($GetService.Name -ne ($row.appname))
                       {
                         Robocopy $row.TestSrvBinPath  $row.TestSrvJobServiceBinPath   /MIR /X   /R:10 /W:5 
                         $physicalPath=$row.TestSrvJobServiceBinPath +  "\BimeJobService.exe"
                         Install-Service  -serviceName $row.appname -targetServer $row.TestServerName -displayName $row.appname -physicalPath $physicalPath -userName $userName -password $password -startMode $startMode -description $description -interactWithDesktop $interactWithDesktop
                       }
                    $GetService= Get-Service -targetServer $row.TestServerName -serviceName $row.appname 
                    $AppStateUpdateList = $AppStateUpdateList + $row.appname + "_" +  $GetService.State  + ","
                }
      }
      

         $SqlQuery = "bld.sp_JobserviceState	@UpdateList ='$AppStateUpdateList'"
         $SqlResult3=Invoke-Sql_DataTable -DataSource $dataSource -database $AutoBuildDB  -SqlQuery $SqlQuery
         
         if ( $SqlResult3.appname -gt 0)
            {
                   foreach ($rowSP in  $SqlResult3)
                     {
                         if ($rowSP.ServiceStatus -eq "stop")
                         {
                         "here is stop"
                           stoping-Service -serviceName  $rowSP.AppName -targetServer $RowSP.TestServerName
                         }
                         elseif ($rowSP.ServiceStatus -eq "start")
                         {

                         if ((Test-Path  $rowSP.TestSrvBinPath)   -eq $true) 
                              {
                               "here is start"
                                  Robocopy $rowSP.TestSrvBinPath  $rowSP.TestSrvJobServiceBinPath   /MIR /X   /R:10 /W:5 

                              } 
                                  $File=$rowSP.TestSrvJobServiceBinPath +  "\BimeJobService.exe.config"
                                  Replace-Rejex-PatternInFile -File $File -AppName $rowSP.appname -AppSrvName $rowSP.TestServerName

                           Start-Service -serviceName $rowSP.appname -targetServer $RowSP.TestServerName
                         }

                     }
            }
}
catch [system.exception]
 {
        "Exception: "
        $_
        $body=$_
        $Subject="Error on Jobservice"
        $to=“X@y.com”
        $Cc=“X@y.com”
        Send_Email
}
