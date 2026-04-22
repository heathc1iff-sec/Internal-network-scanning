@echo off
setlocal
echo [*] Initializing Universal Scanner...

:: 1. 穷举寻找系统绝对可写的目录 (防无配置 Shell)
set "WDIR="
for %%d in ("%TEMP%" "%PUBLIC%" "C:\Users\Public" "C:\ProgramData" "C:\Windows\Temp" ".") do (
    echo. > "%%~d\chk.tmp" 2>nul
    if exist "%%~d\chk.tmp" (
        set "WDIR=%%~d"
        del "%%~d\chk.tmp" 2>nul
        goto :dir_found
    )
)
:dir_found
if "%WDIR%"=="" (
    echo [!] Fatal: No writable directory found.
    exit /b
)

:: 2. 穷举寻找全版本 C# 编译器 (优先 .NET 4，降级到 .NET 2)
set "CSC="
for %%p in (
    "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    "%WINDIR%\Microsoft.NET\Framework64\v2.0.50727\csc.exe"
    "%WINDIR%\Microsoft.NET\Framework\v2.0.50727\csc.exe"
) do (
    if exist "%%~p" (
        set "CSC=%%~p"
        goto :csc_found
    )
)
:csc_found
if "%CSC%"=="" (
    echo [!] Fatal: C# Compiler not found.
    exit /b
)

:: 3. 默认扫描127.0.0.1，支持 port_scan.bat [IP] [起始端口-结束端口]
set "SRC=%WDIR%\s.cs"
set "EXE=%WDIR%\s.exe"

echo using System; > "%SRC%"
echo using System.Net.Sockets; >> "%SRC%"
echo using System.Threading; >> "%SRC%"
echo using System.Collections.Generic; >> "%SRC%"
echo class P { >> "%SRC%"
echo     static int pnd = 0; >> "%SRC%"
echo     static Dictionary^<int,string^> svc = new Dictionary^<int,string^>() >> "%SRC%"
echo         {{21,"FTP"},{22,"SSH"},{23,"Telnet"},{25,"SMTP"},{53,"DNS"},{80,"HTTP"},{110,"POP3"},{135,"MSRPC"},{139,"NetBIOS"},{143,"IMAP"},{389,"LDAP"},{443,"HTTPS"},{445,"SMB"},{1433,"MSSQL"},{3306,"MySQL"},{3389,"RDP"},{5432,"PgSQL"},{5985,"WinRM"},{6379,"Redis"},{8080,"HTTP-Alt"},{8443,"HTTPS-Alt"}}; >> "%SRC%"
echo     static void Main(string[] args) { >> "%SRC%"
echo         string ip = args.Length ^> 0 ? args[0] : "127.0.0.1"; >> "%SRC%"
echo         int ps = 1, pe = 10000; >> "%SRC%"
echo         if(args.Length ^> 1) { string[] r = args[1].Split('-'); ps = int.Parse(r[0]); pe = int.Parse(r[1]); } >> "%SRC%"
echo         ThreadPool.SetMinThreads(500, 500); >> "%SRC%"
echo         Console.WriteLine("[*] Target: " + ip + " Ports: " + ps + "-" + pe + " ^| .NET " + Environment.Version); >> "%SRC%"
echo         for(int i=ps; i^<=pe; i++) { >> "%SRC%"
echo             Interlocked.Increment(ref pnd); >> "%SRC%"
echo             ThreadPool.QueueUserWorkItem(new WaitCallback(Scan), new object[]{ip, i}); >> "%SRC%"
echo         } >> "%SRC%"
echo         while(pnd ^> 0) Thread.Sleep(10); >> "%SRC%"
echo         Console.WriteLine("[*] Scan Complete."); >> "%SRC%"
echo     } >> "%SRC%"
echo     static void Scan(object o) { >> "%SRC%"
echo         try { >> "%SRC%"
echo             object[] arr = (object[])o; >> "%SRC%"
echo             string targetIp = (string)arr[0]; >> "%SRC%"
echo             int port = (int)arr[1]; >> "%SRC%"
echo             using(TcpClient c = new TcpClient()) { >> "%SRC%"
echo                 IAsyncResult iar = c.BeginConnect(targetIp, port, null, null); >> "%SRC%"
echo                 if(iar.AsyncWaitHandle.WaitOne(100, false)) { >> "%SRC%"
echo                     c.EndConnect(iar); >> "%SRC%"
echo                     string s = svc.ContainsKey(port) ? " (" + svc[port] + ")" : ""; >> "%SRC%"
echo                     Console.WriteLine("[+] Port Open: " + port + s); >> "%SRC%"
echo                 } >> "%SRC%"
echo             } >> "%SRC%"
echo         } catch {} finally { Interlocked.Decrement(ref pnd); } >> "%SRC%"
echo     } >> "%SRC%"
echo } >> "%SRC%"

:: 4. 实时静默编译并执行
"%CSC%" /nologo /out:"%EXE%" "%SRC%" >nul 2>&1

if exist "%EXE%" (
    "%EXE%" %1 %2
) else (
    echo [!] Compilation failed.
)

:: 5. 阅后即焚，不留痕迹
del "%SRC%" 2>nul
del "%EXE%" 2>nul
endlocal