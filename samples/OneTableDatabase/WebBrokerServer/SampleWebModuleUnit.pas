unit SampleWebModuleUnit;

interface

uses
  System.SysUtils,
  System.Classes,
  Web.HTTPApp,
  Olf.TableDataSync.WebModuleUnit,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.ConsoleUI.Wait,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite;

type
  TSampleWebModule = class(TOlfTDSWebModule)
    FDPhysSQLiteDriverLink2: TFDPhysSQLiteDriverLink;
  private
  public
    function LoginCheck(Request: TWebRequest): Boolean; override;
    function GetConnectionDefName(Request: TWebRequest): string; override;
    procedure Logout(Request: TWebRequest); override;
  end;

var
  WebModuleClass: TComponentClass = TSampleWebModule;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}
{$R *.dfm}

uses
  System.IOUtils;

{ TSampleWebModule }

function TSampleWebModule.GetConnectionDefName(Request: TWebRequest): string;
var
  FichierDB: string;
  CreerDB: Boolean;
  Params: TStringList;
  DB: tfdconnection;
begin
  result := getPostValueAsString(Request, 'dbAlias').Trim;
  if not result.IsEmpty then
  begin
{$IFDEF DEBUG}
    FichierDB := 'TestDatabase-Server-DEBUG.db';
{$ELSE}
    FichierDB := 'TestDatabase-Server.db';
{$ENDIF}
    FichierDB := tpath.Combine(tpath.GetDocumentsPath, FichierDB);
{$IFDEF DEBUG}
    writeln(FichierDB);
{$ENDIF}
    CreerDB := not tfile.exists(FichierDB);
    if not FDManager.IsConnectionDef(result) then
    begin
      Params := TStringList.Create;
      try
        Params.Clear;
        Params.AddPair('DriverID', 'SQLite');
        Params.AddPair('Database', FichierDB);
        FDManager.AddConnectionDef(result, 'SQLite', Params);
      finally
        Params.Free;
      end;
    end;
    if CreerDB then
    begin
      DB := tfdconnection.Create(self);
      try
        DB.ConnectionDefName := result;
        DB.Open;
        DB.ExecSQL('CREATE TABLE test (' +
          'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
          'idCloud INTEGER NULL DEFAULT 0, ' + ' texte1 VARCHAR(50)NULL, ' +
          ' texte2 VARCHAR(50)NULL, ' + ' texte3 VARCHAR(50)NULL,' +
          ' Sync_Changed BIT NULL DEFAULT 1, ' +
          ' Sync_ChangedDate DATETIME NULL,' +
          ' Sync_NoSeq INTEGER NULL DEFAULT 0 ' + '); ');
        DB.Close;
      finally
        DB.Free;
      end;
    end;
  end
  else
    raise Exception.Create('Missing "dbAlias" parameter.');
end;

function TSampleWebModule.LoginCheck(Request: TWebRequest): Boolean;
begin
  result := (getPostValueAsString(Request, 'user') = 'MyUser') and
    (getPostValueAsString(Request, 'password') = 'MyPassword');
end;

procedure TSampleWebModule.Logout(Request: TWebRequest);
begin
  // rien à faire en sortie de session sur ce projet
end;

end.
