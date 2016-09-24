library ieFilter;

uses
  ComServ,
  _ieFilter in '_ieFilter.pas',
  ieFilter_TLB in 'ieFilter_TLB.pas';

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.TLB}

{$R *.RES}

begin
end.


