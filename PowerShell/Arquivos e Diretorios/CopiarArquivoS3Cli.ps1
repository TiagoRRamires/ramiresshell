
<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br
Descrição:
    Este script copia uma pasta com arquivos e sub-diretórios ou um arquivo especifico para um bucket no S3 da AWS, validando o status final da copia.
    É possível também excluir o diretório de destino no bucket antes de iniciar uma nova copia.
    O script trabalha em modo interativo, O diretório local, o bucket remoto, chave de acesso, chave secreta de acesso e região do bucket são solicitadas durante a execução.
    O resultado é exibido na console do PowerShell não sendo gerado arquivo de log.
    Útil para realizar copias seguras de um diretório para um bucket S3.
Considerações:
    O computador que executar o script deve ter instalado o AWS CLI (Command Line Interface).
    O usuário executor deve possuir permissão NTFS de leitura nos arquivos de origem a serem copiados.
    A chave de acesso do AWS utilizada deve ter permissão de modificação no diretório do bucket de destino do S3.
    Por ser interativo, não é possível executar o script a partir de um scheduler do Windows.
------------------------------------------------------------------------
#>



$SourceDir = Read-Host -Prompt "Informe o diretorio de origem. Obs.: Não use ""\"" no final do caminho"
$S3Path = Read-Host -Prompt "Informe o bucket de destino no S3. Obs.: Use ""/"" no final do caminho. Ex.: s3://rs.script.rep/teste1/Arquivos/"


If (Test-Path -Path $SourceDir)
{
    #Configura CLI com chave de acesso
    $AWSKey = Read-Host -Prompt "Informe a chave de acesso ao AWS S3. Para manter a configuração do perfil atual apenas pressione ENTER"
    If ($AWSKey.Length -ne 0) {aws configure set aws_access_key_id $AWSKey.ToString()}
    
    $AWSscretKey = Read-Host -Prompt "Informe a chave de acesso secreta ao AWS S3. Para manter a configuração do perfil atual apenas pressione ENTER"
    If ($AWSscretKey.Length -ne 0) {aws configure set aws_secret_access_key $AWSscretKey.ToString()}
    
    $AWSRegion = Read-Host -Prompt "Informe a região do Bucket AWS S3. Para manter a configuração do perfil atual apenas pressione ENTER"
    If ($AWSRegion.Length -ne 0) {aws configure set default.region $AWSRegion.ToString()}
    

    #Remove armazenamento atual do bucket S3
    Do
    {
        $RemoveAnswear = Read-Host -Prompt "Deseja limpar destino antes da copia? S (Sim)  N (Não)"
    } While ($RemoveAnswear -ne "S" -and $RemoveAnswear -ne "N")
    If ($RemoveAnswear -eq "S")
    {
        $awsExecrm = aws s3 rm $S3Path --recursive 2>&1
        $awsExecrm = [string]$awsExecrm
        Write-Host $awsExecrm -BackgroundColor DarkRed -ForegroundColor White
    }

    
    #Upload para bucket S3
    $awsExec = aws s3 cp $SourceDir $S3Path --recursive 2>&1
    $awsExec = [string]$awsExec
    Write-Host $awsExec -ForegroundColor White -BackgroundColor DarkCyan
    
    
    #compara tamanho das pastas
    $awsExec = aws s3 ls $S3Path --recursive --summarize | find "Total Size:"  2>&1
    $awsExec = [string]$awsExec
    if ($awsExec.length -gt 1)
    {
        $awsExecTable = $awsExec.Split(":",[System.StringSplitOptions]::RemoveEmptyEntries)
        $SourceDirLength = Get-ChildItem -LiteralPath "$SourceDir" -recurse | Measure-Object -Sum Length
        if ([string]$SourceDirLength.sum -eq [string]$awsExecTable[1].trim())
        {
            Write-Host ("Upload concluido com SUCESSO`r`n" + "Backup Local: " + [string]$SourceDirLength.sum + "`r`n" + "Backup S3: " + [string]$awsExecTable[1].trim()) -ForegroundColor Green
        }
        Else
        {
            Write-Host ("Upload com ERRO`r`n" + "Backup Local: " + [string]$SourceDirLength.sum + "`r`n" + "Backup S3: " + [string]$awsExecTable[1].trim()) -BackgroundColor Yellow -ForegroundColor DarkBlue
        }
    }
    else
    {
        Write-Host ("S3 Upload não executado, Tamanho igual a ZERO") -ForegroundColor Yellow
    }

}
else
{
    Write-Host ("Pasta para upload não encontrada: $SourceDir") -ForegroundColor Red
}

Write-Host "Script Finalizado"
