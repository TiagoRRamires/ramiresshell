 
<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script é uma modificação do script github.com/TiagoRRamires/ramiresshell/blob/master/PowerShell/Arquivos%20e%20Diretorios/PurgaFiles.ps1 para execução remota utilizando WinRM.
    Exclui arquivos a partir de um valor especifico de dias passados, considerando data de criação, leitura ou modificação. Pode definir as extensões de arquivos que se deseja excluir.
    Para conexão remota ao destino que deve ter arquivos purgados defina o nome do servidor (WinRM Client), usuário e senha para delegação de credenciais.
    O script exclui arquivos que satisfaçam os parâmetros -Days e -Extension no diretório e sub diretórios definidos no parâmetro -PathDirPurga
    Útil para excluir arquivos antigos não necessários, mantendo computadores com espaço disponível em disco como por exemplo arquivos de logs de aplicações ou serviços.
    Util para organizar o script de purga e seus logs de execução centralizado em um único local da rede e servir a diversos servidores remotamente para purga de arquivos.
    Registra em log o caminho de todos os arquivos excluídos.
    Registra um log no servidor WinRM Client contento erros gerados em tempo de execução. O arquivo é gerado no mesmo diretório de armazenamento do script.


Considerações:
O usuário que executar este script deve possuir as seguintes permissões NTFS:
    Permissão de Modificação na pasta onde o script será armazenado para criação dos arquivos de log de debug.
    Permissão de Exclusão no diretório e sub-diretórios definido no parâmetro -PathDirPurga.
    Permissão de Modificação no diretório definido no parâmetro -PathDirLog
O usuário para delegação definido no parâmetro -CredDomainUser deve ter permissões para criar sessão WinRM no servidor definido no parâmetro -Server.


Descrição dos Parâmetros:
-PathDirLog
    Campo Opcional. Tipo String. Informe o caminho do diretório onde deve ser armazenado o arquivo de log que registra o nome dos arquivos excluídos por este script.
-PathDirPurga
    Campo Obrigatório. Tipo String. Informe o caminho do diretório onde deve ser purgado os arquivos. Arquivos em sub-diretórios também serão purgados.
-AttributeFileLog
    Campo Obrigatório. Tipo String. Informe o atributo de data do arquivo para purga. Aceita os valores:
        C => Exclui baseado na data de criação do arquivo.
        M => Exclui baseado na data da última modificação do arquivo.
        R => Exclui baseado na data de último acesso de leitura ao arquivo.
-Days
    Campo Obrigatório. Tipo Integer. Informe o número de dias passados para exclusão do arquivo. Aceita de 1 dia até 10000 dias.
-Extension
    Campo Obrigatório. Tipo Array de String. Informe as extensões de arquivos que se deseja excluir. Use asteriscos (*) exclui todos os tipos de arquivos. Cada extensão informada deve ter de 1 a 5 caracteres.
-DelNullDir
    Campo Opcional. Tipo Switch. Exclui sub-diretórios vazios do diretório informado no parâmetro PathDirPurga.
-CredDomainUser
    Campo Obrigatório, Tipo String. Informe domínio e usuário no formato SamAccountName. Esta conta executara o script remotamente. Deve ser usado o formato domínio\usuário.
-CredPass
    Campo Obrigatório. Tipo String. Informe a senha do usuário definido no parâmetro CredDomainUser.
-Server
    Campo Obrigatório. Tipo String. Informe o nome do servidor (WinRM Server) que recebera o script para execução remota via WinRM.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos de qualquer servidor (WinRM Client) que será o repositório de script e log. Esta sintaxe remove arquivos com extensão PDF, DOCX e XML sem modificação a 30 dias do diretório C:\Arquivados\User1 e seus sub-diretórios no servidor remoto (WinRM Server) nomeado FileServer1. Utiliza a conta domínio\usuario1 com senha pass1.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml -CredDomainUser dominio\usuario1 -CredPass pass1 -Server FileServer1

    Este exemplo pode ser executado da console do Windows PowerShell. Executa a mesma ação do exemplo anterior.
    PS > C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml -CredDomainUser dominio\usuario1 -CredPass pass1 -Server FileServer1

    Este exemplo pode ser executado da console do Windows PowerShell. Esta sintaxe remove qualquer arquivo criado a mais de 90 dias do diretório C:\Arquivados\User1 e seus sub-diretórios e remove sub-diretórios vazios no servidor remoto (WinRM Server) nomeado FileServer1. Utiliza a conta dominio\usuario1 com senha pass1. Um arquivo de log é gravado no caminho de rede \\ServerLog\Purga\Arquivados com o nome FileServer1-C-Arquivados-User1-Monday.log, considerando que o script foi executado em uma segunda-feira.
    PS > C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog C -Days 90 -Extension * -PathDirLog \\ServerLog\Purga\Arquivados -DelNullDir -CredDomainUser dominio\usuario1 -CredPass pass1 -Server FileServer1
------------------------------------------------------------------------
#>

 




Param(
    [ValidateNotNullOrEmpty()]
    [string]$PathDirLog = "",

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$PathDirPurga,
	
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1,1)]
    [ValidateSet("C","M","R")]
    [string]$AttributeFileLog,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(1,10000)]
    [int]$Days,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1,5)]
    [String[]]$Extension,

    [Parameter()]
    [Switch]$DelNullDir,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CredDomainUser,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CredPass,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$Server
)




#--------------- CredSSP - Usuario e senha ------------------------------
$MyPass = ConvertTo-SecureString -String $CredPass -AsPlainText -Force
$Pass = ConvertTo-SecureString -String $MyPass
$PassPort = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $CredDomainUser, $Pass
#---------------------------------------------------



Invoke-Command -ComputerName $Server -Authentication credssp -Credential $PassPort -ScriptBlock {

    # ----------------------------- Define parametros para Bloco -----------------------------
    $PathDirLogBlock = $args[0]
    $PathDirPurgaBlock = $args[1]
    $AttributeFileLogBlock = $args[2]
    $DaysBlock = $args[3]
    $ExtensionBlock = $args[4]
    $DelNullDirBlock = $args[5]
    $ServerBlock = $args[6]
    # -----------------------------------------------------------------------------------------

    Function WriteLog ([string]$LogValue,[Switch]$FirtLine)
    {
        If ($PathDirLogBlock.Length -gt 1)
        {
            If ($Global:FileLog.Length -eq 0)
            {
                # ----------------------------- Define nome do Log -----------------------------
                $FileLogName = "$ServerBlock-" + $PathDirPurgaBlock.Replace("\","-").Replace(":","") + "-" + (Get-Date).DayOfWeek + ".log"
                If ($PathDirLogBlock.Substring($PathDirLogBlock.Length -1,1) -eq "\")
                {
                    New-Variable -Name FileLog -Scope Global -Value ($PathDirLogBlock + $FileLogName)
                }
                Else
                {
                    New-Variable -Name FileLog -Scope Global -Value ($PathDirLogBlock + "\$FileLogName")
                }
            }

            If ($FirtLine)
            {
                Set-Content -Path $Global:FileLog -Value ("Inicio: " + [string](Get-Date -Format F) + "`r`n") -Force
            }
            Else
            {
                Add-Content -LiteralPath $Global:FileLog -Value ($LogValue) -Force
            }
        }
    }


    Function RemoveObjectFSO([string]$ObjectFSO, [string]$ObjectDateProp, [string]$ObjectDateValue)
    {
        Remove-Item -LiteralPath $ObjectFSO -Force
        If (!(Test-Path $ObjectFSO))
        {
            WriteLog -LogValue ([string](Get-Date -Format G) + " - Removido:  $ObjectFSO   $ObjectDateProp  $ObjectDateValue")
        }
    }




    # ----------------------------- Inicia Log -----------------------------
    WriteLog -FirtLine


    # ----------------------------- Define string de extensões -----------------------------
    If ($ExtensionBlock.Count -eq 1 -and $ExtensionBlock[0] -eq "*")
    {
        $FileExt = "*"
    }
    Else
    {
        ForEach ($ExtensionLine in $ExtensionBlock)
        {
            If ($ExtensionLine -ne "*")
            {
                $FileExtTemp += "*." + $ExtensionLine + ","
            }
        }
        $FileExtTemp = $FileExtTemp.Substring(0,$FileExtTemp.Length - 1)
        $FileExt = $FileExtTemp.Split(",")
    }


    # ----------------------------- Loga parametros -----------------------------
    WriteLog -LogValue ([string](Get-Date -Format G) + " - Parametros:`r`n" +
    "Server: " + $ServerBlock + "`r`n" + 
    "PathDirLog: " +  $PathDirLogBlock + "`r`n" + 
    "PathDirPurga: " +  $PathDirPurgaBlock + "`r`n" + 
    "AttributeFileLog: " +  $AttributeFileLogBlock + "`r`n" + 
    "Days: " +  $DaysBlock + "`r`n" + 
    "Extension: " + $FileExt + "`r`n" +
    "DelNullDir: " +  $DelNullDirBlock + "`r`n")


    # ----------------------------- Data de purga -----------------------------
    $PurgaDate = (Get-Date).AddDays(($DaysBlock * -1))
    WriteLog -LogValue ([string](Get-Date -Format G) + " - Data para purga: " + [string](Get-Date $PurgaDate -Format G) + "`r`n")



    # ----------------------------- Define Attributo de data -----------------------------
    # C -> Criação, M -> Modificação, R -> Leitura
    Switch ($AttributeFileLogBlock)
    { 
        "C" {$FileDateProp = "CreationTime"} 
        "M" {$FileDateProp = "LastWriteTime"} 
        "R" {$FileDateProp = "LastAccessTime"}
    }



    # ----------------------------- Excluir arquivo, logando -----------------------------
    $Files = @(Get-ChildItem -Path $PathDirPurgaBlock -Recurse -Include $FileExt -Force -File)
    ForEach ($FilesLine in $Files)
    {
        If ($FilesLine.$FileDateProp -lt $PurgaDate)
        {
            RemoveObjectFSO -ObjectFSO $FilesLine.FullName -ObjectDateProp $FileDateProp -ObjectDateValue (Get-Date $FilesLine.$FileDateProp -Format G)
        }
    }



    # ----------------------------- Exluir diretorios Vazios -----------------------------
    If ($DelNullDirBlock)
    {
        $Dirs = @(Get-ChildItem -Path $PathDirPurgaBlock -Recurse -Force -Directory)
        ForEach ($DirsLine in $Dirs)
        {
            $DirEmpty = @(Get-ChildItem -Path $DirsLine.FullName -Recurse -Force)
            If ($DirEmpty.Count -eq 0)
            {
                RemoveObjectFSO -ObjectFSO $DirsLine.FullName
            }
        }
    }


    # ----------------------------- Finaliza script -----------------------------
    WriteLog -LogValue ("`r`nFim: " + [string](Get-Date -Format F))

    If ($Global:FileLog.Length -gt 1)
    {
        Remove-Variable -Name FileLog -Force -Scope Global
    }

} -ArgumentList $PathDirLog, $PathDirPurga, $AttributeFileLog, $Days, $Extension, $DelNullDir, $Server

#---- Log de Debug Execução


Set-Content -Path (($MyInvocation.MyCommand.Path).SubString(0,($MyInvocation.MyCommand.Path).LastIndexOfAny("\")) + "\Error-$Server-" + $PathDirPurga.Replace("\","-").Replace(":","") + ".log") -Value ($Error.InvocationInfo + "`r`n" + $Error.Exception ) -Force

