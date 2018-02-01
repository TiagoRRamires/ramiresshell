
<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script excluir arquivos a partir de um valor especifico de dias passados, considerando data de criação, leitura ou modificação. Pode definir as extensões de arquivos que se deseja excluir.
    O script exclui arquivos que satisfaçam os parâmetros -Days e -Extension no diretório e subdiretórios definidos no parâmetro -PathDirPurga
    Útil para excluir arquivos antigos não necessários, mantendo computadores com espaço disponível em disco como por exemplo arquivos de logs de aplicações ou serviços.
    Registra em log o caminho de todos os arquivos excluídos.


Considerações:
O usuário que executar este script deve possuir as seguintes permissões NTFS:
    Permissão de Modificação na pasta onde o script será armazenado para criação dos arquivos de log de debug.
    Permissão de Exclusão no diretório e subdiretórios definido no parâmetro -PathDirPurga.
    Permissão de Modificação no diretório definido no parâmetro -PathDirLog


Descrição dos Parâmetros:
-PathDirLog
    Campo Opcional. Tipo String. Informe o caminho do diretório onde deve ser armazenado o arquivo de log que registra o nome dos arquivos excluídos por este script.
-PathDirPurga
    Campo Obrigatório. Tipo String. Informe o caminho do diretório onde deve ser purgado os arquivos. Arquivos em subdiretórios também serão purgados.
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
    Campo Opcional. Tipo Switch. Exclui subdiretórios vazios do diretório informado no parâmetro PathDirPurga.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Esta sintaxe remove arquivos com extensão PDF, DOCX e XML sem modificação a 30 dias do diretório C:\Arquivados\User1 e seus subdiretórios.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml

    Este exemplo pode ser executado da console do Windows PowerShell. Executa a mesma ação do exemplo anterior.
    PS > C:\Script1\PurgaFiles.ps1 -PathDirPurga C:\Arquivados\User1 -AttributeFileLog M -Days 30 -Extension pdf, docx, xml

    Este exemplo pode ser executado da console do Windows PowerShell. Esta sintaxe remove qualquer arquivo criado a mais de 90 dias do diretório C:\Arquivados\User1 e seus subdiretórios e remove subdiretórios vazios. Um arquivo de log é gravado no caminho de rede \\ServerLog\Purga\Arquivados com o nome C-Arquivados-User1-Monday.log, considerando que o script foi executado em uma segunda-feira.
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


# ----------------------------- Define string de extensões -----------------------------
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


#---- Log de Debug Execução
Set-Content -Path (($MyInvocation.MyCommand.Path).SubString(0,($MyInvocation.MyCommand.Path).LastIndexOfAny("\")) + "\Error-" + $PathDirPurga.Replace("\","-").Replace(":","") + ".log") -Value ($Error) -Force

