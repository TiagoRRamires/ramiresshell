
<#
------------------ Sobre ------------------------------------------------------
Conhe�a nosso projeto em www.ramiresshell.com.br
Descri��o:
    Este script copia todos os arquivos e estrutura de diret�rios de uma origem definida no par�metro SourceDir para um local de destino definido no par�metro DestinationDir.
    Pode se definir um valor m�ximo de threads para copias simult�neas de arquivos. Cuidado para n�o definir um valor muito alto, pois poder� sobrecarregar o computador.
    Caso ocorra falha em uma copia, ser� executado novas tentativas de copias limitadas ao valor definido no par�metro Retry com intervalo de tempo definido no par�metro Wait entra as tentativas.
    Um arquivo de log � gerado na pasta onde o script esta armazenado contento arquivos copiados, erros de copia, cria��o da estrutura de diret�rios existente na origem no destino e um sumario resumindo estas a��es.
    �til para copia de grande volume de arquivos entre diret�rios ou servidores, com ganho de tempo com copias simult�neas. Quantia muito grande de arquivos ira utilizar muita memoria RAM.
Considera��es:
    O usu�rio executor deve possuir permiss�o NTFS de leitura nos arquivos de origem a serem copiados.
    O usu�rio executor deve possuir permiss�o NTFS de modifica��o no caminho de destino a receber as copias e no diret�rio onde o script esta armazenado para cria��o e escrita no arquivo de log.
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
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\RS\Script\RoboCopyMTJob.ps1 -SourceDir C:\Arquivos1 -DestinationDir \\FileServer\Arquivo\Folder1 -Overwrite -Threads 4 -Wait 40
    Este exemplo pode ser executado da console do Windows PowerShell. Copia arquivos do caminho de rede \\FS2\Archieve\1 para o caminho de rede \\FileServer\Arquivo\Folder1. N�o sobrep�em arquivos j� existentes no destino. Executa 5 copias simult�neas de arquivos e 3 tentativas de copias para arquivos que estiverem apresentando problemas na copia. Aguarda 2 segundos entre as tentativas de copia que est�o apresentando problemas.
    PS > C:\RS\Script\RoboCopyMTJob.ps1 -SourceDir \\FS2\Archieve\1 -DestinationDir \\FileServer\Arquivo\Folder1
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



$JobRun = {
    param($IdJob, $JobSourceDir, $JobDestinationDir, $JobSourceFile, $JobRetry, $JobWait, $JobOverwrite)

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


}


Function CopyStatistic ()
{
    #Trata ReturnJob para contar arquivos copiados, dubplicados e n�o copiados
    ForEach ($ReturnJobLine in $ReturnJob)
    {
        Switch -Wildcard ($ReturnJobLine)
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


Function ReceiveJobData()
{
    $ReturnJob = Get-Job -HasMoreData $true | Receive-Job
    If ($ReturnJob.Length -gt 0)
    {
        Add-Content -LiteralPath $FileLog -Value $ReturnJob -Force -Encoding Unicode
        CopyStatistic
    }
}




Try
{
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

            #Copia Arquivos
            $SourceFileTable = [System.IO.Directory]::GetFiles($DirOrigemLine.FullName)
            ForEach ($SourceFile in $SourceFileTable)
            {
                While (@(Get-Job -State Running).Length -ge $Threads)
                {
                    Start-Sleep -Seconds 1
                    If (@(Get-Job -HasMoreData $true).Length -gt 0)
                    {
                        ReceiveJobData
                    }
                    Get-Job -State Completed -HasMoreData $false | Remove-Job
                }
            
                Start-Job -ScriptBlock $JobRun -ArgumentList $MyId, $SourceDir, $DestinationDir, $SourceFile, $Retry, $Wait, $Overwrite
                $MyId += 1
            }
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
    Add-Content -LiteralPath $FileLog -Value ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   " + $Error[0].Exception.Message + "   " + $Error[0].InvocationInfo.InvocationName) -Force -Encoding Unicode
}




#Aguarda a finaliza��o de todos os jobs
While(@(Get-Job -HasMoreData $true).Length -gt 0 -or @(Get-Job -State Running).Length -gt 0)
{
    ReceiveJobData
    Start-Sleep -Seconds 5
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


