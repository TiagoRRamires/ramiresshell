
<#
------------------ Sobre ------------------------------------------------------
Conhe�a nosso projeto em www.ramiresshell.com.br

Descri��o:
    Este script l� um arquivo de texto contendo nome de arquivos. O arquivo de texto deve ter o seguinte formato de informa��o:
    --------------------------------------------------
    -   Teste.txt                                    -
    -   Photo.jpg                                    -
    -   Planilha.xlsx                                -
    --------------------------------------------------
    Para cada linha do arquivo de texto procura o arquivo em todos os subdiretorios a partir do diret�rio especificado no par�metro -DirSource
    Copia os arquivos encontrados para o diret�rio de destino especificado no par�metro -DirDestination
    Caso o arquivo esteja em um subdiretorio, a estrutura de sub-diret�rios � criada antes da copia no caminho de destino.

Considera��es:
    O usu�rio executor deve possuir permiss�o NTFS de leitura nos arquivos de origem a serem copiados.
    O usu�rio executor deve possuir permiss�o NTFS de modifica��o no caminho de destino a receber as copias.

Descri��o dos Par�metros:
    -FileContent
        Campo Obrigat�rio. Tipo String. Informe o nome do arquivo que contem o nome dos arquivos que devem ser copiados. Aceita caminhos UNC e local.
    -DirSource
        Campo Obrigat�rio. Tipo String. Informe o nome do diret�rio de origem que contem arquivos a serem copiados. Aceita caminhos UNC e local.
    -DirDestination
        Campo Obrigat�rio. Tipo String. Informe o nome do diret�rio de destino. Aceita caminhos UNC e local.

Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Copia arquivos informados no arquivo C:\RS\ArquivosParaCopia.txt armazenados na pasta C:\RS\Documentos para o camminho de rede \\FileServer\Archieve
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file RoboCopyFromList.ps1 -FileSource C:\RS\ArquivosParaCopia.txt -DirSource C:\RS\Documentos -DirDestination \\FileServer\Archieve
    Este exemplo pode ser executado da console do Windows PowerShell. Copia arquivos informados no arquivo C:\RS\ArquivosParaCopia.txt armazenados na pasta C:\RS\Documentos para o caminho de rede \\FileServer\Archieve
    PS > C:\RS\RoboCopyFromList.ps1 -FileSource C:\RS\ArquivosParaCopia.txt -DirSource C:\RS\Documentos -DirDestination \\FileServer\Archieve 
------------------------------------------------------------------------
#>




Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$FileContent,
	
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DirSource,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DirDestination
)


$FileNotCopy = 0
$FileCopied = 0



$FileContent = Get-Content -LiteralPath $FileContent

$FileContent | ForEach-Object {
    $FindFileName = $_
    $FindFile = @(Get-ChildItem -LiteralPath $DirSource -Force -Recurse -File | Where-Object -Property Name -EQ -Value $FindFileName)
    If ($FindFile.Count -eq 0)
    {
        Write-Host "N�o encontrado arquivo " $FindFileName -BackgroundColor DarkRed
        $FileNotCopy += 1
    }
    ForEach ($FindFileLine in $FindFile)
    {
        $FileDestination = $FindFileLine.FullName.Replace($DirSource, $DirDestination)
        #Cria pasta caso n�o exista
        $LastBar = 3
        While($LastBar -gt 0)
        {
            $LastBar = $FileDestination.IndexOfAny("\" ,$LastBar + 1)
            If ($LastBar -gt 3)
            {
                $ValidaPath = $FileDestination.Substring(0, $LastBar)
                if (-not (Test-Path -LiteralPath $ValidaPath))
                {
                    New-Item -Path $ValidaPath -ItemType Directory -Force
                }
            }
        }


        try
        {
            Copy-Item -LiteralPath $FindFileLine.FullName -Destination $FileDestination -Force
            $FileCopied += 1
        }
        catch
        {
            Write-Host "Erro para copiar arquivo: " $FindFileLine.FullName "  destino: " $FileDestination -BackgroundColor DarkYellow
            $FileNotCopy += 1
        }
    }
}


#--------- Sumario -----------------
[string]$Block=[char]9608
$BlockLine = $Block * 100
Write-Host ("`r`n$BlockLine`r`n$Block")
Write-Host ($Block + (" " * 40) + "Sum�rio`r`n$Block")
Write-Host ("$Block    Arquivos   -   Copiados: $FileCopied     N�o Copiado: $FileNotCopy")
Write-Host ("$Block`r`n$BlockLine")
#-----------------------------------
