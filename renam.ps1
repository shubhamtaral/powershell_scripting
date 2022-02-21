Install-module "PSExcel"  

$currentDir = "D:\Renaming"  
$fileFolder = $currentDir + "\OneDrive_1_12-20-2021"
$ExcelFile = $currentDir + "\Procurement Contracts_File Naming Convention _Combine Sheet_23th Dec.xlsx"  
$Folder = $currentDir + "\RenamedFilesBackup"
$count=0


if (Test-Path -Path $Folder) {
    "Path exists!"
} else {
    New-Item -Path $currentDir -Name "RenamedFilesBackup" -ItemType "directory"
}

Function Search-Excel($Source, $SearchText) {  
    $objExcel = New-Excel -Path $Source  
    $WorkBook = $objExcel | Get-Workbook  
    Foreach($Sheet in $WorkBook.Worksheets) {  
        $Dimension = $Sheet.Dimension  
        $RowStart = 2  
        $ColumnStart = 1  
        $RowEnd = $Dimension.End.Row  
        $ColumnEnd = $Dimension.End.Column  
        for ($Row = $RowStart; $Row -le $RowEnd; $Row++) {  
            $Value = $Sheet.Cells.Item($Row, $ColumnStart).Value  
            if ($Value) {
                if ($Value.trim() -eq $searchText) {  
                    if ($Sheet.Cells.Item($Row, $ColumnStart+1).Value){
                        $renameTo = $Sheet.Cells.Item($Row, $ColumnStart+1).Value   
                    }else{
                        Write-Host "Update the steet for $searchText @ $Row"
                    }
                    return ($true, $renameTo)
                }
            }
        }
        $objExcel.Dispose()  
    }
}

$names = Get-ChildItem $fileFolder
foreach ($name in $names){
    $ifExsist , $renameTo = (Search-Excel -Source $ExcelFile -SearchText $name)
    if ($ifExsist){
        $path = $fileFolder + "\" + $name
        $dest = $Folder
        $newFile = $fileFolder  + "\" + $renameTo
        if (Test-Path -Path $newFile){
            Write-host "Moving" $renameTo "===>" $dest "as filename is already exist"
            Move-Item -Path $path -Destination $dest -force
        }
        else{
            Write-host "Renaming" $name "===>" $renameTo
            Copy-Item -Path $path -Destination $dest -force
            Rename-Item -Path $path -NewName $renameTo            
        }

        $count++
    }
}
Write-Host
Write-Host "----------------------------"
Write-Host "Total Files renamed: $count! For renamed files backup check $dest!"
Write-Host "----------------------------"

