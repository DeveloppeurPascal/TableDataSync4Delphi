program OneTableDatabaseSample;

uses
  System.StartUpCopy,
  FMX.Forms,
  fMain in 'fMain.pas' {frmMain},
  Olf.TableDataSync in '..\..\..\src\Olf.TableDataSync.pas',
  Olf.RTL.GenRandomID in '..\..\lib-externes\librairies\src\Olf.RTL.GenRandomID.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
