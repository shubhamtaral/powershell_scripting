Install-module "PSExcel"  

$fileFolder = "" ###Path to the pdf files
$ExcelFile = "2022.xlsx"  ###Path of Excel File 
$Folder = ""
$count=0


if (Test-Path -Path $Folder) {
    "Path exists!"
} else {
    New-Item -Path $fileFolder -Name "RenamedFilesBackup" -ItemType "directory"
}

Function Search-Excel($Source, $SearchText) {  
    #Write-host "Now looking for: " $SearchText "In function"
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
                        $renameTo = $Sheet.Cells.Item($Row, $ColumnStart+1).Value + ".pdf"
                        Write-Host $Value " ==> " $renameTo
                        return ($true, $renameTo)
                    }else{
                        Write-Host "Update the steet for $searchText @ $Row"
                        return ($false, $searchText)
                    }
                    return ($false, $searchText)
                }
            }
        }
        $objExcel.Dispose()  
    }
}

Function UpodateRow(){

}


$names = Get-ChildItem $fileFolder
foreach ($name in $names){
    $ifExsist , $renameTo = (Search-Excel -Source $ExcelFile -SearchText $name)
    Write-host "Now looking for: " $name "Exsist?: "$ifExsist
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


