 param
 (
 #**some rows are deleted***
 )

        Import-Module  $PSScriptRoot\Invoke-Sql.ps1
        Import-Module  $PSScriptRoot\Invoke-iis.ps1
        Import-Module  $PSScriptRoot\CommonConfigFileRenew.ps1
        Import-Module  $PSScriptRoot\GetPhysicalPath_FromUNC.ps1

     
######################### Set-fileContent ####################################

 function Set-ExeConfigContent($pathToFile,$AppConnction)
 {
    $TestExereplaceWith =@('<?xml version="1.0"?>
    <configuration>
      <appSettings>
        <add key="ServerUrl" value="'+ $AppConnction +'"/>
        <add key="loaderVersionControl" value="true" />
       </appSettings>
      <startup >
      </startup>
    </configuration>')

Clear-Content -Path $pathToFile -Force 
Set-Content $pathToFile -Value $TestExereplaceWith
}

################################# Copy-ItemUNC #####################################
 
 Function Copy-ItemUNC ($SourcePath,$TargetPath)
{
     if ( ! (test-path $TargetPath))
         {
            New-Item $TargetPath -ItemType Directory -Force
            Copy-Item $SourcePath -Destination $TargetPath -Force
            Write-Host "Destination did not exist and has been created" 
         }
}

########################### CreateSiteLnk #########################################

Function CreateSiteLnk($BimeSiteTestPath,$CorpToDeploy,$CurVersion,$SiteLink,$Product)
{
    if ((test-path $BimeSiteTestPath) -eq $true)
    {
        $SiteName=$Product + "_" + $CorpToDeploy + '_' + $CurVersion
        $Shell = New-Object -ComObject ("WScript.Shell")
        $Favorite = $Shell.CreateShortcut($BimeSiteTestPath +"\"+  $SiteName + ".url")
        $Favorite.TargetPath = $SiteLink;
        $Favorite.Save()
    }
}

########################### CreateVdr #########################################
Function CreateVdr($TestServerDestPath,$BuildSrvDepPath,$BuildServerCmnDll,$BuildServerBimeExePath,$CorpToDeploy,$CurVersion,$CurProductName)
{
   $CommonConfigFile= $TestServerDestPath + '\Com.config'

   #Copy_Regex_ExactDestPath -sourcePath $BuildSrvDepPath -destPath  $TestServerDestPath -excludeMatch $Excluded
                      
    robocopy $BuildSrvDepPath $TestServerDestPath /XD "Application Files2" "Binaries" "bin2" "bin3" "Tools.Net" "Source" "Report" /E   /Z /X /MIR  /R:0 /W:1 
    xcopy $BuildServerCmnDll $TestServerBinPath /y
    xcopy $BuildServerBimeExePath $TestServerBinPath /y

    $SqlQuery = "select bld.fn_CommonConFigFile ('$CorpToDeploy','$CurVersion','$CurProductName','Test') as CommonConFigFile "
    $SqlResult = Invoke-Sql_DataTable -DataSource $dataSource -database $AutoBuildDB -SqlQuery $SqlQuery
    $SqlResult.CommonConFigFile | Set-Content  $CommonConfigFile -Force

                     
}

########################### CreateAppAndPool #########################################
Function CreateAppAndPool($TestServerName,$PoolName,$AppName,$TestServerDepPath)
{

   $physicalPath = GetPhysicalPath -physicalPath $TestServerDepPath
   Create_pool_RemoteServer -Server $TestServerName -PoolName $PoolName 
   Create_Site_RemoteServer -Server $TestServerName -PoolName $PoolName -physicalPath $physicalPath -AppName $AppName

}


############################################################################
  
Try{
        $SqlQuery = "bld.sp_DeployCurCorp"
        $SqlResult = Invoke-Sql_DataTable -DataSource $dataSource -database $AutoBuildDB -SqlQuery $SqlQuery

        if ( $SqlResult.Version -gt 0)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           {

    foreach ($row in  $SqlResult)
           {
            $CorpToDeploy = $Row.Corp
            $CurVersion   = $Row.Version
           
            $SqlQuery = "select * from bld.fn_CorpVersionInfo('$CorpToDeploy','$CurVersion','$ProductS')"
            $SqlResult = Invoke-Sql_DataTable -DataSource $dataSource -database $AutoBuildDB -SqlQuery $SqlQuery
 
                foreach ($rowset in  $SqlResult)
                 {
                     $ReportPath=$Rowset.TestSrvReportPath
                     $TestServerDepPath= $Rowset.TestSrvDepPath
                     $TestServerDestPath=$TestServerDepPath.substring(0,$TestServerDepPath.LastIndexOf("\"))
                     $TestServerBinPath= $rowset.TestSrvBinPath
                     $BuildSrvDepPath=$Rowset.BuildSrvDepPath
                     $CurProductName=$rowset.ProductName
                     $TestServerName=$rowset.TestServerName

                     if ($rowset.ProductName -eq 'Bime.Net')
                        {

                        $BuildServerBimeExePath = $rowset.BuildSrvInsCorpPath + '\X.Exe*'
                        $BuildServerCmnDll = $rowset.BuildSrvInsCorpPath + '\X.cmn.dll'

                        #$BimeNetPath=$Rowset.TestSrvBinPath
                        $BimeTestPath='\\'+ $Exeserver + '\Test\Bime.Net\' + $Rowset.Version + '\' + $rowset.Corp
                         
                        $BimeDemoPath = '\\'+ $ExeServer + '\Version_Demo\'  + $Rowset.Version + '\' + $rowset.Corp
                        $BimeDBPath = $Rowset.dbservername +'\'+ $Rowset.DBInstanceVersion + "             " + $Rowset.DBName 

                        $TestExestringToReplace = <#$Rowset.TestServerName#> "Appproxy/" + $rowset.Corp + '_' + $Rowset.Version
                        $TestExepathToFile = $BimeTestPath + "\exe.config"
                        $BimeExeDemoPath=$BimeDemoPath + "\exe.config"

                        $TestServerValidIp=$Rowset.ValidIpAddress # + ":" + $Rowset.HttpPort
                        $DemoExestringToReplace= $TestServerValidIp + "/" + $rowset.Corp + '_' + $Rowset.Version 

                   
                        $Excluded=@("Application Files2", "Binaries", "bin2", "bin3","Tools.Net","Source","Report")

                        $AppName = $IISSite + $rowset.Corp  + "_" + $Rowset.Version
                        $PoolName =  $Rowset.Version + "." + $rowset.Corp 

                        foreach ($AppServer in $SqlResult.otherservers -split ",")
                          {

                            $TestServerDepPath= $Rowset.TestSrvDepPath
                            $Dstpath  = "\\" + ($TestServerDepPath -replace '\\\\\w+(\-)*\w*' ,$Appserver)
                            $TestServerDestPath=$Dstpath.substring(0,$Dstpath.LastIndexOf("\"))
                            $TestServerBinPath="\\" + ( $rowset.TestSrvBinPath -replace '\\\\\w+(\-)*\w*' ,$Appserver)   
                            
                            CreateVdr -TestServerDestPath $TestServerDestPath -BuildSrvDepPath $BuildSrvDepPath -BuildServerCmnDll $BuildServerCmnDll -BuildServerBimeExePath $BuildServerBimeExePath -CorpToDeploy $CorpToDeploy -CurVersion $CurVersion -CurProductName $CurProductName
                            CreateAppAndPool -TestServerName $AppServer -PoolName $PoolName -AppName $AppName  -TestServerDepPath $Dstpath
                          }

                        }
                        elseif ($rowset.ProductName -eq 'BimeSite')
                        {

                         $BimeSiteTestPath='\\'+ $Exeserver + '\Test\Site\' + $rowset.Corp
                         $BimeSiteLink='https://' + $rowset.TestServerName + '/BimeSite_' + $rowset.Corp + '_' + $Rowset.Version
                         
                         $TestServerValidIp=$Rowset.ValidIpAddress  + ":" + $Rowset.HttpsPort
                         $BimeSiteDemoLink='https://' + $TestServerValidIp + '/BimeSite_' + $rowset.Corp + '_' + $Rowset.Version

                         $AppName = $IISSite +'BimeSite_' + $rowset.Corp + '_' + $Rowset.Version
                         $PoolName= $Rowset.Version + '.Site.' + $rowset.Corp 

                         CreateVdr -TestServerDestPath $TestServerDestPath -BuildSrvDepPath $BuildSrvDepPath -BuildServerCmnDll $BuildServerCmnDll -BuildServerBimeExePath $BuildServerBimeExePath -CorpToDeploy $CorpToDeploy -CurVersion $CurVersion -CurProductName $CurProductName
                         CreateAppAndPool -TestServerName $AppServer -PoolName $PoolName -AppName $AppName  -TestServerDepPath $TestServerDepPath
                        }

                        elseif ($rowset.ProductName -eq 'BimeApi')
                        {
                         start-sleep -second 5
                        "injam4"
                         $BimeApiTestPath='\\'+ $Exeserver + '\Test\BimeApi\' + $rowset.Corp
                         $BimeApiLink='https://' + $rowset.TestServerName + '/BimeApi_' + $rowset.Corp + '_' + $Rowset.Version
                         
                         $TestServerValidIp=$Rowset.ValidIpAddress  + ":" + $Rowset.HttpsPort
                         $BimeApiDemoLink='https://' + $TestServerValidIp + '/BimeApi_' + $rowset.Corp + '_' + $Rowset.Version

                         $AppName = $IISSite +'BimeApi_' + $rowset.Corp + '_' + $Rowset.Version
                         $PoolName= $Rowset.Version + '.BimeApi.' + $rowset.Corp 
                         CreateVdr -TestServerDestPath $TestServerDestPath -BuildSrvDepPath $BuildSrvDepPath -BuildServerCmnDll $BuildServerCmnDll -BuildServerBimeExePath $BuildServerBimeExePath -CorpToDeploy $CorpToDeploy -CurVersion $CurVersion -CurProductName $CurProductName
                         CreateAppAndPool -TestServerName $AppServer -PoolName $PoolName -AppName $AppName  -TestServerDepPath $TestServerDepPath
                        }

                 }


   ############################################################################
          
            $body = CreatHtmlBody  -MsgArray $MsgArray -BimeTestPath $BimeTestPath -ReportPath $ReportPath -BimeSiteTestPath $BimeSiteTestPath -BimeDemoPath $BimeDemoPath -BimeDBPath $BimeDBPath  -BimeApiTestPath $BimeApiTestPath | out-string 

            Copy-ItemUNC -SourcePath  $BuildServerBimeExePath -TargetPath $BimeTestPath
            
            Copy-ItemUNC -SourcePath  $BuildServerBimeExePath -TargetPath $BimeDemoPath

            Set-ExeConfigContent -pathToFile $TestExepathToFile -AppConnction $TestExestringToReplace

            Set-ExeConfigContent -pathToFile  $BimeExeDemoPath -AppConnction $DemoExestringToReplace

            CreateSiteLnk -BimeSiteTestPath $BimeSiteTestPath -CorpToDeploy $Rowset.Corp -CurVersion $Rowset.Version -SiteLink $BimeSiteLink -Product "BimeSite"

            CreateSiteLnk -BimeSiteTestPath $BimeDemoPath -CorpToDeploy $Rowset.Corp -CurVersion $Rowset.Version -SiteLink $BimeSiteDemoLink -Product "BimeSite"

            CreateSiteLnk -BimeSiteTestPath $BimeApiTestPath -CorpToDeploy $Rowset.Corp -CurVersion $Rowset.Version -SiteLink $BimeApiLink -Product "BimeApi"

            CreateSiteLnk -BimeSiteTestPath $BimeDemoPath -CorpToDeploy $Rowset.Corp -CurVersion $Rowset.Version -SiteLink $BimeApiDemoLink -Product "BimeApi"

            Send_Email
         }
  }
    }
catch [system.exception]
    {
        "Exception: "
        $_
        $body=$_
        $Subject="Error on Deploy new corp"
        $to=“X@y.com”
        $Cc=“X@y.com”
        Send_Email
    }


