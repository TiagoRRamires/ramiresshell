
<#
------------------ Sobre ------------------------------------------------------
Conhe�a nosso projeto em www.ramiresshell.com.br

Descri��o:
    Este script excluir arquivos a partir de um valor especifico de dias passados, considerando data de cria��o, leitura ou modifica��o. Pode definir as extens�es de arquivos que se deseja excluir.
    O script exclui arquivos que satisfa�am os par�metros -Days e -Extension no diret�rio e subdiret�rios definidos no par�metro -PathDirPurga
    �til para excluir arquivos antigos n�o necess�rios, mantendo computadores com espa�o dispon�vel em disco como por exemplo arquivos de logs de aplica��es ou servi�os.
    Registra em log o caminho de todos os arquivos exclu�dos.


Considera��es:
O usu�rio que executar este script deve possuir as seguintes permiss�es NTFS:
    Permiss�o de Modifica��o na pasta onde o script ser� armazenado para cria��o dos arquivos de log de debug.
    Permiss�o de Exclus�o no diret�rio e subdiret�rios definido no par�metro -PathDirPurga.
    Permiss�o de Modifica��o no diret�rio definido no par�metro -PathDirLog


Descri��o dos Par�metros:
-PathDirLog
    Campo Opcional. Tipo String. Informe o caminho do diret�rio onde deve ser armazenado o arquivo de log que registra o nome dos arquivos exclu�dos por este script.
-PathDirPurga
    Campo Obrigat�rio. Tipo String. Informe o caminho do diret�rio onde deve ser purgado os arquivos. Arquivos em subdiret�rios tamb�m ser�o purgados.
-AttributeFileLog
    Campo Obrigat�rio. Tipo String. Informe o atributo de data do arquivo para purga. Aceita os valores:
        C => Exclui baseado na data de cria��o do arquivo.
        M => Exclui baseado na data da �ltima modifica��o do arquivo.
        R => Exclui baseado na data de �ltimo acesso de leitura ao arquivo.
-Days
    Campo Obrigat�rio. Tipo Integer. Informe o n�mero de dias passados para exclus�o do arquivo. Aceita de 1 dia at� 10000 dias.
-Extension
    Campo Obrigat�rio. Tipo Array de String. Informe as extens�es de arquivos que se deseja excluir. Use asteriscos (*) exclui todos os tipos de arquivos. Cada extens�o informada deve ter de 1 a 5 caracteres.
-DelNullDir
    Campo Opcional. Tipo Switch. Exclui subdiret�rios vazios do diret�rio informado no par�metro PathDirPurga.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Esta sintaxe remove arquivos com extens�o PDF, DOCX e XML sem modifica��o a 30 dias do diret�rio C:\Arquivados\User1 e seus subdiret�rios.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml

    Este exemplo pode ser executado da console do Windows PowerShell. Executa a mesma a��o do exemplo anterior.
    PS > C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml

    Este exemplo pode ser executado da console do Windows PowerShell. Esta sintaxe remove qualquer arquivo criado a mais de 90 dias do diret�rio C:\Arquivados\User1 e seus subdiret�rios e remove subdiret�rios vazios. Um arquivo de log � gravado no caminho de rede \\ServerLog\Purga\Arquivados com o nome C-Arquivados-User1-Monday.log, considerando que o script foi executado em uma segunda-feira.
    PS > C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog C -Days 90 -Extension * -PathDirLog \\ServerLog\Purga\Arquivados -DelNullDir 
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
    [Switch]$DelNullDir
)





Function WriteLog ([string]$LogValue,[Switch]$FirtLine)
{
    If ($PathDirLog.Length -gt 1)
    {
        If ($Global:FileLog.Length -eq 0)
        {
            # ----------------------------- Define nome do Log -----------------------------
            $FileLogName = $PathDirPurga.Replace("\","-").Replace(":","") + "-" + (Get-Date).DayOfWeek + ".log"
            If ($PathDirLog.Substring($PathDirLog.Length -1,1) -eq "\")
            {
                New-Variable -Name FileLog -Scope Global -Value "$PathDirLog$FileLogName"
            }
            Else
            {
                New-Variable -Name FileLog -Scope Global -Value "$PathDirLog\$FileLogName"
            }
        }

        If ($FirtLine)
        {
            Set-Content -Path $Global:FileLog -Value ("Inicio: " + [string](Get-Date -Format F) + "`r`n") -Force
        }
        Else
        {
            Add-Content -LiteralPath $Global:FileLog -Value $LogValue -Force
        }
    }
}



Function RemoveObjectFSO([string]$ObjectFSO, [string]$ObjectDateProp, [string]$ObjectDateValue)
{
    Remove-Item -LiteralPath $ObjectFSO -Force
    If (-not(Test-Path $ObjectFSO))
    {
        WriteLog -LogValue ([string](Get-Date -Format G) + " - Removido:  $ObjectFSO   $ObjectDateProp  $ObjectDateValue")
    }
}



# ----------------------------- Inicia Log -----------------------------
WriteLog -FirtLine


# ----------------------------- Define string de extens�es -----------------------------
If ($Extension.Count -eq 1 -and $Extension[0] -eq "*")
{
    $FileExt = "*"
}
Else
{
    ForEach ($ExtensionLine in $Extension)
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
"PathDirLog: $PathDirLog`r`n" + 
"PathDirPurga: $PathDirPurga`r`n" + 
"AttributeFileLog: $AttributeFileLog`r`n" + 
"Days: $Days`r`n" + 
"Extension: $FileExt`r`n" +
"DelNullDir: $DelNullDir`r`n")


# ----------------------------- Data de purga -----------------------------
$PurgaDate = (Get-Date).AddDays(($Days * -1))
WriteLog -LogValue ([string](Get-Date -Format G) + " - Data para purga: " + [string](Get-Date $PurgaDate -Format G) + "`r`n")



# ----------------------------- Define Attributo de data -----------------------------
Switch ($AttributeFileLog)
{
    "C" {$FileDateProp = "CreationTime"} 
    "M" {$FileDateProp = "LastWriteTime"} 
    "R" {$FileDateProp = "LastAccessTime"}
}


# ----------------------------- Excluir arquivo, logando -----------------------------
$Files = @(Get-ChildItem -Path $PathDirPurga -Recurse -Include $FileExt -Force -File)
ForEach ($FilesLine in $Files)
{
    If ($FilesLine.$FileDateProp -lt $PurgaDate)
    {
        RemoveObjectFSO -ObjectFSO $FilesLine.FullName -ObjectDateProp $FileDateProp -ObjectDateValue (Get-Date $FilesLine.$FileDateProp -Format G)
    }
}



# ----------------------------- Exluir diretorios Vazios -----------------------------
If ($DelNullDir)
{
    $Dirs = @(Get-ChildItem -Path $PathDirPurga -Recurse -Force -Directory)
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


#---- Log de Debug Execu��o
Set-Content -Path (($MyInvocation.MyCommand.Path).SubString(0,($MyInvocation.MyCommand.Path).LastIndexOfAny("\")) + "\Error-" + $PathDirPurga.Replace("\","-").Replace(":","") + ".log") -Value ($Error) -Force

