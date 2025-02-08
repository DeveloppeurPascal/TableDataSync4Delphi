/// <summary>
/// ***************************************************************************
///
/// Table Data Sync for Delphi
///
/// Copyright 2017-2025 Patrick PREMARTIN under AGPL 3.0 license.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
/// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
/// DEALINGS IN THE SOFTWARE.
///
/// ***************************************************************************
///
/// A Delphi client/server library to synchronize table records over the
/// rainbows.
///
/// ***************************************************************************
///
/// Author(s) :
/// Patrick PREMARTIN
///
/// Site :
/// https://tabledatasync.developpeur-pascal.fr/
///
/// Project site :
/// https://github.com/DeveloppeurPascal/TableDataSync4Delphi
///
/// ***************************************************************************
/// File last update : 2025-02-05T20:59:38.201+01:00
/// Signature : b53c7df5d2c1109a6439afbdcfb23860d4a218ed
/// ***************************************************************************
/// </summary>

unit fMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.FMXUI.Wait,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  Data.DB,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Olf.TableDataSync,
  System.Rtti,
  FMX.Grid.Style,
  Data.Bind.EngExt,
  FMX.Bind.DBEngExt,
  FMX.Bind.Grid,
  System.Bindings.Outputs,
  FMX.Bind.Editors,
  Data.Bind.Components,
  Data.Bind.Grid,
  Data.Bind.DBScope,
  FMX.Controls.Presentation,
  FMX.ScrollBox,
  FMX.Grid,
  FMX.StdCtrls,
  FMX.Layouts,
  System.JSON;

type
  TfrmMain = class(TForm)
    FDConnection1: TFDConnection;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDTable1: TFDTable;
    StringGrid1: TStringGrid;
    BindSourceDB1: TBindSourceDB;
    BindingsList1: TBindingsList;
    LinkGridToDataSourceBindSourceDB1: TLinkGridToDataSource;
    Timer1: TTimer;
    Switch1: TSwitch;
    Layout1: TLayout;
    Button1: TButton;
    ProgressBar1: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure FDConnection1BeforeConnect(Sender: TObject);
    procedure FDConnection1AfterConnect(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FDTable1BeforePost(DataSet: TDataSet);
  private
    { Déclarations privées }
    CreerDB: boolean;
    SyncDB: TOlfTDSDatabase;
    FConnectionDefNameLocal: string;
    function GetConnectionDefNameLocal: string;
    property ConnectionDefNameLocal: string read GetConnectionDefNameLocal;
    function getNomFichier: string;
    procedure onSynchroStart(Sender: TObject);
    procedure onSynchroStop(Sender: TObject);
    procedure onSessionOpen(SessionParams: TJSONObject);
    procedure onSessionClose(SessionParams: TJSONObject);
    procedure onProgressBar(Step, MaxSteps: Cardinal);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils,
  System.Threading,
  Olf.RTL.GenRandomID;

procedure TfrmMain.Button1Click(Sender: TObject);
begin
  for var i := 0 to random(10) do
  begin
    FDTable1.Append;
    FDTable1.FieldByName('texte1').asString :=
      TOlfRandomIDGenerator.getIDBase2(10);
    FDTable1.FieldByName('texte2').asString :=
      TOlfRandomIDGenerator.getIDBase10(10);
    FDTable1.FieldByName('texte3').asString :=
      TOlfRandomIDGenerator.getIDBase36(10);
    FDTable1.FieldByName('Sync_Changed').asboolean := true;
    FDTable1.FieldByName('Sync_ChangedDate').asdatetime := now;
    FDTable1.Post;
  end;
end;

procedure TfrmMain.FDConnection1AfterConnect(Sender: TObject);
var
  SyncTable: TOlfTDSTable;
begin
  if CreerDB then
    FDConnection1.ExecSQL('CREATE TABLE test (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
      'idCloud INTEGER NULL DEFAULT 0, ' + ' texte1 VARCHAR(50)NULL, ' +
      ' texte2 VARCHAR(50)NULL, ' + ' texte3 VARCHAR(50)NULL,' +
      ' Sync_Changed BIT NULL DEFAULT 1, ' + ' Sync_ChangedDate DATETIME NULL,'
      + ' Sync_NoSeq INTEGER NULL DEFAULT 0 ' + '); ');
  FDTable1.TableName := 'test';
  FDTable1.Open;

  // Paramétrage de la librairie de synchronisation
  SyncDB := TOlfTDSDatabase.Create(self);
  SyncDB.SyncMode := TOlfTDSSyncMode.Manual;

  // evenements
  SyncDB.onSynchroStart := onSynchroStart;
  SyncDB.onSynchroStop := onSynchroStop;
  SyncDB.onSessionOpen := onSessionOpen;
  SyncDB.onSessionClose := onSessionClose;
  SyncDB.onProgress := onProgressBar;

  // Paramètres WebBrocker
  SyncDB.ServerProtocol := TOlfTDSServerProtocol.HTTP;
{$IFDEF DEBUG}
  SyncDB.ServerIPOrDomain := '127.0.0.1';
{$ELSE}
  SyncDB.ServerIPOrDomain := '92.222.216.233';
{$ENDIF}
  SyncDB.ServerPort := 8080;
  SyncDB.ServerFolder := '/';

  // Paramètres de la base de données
  SyncDB.DefaultChangedFieldName := 'Sync_Changed';
  SyncDB.DefaultChangedDateTimeFieldName := 'Sync_ChangedDate';
  SyncDB.DefaultNoSeqFieldName := 'Sync_NoSeq';
  SyncDB.LocalConnectionDefName := ConnectionDefNameLocal;

  // Ajout de la table de la base de données
  SyncTable := TOlfTDSTable.Create(self)
    .AddKey(TOlfTDSField.Create('id', 'idCloud'));
  SyncTable.TableName := FDTable1.TableName;
  SyncTable.Database := SyncDB;
  SyncTable.SyncType := TOlfTDSSyncType.Mirroring;
  SyncTable.TableDeleteType := TOlfTDSTableDeleteType.Physical;
end;

procedure TfrmMain.FDConnection1BeforeConnect(Sender: TObject);
var
  FichierDB: string;
begin
  FichierDB := getNomFichier;
  CreerDB := not tfile.exists(FichierDB);
  if FDManager.IsConnectionDef(ConnectionDefNameLocal) then
  begin
    FDConnection1.Params.Clear;
    FDConnection1.ConnectionDefName := ConnectionDefNameLocal;
  end
  else
  begin
    FDConnection1.Params.Clear;
    FDConnection1.Params.DriverID := 'SQLite';
    FDConnection1.Params.Database := FichierDB;
    FDManager.AddConnectionDef(ConnectionDefNameLocal, 'SQLite',
      FDConnection1.Params);
  end;
end;

procedure TfrmMain.FDTable1BeforePost(DataSet: TDataSet);
begin
  DataSet.FieldByName('Sync_Changed').asboolean := true;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FDConnection1.Open;
end;

function TfrmMain.GetConnectionDefNameLocal: string;
begin
  if FConnectionDefNameLocal.IsEmpty then
    FConnectionDefNameLocal := TOlfRandomIDGenerator.getIDBase62(50);
  result := FConnectionDefNameLocal;
end;

function TfrmMain.getNomFichier: string;
var
  Suffixe, Filename: string;
begin
{$IFDEF WIN64}
  Suffixe := '64';
{$ELSE}
  Suffixe := '';
{$ENDIF}
{$IFDEF DEBUG}
  Filename := 'TestDatabase-FMX' + Suffixe + '-DEBUG.db';
{$ELSE}
  Filename := 'TestDatabase-FMX' + Suffixe + '.db';
{$ENDIF}
  result := tpath.Combine(tpath.GetDocumentsPath, Filename);
end;

procedure TfrmMain.onProgressBar(Step, MaxSteps: Cardinal);
begin
  ProgressBar1.Max := MaxSteps;
  ProgressBar1.Value := Step;
end;

procedure TfrmMain.onSessionClose(SessionParams: TJSONObject);
begin
  // sessionParams.AddPair('dummy','nil');
end;

procedure TfrmMain.onSessionOpen(SessionParams: TJSONObject);
begin
  SessionParams.AddPair('user', 'MyUser');
  SessionParams.AddPair('password', 'MyPassword');
  SessionParams.AddPair('dbAlias', 'ServeurTestDB');
end;

procedure TfrmMain.onSynchroStart(Sender: TObject);
begin
  Switch1.IsChecked := true;
  ProgressBar1.Min := 0;
  ProgressBar1.Value := 0;
  ProgressBar1.Max := 0;
  ProgressBar1.Visible := true;
end;

procedure TfrmMain.onSynchroStop(Sender: TObject);
begin
  Switch1.IsChecked := false;
  ProgressBar1.Visible := false;
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  if assigned(SyncDB) and not(SyncDB.SyncState = TOlfTDSSyncState.Started) then
    tthread.CreateAnonymousThread(
      procedure
      begin
        SyncDB.Start;
        tthread.Queue(nil,
          procedure
          begin
            FDTable1.Refresh;
          end);
      end).Start;
end;

initialization

{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := true;
{$ENDIF}
randomize;

end.
