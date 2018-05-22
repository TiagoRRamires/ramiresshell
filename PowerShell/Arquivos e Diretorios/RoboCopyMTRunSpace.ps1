
<#
------------------ Sobre ------------------------------------------------------
Conhe�a nosso projeto em www.ramiresshell.com.br
    Creditos para https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/28/beginning-use-of-powershell-runspaces-part-3/
Descri��o:
    Este script copia todos os arquivos e estrutura de diret�rios de uma origem definida no par�metro SourceDir para um local de destino definido no par�metro DestinationDir.
    Pode se definir um valor m�ximo de threads para copias simult�neas de arquivos. Utiliza RunSpaces do .Net Framework, que consome menos mem�ria e possui melhor performance comparado ao jobs do Windows PowerShell.
    Caso ocorra falha em uma copia, ser� executado novas tentativas de copias limitadas ao valor definido no par�metro Retry com intervalo de tempo definido no par�metro Wait entra as tentativas.
    Um arquivo de log � gerado na pasta onde o script esta armazenado contento arquivos copiados, erros de copia, cria��o da estrutura de diret�rios existente na origem no destino e um sumario resumindo estas a��es.
    �til para copia de grande volume de arquivos entre diret�rios ou servidores, com ganho de performance com copias simult�neas.
Considera��es:
    O usu�rio executor deve possuir permiss�o NTFS de leitura nos arquivos de origem a serem copiados.
    O usu�rio executor deve possuir permiss�o NTFS de modifica��o no caminho de destino a receber as copias e no diret�rio onde o script esta armazenado para cria��o e escrita no arquivo de log.
    N�o use no Windows PowerShell v4, esta vers�o apresenta problemas de memory leak com o RunSpace.
Descri��o dos Par�metros:
    -SourceDir
        Campo Obrigat�rio. Tipo String. Informe o nome do diret�rio de origem. Aceita caminhos UNC e local.
    -DestinationDir
        Campo Obrigat�rio. Tipo String. Informe o nome do diret�rio de destino. Aceita caminhos UNC e local.
    -Threads
        Campo Opcional. Tipo Inteiro. Informe um numero para limitar o m�ximo de copias simult�neas executadas pelo script. O valor padr�o � de 5 threads.
    -Retry
        Campo Opcional. Tipo Inteiro. Informe um numero m�ximo de tentativas de copia para arquivos cuja copia esta apresentando erro. O valor padr�o � de 3 tentativas.
    -Wait
        Campo Opcional. Tipo Inteiro. Informe um numero de espera em segundos entre as tentativas de copias de um arquivo que esta apresentando erro. O valor padr�o � de 2 segundos.
    -Overwrite
        Campo Opcional. Tipo Switch. Informe se a copia deve sobrepor arquivos j� existentes no destino.
Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Copia arquivos da pasta C:\Arquivos1 do computador onde o script esta sendo executado para o caminho de rede \\FileServer\Arquivo\Folder1. Sobrep�em arquivos j� existentes no destino. Executa 4 copias simult�neas de arquivos e 3 tentativas de copias para arquivos que estiverem apresentando problemas na copia. Aguarda 40 segundos entre as tentativas de copia que est�o apresentando problemas.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\RS\Script\RoboCopyMTRunSpace.ps1 -SourceDir C:\Arquivos1 -DestinationDir \\FileServer\Arquivo\Folder1 -Overwrite -Threads 4 -Wait 40
    Este exemplo pode ser executado da console do Windows PowerShell. Copia arquivos do caminho de rede \\FS2\Archieve\1 para o caminho de rede \\FileServer\Arquivo\Folder1. N�o sobrep�em arquivos j� existentes no destino. Executa 5 copias simult�neas de arquivos e 3 tentativas de copias para arquivos que estiverem apresentando problemas na copia. Aguarda 2 segundos entre as tentativas de copia que est�o apresentando problemas.
    PS > C:\RS\Script\RoboCopyMTRunSpace.ps1 -SourceDir \\FS2\Archieve\1 -DestinationDir \\FileServer\Arquivo\Folder1
------------------------------------------------------------------------
#>



Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDir,
	
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationDir,

    [ValidateNotNullOrEmpty()]
    [int]$Threads=5,

    [ValidateNotNullOrEmpty()]
    [int]$Retry=3,

    [ValidateNotNullOrEmpty()]
    [int]$Wait=2,

    [Parameter()]
    [Switch]$Overwrite
)



$Error.Clear()
# ------------------------ global var -------------------------------
$FileLog = ($MyInvocation.MyCommand.Path).SubString(0,($MyInvocation.MyCommand.Path).LastIndexOfAny("\")) + "\" + $MyInvocation.MyCommand.Name.Replace(".ps1","-") + (Get-Date).ToString("dd-MM-yyyy") + ".log"
$Global:DirCreated = 0
$Global:DirExisting = 0
$Global:DirNotFound = 0
$Global:FileCopied = 0
$Global:FileDiffSize = 0
$Global:FileNotCopy = 0
$Global:FileError = 0
$ReturnJob = ""
$MyId = 1
[int]$MaxConcurrentThreat = 10000
# -------------------------------------------------------------------


Set-Content -Path $FileLog -Value ("Inicio: " + [string](Get-Date -Format F) + "`r`n" +
"Parametros:`r`n" +
"SourceDir: $SourceDir`r`n" + 
"DestinationDir: $DestinationDir`r`n" +
"Threads: $Threads`r`n" +
"Retry: $Retry`r`n" +
"Wait: $Wait`r`n" +
"Overwrite: $Overwrite`r`n"
) -Force -Encoding Unicode



Function CopyStatistic ($OutPutThread)
{
    ForEach ($OutThreadLine in $OutPutThread)
    {
        Switch -Wildcard ($OutThreadLine)
        {
            "*- Copiado arquivo -*"{
                $Global:FileCopied += 1
            }
            "*- Copia com TAMANHO DIFERENTE -*"{
                $Global:FileDiffSize += 1
            }
            "*- Copia N�O executada -*"{
                $Global:FileNotCopy += 1
            }
            "*- Erro na copia -*"{
                $Global:FileError += 1
            }
        }
    }
}


#Valida vers�o do Windows PowerShell
If ((Get-Host).Version.Major -lt 3)
{
    Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Vers�o n�o comporta todos cmdlet utilizados pelo script. Recomendado vers�o 5.1 do Windows PowerShell") -Force -Encoding Unicode
    Exit
}

If ((Get-Host).Version.Major -eq 4)
{
    Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Windows PowerShell v4 apresenta erros de memory leak com runspace e jobs. Recomendado vers�o 5.1 do Windows PowerShell") -Force -Encoding Unicode
    Exit
}


Try
{
    $ThreadTable = New-Object System.Collections.ArrayList

    #Lista todas as pastas na origem
    @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Directory -Force -ErrorAction Stop) | ForEach-Object -Process {
        $DirOrigemLine = $_
        $NewDir = $DirOrigemLine.FullName.Replace($SourceDir, $DestinationDir)
        $DirCreate = $True


        #-------------- cria pasta no destino -------------------------
        If (Test-Path -LiteralPath $NewDir)
        {
            #Valida se pasta j� existia ou n�o para registar no log
            $DirCreate = $false
            $Global:DirExisting += 1
        }
        Else
        {
            $MyRetry = 1
            While ($MyRetry -le $Retry -and (-not (Test-Path -LiteralPath $NewDir)))
            {
                #Espera apenas apos a primeira tentiva
                If ($MyRetry -gt 1)
                {
                    Start-Sleep -Seconds $Wait
                    Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Tentativa n.� $MyRetry para cria��o do diretorio: $NewDir") -Force -Encoding Unicode
                }

                New-Item -Path $NewDir -ItemType Directory -ErrorAction SilentlyContinue
                $MyRetry += 1                
            }
        }

        If (Test-Path -LiteralPath $NewDir)
        {
            If ($DirCreate)
            {
                Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "  Diretorio criado: $NewDir") -Force -Encoding Unicode
                $Global:DirCreated += 1
            }

            $PsSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
            $PsPool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Threads)
            $PsPool.Open()

            #Copia Arquivos
            $SourceFileTable = [System.IO.Directory]::GetFiles($DirOrigemLine.FullName)
            ForEach ($SourceFile in $SourceFileTable)
            {
                $PsRun = [System.Management.Automation.PowerShell]::Create()
                $PsRun.RunspacePool = $PsPool
                $PsRun.AddScript({
                    param([string]$IdJob, [string]$JobSourceDir, [string]$JobDestinationDir, [string]$JobSourceFile, [int]$JobRetry, [int]$JobWait, [Boolean]$JobOverwrite)

                    Function GetSize ([string]$FilePath)
                    {
                        Try
                        {
                            $FileLen = (Get-Item -LiteralPath $FilePath -Force -ErrorAction Stop).Length   
                        }
                        Catch
                        {
                            $FileLen = 0
                        }
                        return $FileLen
                    }

                    $FileDestination = $JobSourceFile.Replace($JobSourceDir, $JobDestinationDir)
                    $RetryCopy = 1
                    $CopyError = $false

    
                    If (-not $JobOverwrite -and (Test-Path -LiteralPath $FileDestination))
                    {
                        #Se existe arquivo e n�o � para sobrepor n�o faz nada
                    }
                    Else
                    {
                        While ($RetryCopy -le $JobRetry)
                        {
                            Try
                            {
                                [System.IO.File]::Copy($JobSourceFile, $FileDestination, $JobOverwrite)
                                $CopyError = $False
                            }
                            Catch
                            {
                                $CopyError = $True
                            }

                            If (Test-Path -LiteralPath $FileDestination)
                            {
                                $RetryCopy = $JobRetry + 1
                            }
                            Else
                            {
                                Start-Sleep -Seconds $JobWait
                                Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Tentativa n.� $RetryCopy para copia do arquivo: $JobSourceFile")
                                $RetryCopy += 1
                            }
                        }

                        #Loga status da copia
                        If (Test-Path -LiteralPath $FileDestination)
                        {
                            $JobSourceFileLen = GetSize -FilePath $JobSourceFile
                            $FileDestinationLen = GetSize -FilePath $FileDestination
            
                            If ($JobSourceFileLen -eq $FileDestinationLen)
                            {
                                If ($CopyError)
                                {
                                    Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Erro na copia - J� existe no destino com tamanho IGUAL - Origem: $JobSourceFile   Tamanho: $JobSourceFileLen  -->>  destino: $FileDestination  Tamanho: $FileDestinationLen  " + $Error[0].Exception.Message + "   " + $Error[0].InvocationInfo.InvocationName)
                                }
                                Else
                                {
                                    Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Copiado arquivo - Origem: $JobSourceFile  Tamanho: $JobSourceFileLen  -->>  destino: $FileDestination  Tamanho: $FileDestinationLen")
                                }
                            }
                            Else
                            {
                                If ($CopyError)
                                {
                                    Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Erro na copia - J� existe no destino com tamanho DIFERENTE - Origem: $JobSourceFile  Tamanho: $JobSourceFileLen  -->>  destino: $FileDestination  Tamanho: $FileDestinationLen  "  + $Error[0].Exception.Message + "   " + $Error[0].InvocationInfo.InvocationName)
                                }
                                Else
                                {
                                    Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Copia com TAMANHO DIFERENTE - Origem: $JobSourceFile  Tamanho: $JobSourceFileLen  -->>  destino: $FileDestination  Tamanho: $FileDestinationLen")
                                }
                            }
                        }
                        Else
                        {
                            Write-Output ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + " Job: $IdJob  - Copia N�O executada - Origem: $JobSourceFile  -->>  destino: $FileDestination")
                        }
                    }
                })

                $PsRunParam = @{IdJob = $MyId;
                                JobSourceDir = $SourceDir;
                                JobDestinationDir = $DestinationDir;
                                JobSourceFile = $SourceFile;
                                JobRetry = $Retry;
                                JobWait = $Wait;
                                JobOverwrite = $Overwrite}
                $PsRun.AddParameters($PsRunParam)
                $MyProcess = $PsRun.BeginInvoke()
                $ThreadTable.Add(@{PsRunScript=$PsRun;Handle=$MyProcess})

                $MyId += 1

                #Aguarda quando a tabela estiver acima de MaxConcurrentThreat linhas para evitar uso excessivo de memoria
                If ($ThreadTable.Count -gt $MaxConcurrentThreat)
                {
                    Start-Sleep -Seconds 60
                }

                #Limpa threads finalizadas
                [int]$Index = 0
                While ($Index -lt $ThreadTable.Count)
                {
                    If ($ThreadTable.Item($Index).Handle.IsCompleted)
                    {
                        $OutThread = $ThreadTable.Item($Index).PsRunScript.EndInvoke($ThreadTable.Item($Index).Handle)
                        Add-Content -LiteralPath $FileLog -Value $OutThread -Force -Encoding Unicode
                        CopyStatistic -OutPutThread $OutThread

                        $ThreadTable.Item($Index).PsRunScript.Dispose()
                        $ThreadTable.RemoveAt($Index)
                    }
                    $Index += 1
                }
            }

            #Le conteudo dos handles finalizados
            $ThreadTable | ForEach-Object {
                While (-not($_.Handle.IsCompleted))
                {
                    Start-Sleep -Seconds 1
                }
                $OutThread = $_.PsRunScript.EndInvoke($_.Handle)
                Add-Content -LiteralPath $FileLog -Value $OutThread -Force -Encoding Unicode
                CopyStatistic -OutPutThread $OutThread

                $_.PsRunScript.Dispose()
            }
            $PsPool.Close()
            $PsPool.Dispose()
            $ThreadTable.Clear()
        }
        Else
        {
            Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "  Diretorio N�O criado: $NewDir  - N�o havera tentativa de copias para este diretorio") -Force -Encoding Unicode
            $Global:DirNotFound += 1
        }
    }
}
Catch
{
    Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Catch:  " + $Error[0].Exception.Message + "   " + $Error[0].InvocationInfo.InvocationName) -Force -Encoding Unicode
}






#--------- Sumario -----------------
[string]$Block=[char]9608
$BlockLine = $Block * 100
Add-Content -LiteralPath $FileLog -Value ("`r`n$BlockLine`r`n$Block") -Force -Encoding Unicode
Add-Content -LiteralPath $FileLog -Value ($Block + (" " * 40) + "Sum�rio`r`n$Block") -Force -Encoding Unicode
Add-Content -LiteralPath $FileLog -Value ("$Block    Diret�rios -   Criados: $Global:DirCreated     Existentes: $Global:DirExisting     N�o encontrados: $Global:DirNotFound") -Force -Encoding Unicode
Add-Content -LiteralPath $FileLog -Value ("$Block    Arquivos   -   Copiados: $Global:FileCopied     Tamanhos Diferentes: $Global:FileDiffSize     N�o Copiado: $Global:FileNotCopy     Erros: $Global:FileError") -Force -Encoding Unicode
Add-Content -LiteralPath $FileLog -Value ("$Block`r`n$BlockLine") -Force -Encoding Unicode
#-----------------------------------

Add-Content -LiteralPath $FileLog -Value ("`r`nScript finalizado: " + [string](Get-Date -Format F) + "`r`nDebug: $Error") -Force -Encoding Unicode


