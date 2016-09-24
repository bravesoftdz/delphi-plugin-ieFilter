unit _ieFilter;

interface
uses
  Windows, Classes, ActiveX, ShlObj, ComServ, ComObj,
  Urlmon, registry, dialogs, axctrls, SysUtils, Forms,
  consoleoutput,
  //csintf,
  SyncObjs;

var cs : TCriticalSection;
const
  MimeFilterType = 'text/html';
  MimeFilterName = 'mkrz ieFilter';
  CLSID_MimeFilter: TGUID = '{2FC29FB7-2BD4-450B-851E-89C56C86A635}';
  // kk made this GUID with Ctrl-Shift-G

type
  TMimeFilterFactory = class(TComObjectFactory)
  private
    procedure AddKeys;
    procedure RemoveKeys;
  public
    procedure UpdateRegistry(Register: Boolean); override;
  end;

type
  TMimeFilter = class(TComObject, IInternetProtocol, IInternetProtocolSink)
  private
    CacheFileName: string;
    Url: PWideChar;
    DataStream: IStream;
    UrlMonProtocol: IInternetProtocol;
    UrlMonProtocolSink: IInternetProtocolSink;
    Written, TotalSize: Integer;
  protected
// IInternetProtocolSink Methods
    function Switch(const ProtocolData: TProtocolData): HResult; stdcall;
    function ReportProgress(ulStatusCode: ULONG; szStatusText: LPCWSTR): HResult; stdcall;
    function ReportData(grfBSCF: DWORD; ulProgress, ulProgressMax: ULONG): HResult; stdcall;
    function ReportResult(hrResult: HResult; dwError: DWORD; szResult: LPCWSTR): HResult; stdcall;
// IInternetProtocol Methods
    function Start(szUrl: PWideChar; OIProtSink: IInternetProtocolSink;
      OIBindInfo: IInternetBindInfo; grfPI, dwReserved: DWORD): HResult; stdcall;
    function Continue(const ProtocolData: TProtocolData): HResult; stdcall;
    function Abort(hrReason: HResult; dwOptions: DWORD): HResult; stdcall;
    function Terminate(dwOptions: DWORD): HResult; stdcall;
    function Suspend: HResult; stdcall;
    function Resume: HResult; stdcall;
    function Read(pv: Pointer; cb: ULONG; out cbRead: ULONG): HResult; stdcall;
    function Seek(dlibMove: LARGE_INTEGER; dwOrigin: DWORD;
      out libNewPosition: ULARGE_INTEGER): HResult; stdcall;
    function LockRequest(dwOptions: DWORD): HResult; stdcall;
    function UnlockRequest: HResult; stdcall;
  end;


implementation


uses wininet;



function TMimeFilter.Start(szUrl: PWideChar; OIProtSink: IInternetProtocolSink;
  OIBindInfo: IInternetBindInfo; grfPI, dwReserved: DWORD): HResult;
var
  Fetched: Cardinal;
begin
//  codesite.EnterMethod('TMimeFilter.Start');
  CacheFileName := '';
  TotalSize := 0;
  Written := 0;
  UrlMonProtocol := OIProtSink as IInternetProtocol;
  UrlMonProtocolSink := OIProtSink as IInternetProtocolSink;
  OIBindinfo.GetBindString(BINDSTRING_URL, @Url, 1, Fetched);
  Result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Start');
end;


function TMimeFilter.ReportProgress(ulStatusCode: ULONG;
  szStatusText: LPCWSTR): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.ReportProgress');
  if ulStatusCode = BINDSTATUS_CACHEFILENAMEAVAILABLE then
    CacheFileName := SzStatusText;
  UrlMonProtocolSink.ReportProgress(ulStatusCode, szStatustext);
  Result := S_OK;
//  codesite.ExitMethod('TMimeFilter.ReportProgress');
end;



function TMimeFilter.ReportData(grfBSCF: DWORD; ulProgress,
  ulProgressMax: ULONG): HResult;
var
  TS: TStringStream;
  Dummy: Int64;
  hr: HResult;
  readTotal: ULONG;
  S: string;
  Fname: array[0..512] of Char;
  p: array[0..1000] of char;
begin
//  codesite.EnterMethod('TMimeFilter.ReportData');

  Ts := TStringStream.Create('');
  repeat
    hr := UrlMonProtocol.Read(@P, SizeOf(p), Readtotal);
    Ts.write(P, Readtotal);
  until (hr = S_FALSE) or (hr = INET_E_DOWNLOAD_FAILURE) or (hr = INET_E_DATA_NOT_AVAILABLE);

  if hr = S_FALSE then begin
//    codesite.send('Data Completely Downloaded');

    cs.acquire;
    TRY

    if CacheFilename = '' then begin
//      codesite.send('CacheFilename is blank');
      CreateUrlCacheEntry(@url, ts.Size, Pchar('htm'), FName, 0);
      TMemoryStream(ts).SaveToFile(Fname);
      StringToWideChar(StrPas(FName), @FName, SizeOf(FName));
      ReportProgress(BINDSTATUS_CACHEFILENAMEAVAILABLE, @FName);
    end;

///*  FILTER DATA HERE - something like:
//    S := StringReplace(Ts.DataString, 'Delphi', 'Borland Inprise', [rfReplaceAll, rfIgnoreCase]);

    try
//      codesite.send('D:\Bin\php\php.exe',' '+'ieFilter.php'+' "'+string(Url)+'" "'+CacheFileName+'"');
      S := GetDosOutput('D:\Bin\php\php.exe',' '+'ieFilter.php'+' "'+string(Url)+'" "'+CacheFileName+'"');
// TODO : PIPES!
//S:= Ts.DataString;
//      codesite.send('S',S);
    except
      on e:Exception do begin
//        codesite.send('Exception',e);
        S := e.Message;
      end;
    end;
    ts.Size := 0;
    ts.WriteString(S);
///************************************

////***** Debug only ******************
    ts.Seek(0, 0);
//    form1.HtmlMemo.Lines.LoadFromStream(TS);
///************************************

    TotalSize := Ts.Size;
    ts.Seek(0, 0);
    CreateStreamOnHGlobal(0, True, DataStream);
    TOlestream.Create(DataStream).CopyFrom(ts, ts.size);
    TS.Free;
    DataStream.Seek(0, STREAM_SEEK_SET, Dummy);
    UrlMonProtocolSink.ReportData(BSCF_FIRSTDATANOTIFICATION or BSCF_LASTDATANOTIFICATION or BSCF_DATAFULLYAVAILABLE, TotalSize, Totalsize);
    UrlMonProtocolSink.ReportResult(S_OK, S_OK, nil);

    FINALLY
      cs.Release;
    END;

  end else begin
//    codesite.send('Data Still Coming');
    Abort(hr, 0); //On Error: INET_E_DOWNLOAD_FAILURE or INET_E_DATA_NOT_AVAILABLE
  end;
  Result := S_OK;
//  codesite.ExitMethod('TMimeFilter.ReportData');
end;

function TMimeFilter.Read(pv: Pointer; cb: ULONG; out cbRead: ULONG): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Read');
  DataStream.Read(pv, cb, @cbRead);
  Inc(written, cbread);
  if (written = totalsize) then result := S_FALSE else Result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Read');
end;



function TMimeFilter.Continue(const ProtocolData: TProtocolData): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Continue');
  UrlMonProtocol.Continue(ProtocolData);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Continue');
end;

function TMimeFilter.Terminate(dwOptions: DWORD): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Terminate');
  UrlmonProtocol.Terminate(dwOptions);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Terminate');
end;

function TMimeFilter.Abort(hrReason: HResult; dwOptions: DWORD): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Abort');
  UrlMonProtocol.Abort(hrReason, dwOptions);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Abort');
end;

function TMimeFilter.LockRequest(dwOptions: DWORD): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.LockRequest');
  UrlMonProtocol.LockRequest(dwOptions);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.LockRequest');
end;

function TMimeFilter.UnlockRequest: HResult;
begin
//  codesite.EnterMethod('TMimeFilter.UnlockRequest');
  UrlMonProtocol.UnlockRequest;
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.UnlockRequest');
end;

function TMimeFilter.Seek(dlibMove: LARGE_INTEGER; dwOrigin: DWORD;
  out libNewPosition: ULARGE_INTEGER): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Seek');
  UrlMonProtocol.Seek(dlibMove, dwOrigin, libNewPosition);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Seek');
end;

function TMimeFilter.Suspend: HResult;
begin
//  codesite.ExitMethod('TMimeFilter.Suspend');
// Not implemented
  result := E_NOTIMPL;
//  codesite.ExitMethod('TMimeFilter.Suspend');
end;

function TMimeFilter.Resume: HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Resume');
// Not implemented
  result := E_NOTIMPL;
//  codesite.ExitMethod('TMimeFilter.Resume');
end;

function TMimeFilter.Switch(const ProtocolData: TProtocolData): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.Switch');
  UrlMonProtocolSink.Switch(ProtocolData);
  result := S_OK;
//  codesite.ExitMethod('TMimeFilter.Switch');
end;

function TMimeFilter.ReportResult(hrResult: HResult; dwError: DWORD;
  szResult: LPCWSTR): HResult;
begin
//  codesite.EnterMethod('TMimeFilter.ReportResult');

	hrResult := S_OK;
	if (UrlMonProtocolSink = nil) then begin
		result := E_FAIL;

  end else begin
//    codesite.send('UrlMonProtocolSink Reporting Begin');
    UrlMonProtocolSink.ReportResult(hrResult, dwError, szResult);
//    codesite.send('UrlMonProtocolSink Reporting End');
    Result := S_OK;
  end;

//  codesite.ExitMethod('TMimeFilter.ReportResult');
end;

procedure TMimeFilterFactory.UpdateRegistry(Register: Boolean);
begin
//  codesite.EnterMethod('TMimeFilterFactor.UpdateRegistry');
  inherited UpdateRegistry(Register);
  if Register then AddKeys else RemoveKeys;
//  codesite.ExitMethod('TMimeFilterFactor.UpdateRegistry');
end;                                        

procedure TMimeFilterFactory.AddKeys;
var S: string;
begin
//  codesite.EnterMethod('TMimeFilterFactory.AddKeys');
  S := GUIDToString(CLSID_MimeFilter);
  with TRegistry.Create do
  try
    RootKey := HKEY_CLASSES_ROOT;
    if OpenKey('PROTOCOLS\Filter\' + MimeFilterType, True) then
    begin
      WriteString('', MimeFilterName);
      WriteString('CLSID', S);
      CloseKey;
    end;
  finally
    Free;
  end;
//  codesite.ExitMethod('TMimeFilterFactory.AddKeys');
end;

procedure TMimeFilterFactory.RemoveKeys;
var S: string;
begin
//  codesite.EnterMethod('TMimeFilterFactory.RemoveKeys');
  S := GUIDToString(CLSID_MimeFilter);
  with TRegistry.Create do
  try
    RootKey := HKEY_CLASSES_ROOT;
    DeleteKey('PROTOCOLS\Filter\'+MimeFilterType );
  finally
    Free;
  end;
//  codesite.ExitMethod('TMimeFilterFactory.RemoveKeys');
end;

initialization

  cs := TCriticalSection.Create();
  
//  codesite.enabled := false;
//  codesite.EnterMethod('Initialization');
  TMimeFilterFactory.Create(
    ComServer, TMimeFilter, CLSID_MimeFilter,
    'ieFilter', 'mkrz ieFilter', ciMultiInstance, tmApartment
  );
//  codesite.ExitMethod('Initialization');

finalization

  cs.free();

end.

