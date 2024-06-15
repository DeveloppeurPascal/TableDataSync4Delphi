unit Olf.TableDataSync;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.CONSOLEUI.Wait,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet;

const
  // Version de l'API gérée par ce fichier
  COlfTDSAPIVersion = 20211111;

  // Valeurs par défaut de l'accès au serveur de synchronisation par défaut
  COlfTDSDefaultServerProtocol = 'http';
  COlfTDSDefaultServerIPOrDomain = '127.0.0.1';
  COlfTDSDefaultServerPort = 80;
  COlfTDSDefaultServerFolder = '/';

  // Valeurs par défaut des champs de base de données utilisés pour la synchro
  COlfTDSDefaultChangedFieldName = 'SyncChanged';
  COlfTDSDefaultChangedDateTimeFieldName = 'SyncChangedDateTime';
  COlfTDSDefaultNoSeqFieldName = 'SyncNoSeq';

type
  TOlfTDSDatabase = class;
  TOlfTDSTable = class;
  TOlfTDSTableList = TList<TOlfTDSTable>; // Volontairement pas TObjectList
  TOlfTDSField = class;
  TOlfTDSFieldList = TObjectList<TOlfTDSField>;
  TOlfTDSForeignKey = class;
  TOlfTDSForeignKeyList = TObjectList<TOlfTDSForeignKey>;

  TOlfTDSSyncProgressEvent = procedure(Step, MaxSteps: Cardinal) of object;
  TOlfTDSTableSessionOpenEvent = procedure(SessionParams: TJSONObject)
    of object;
  TOlfTDSTableSessionCloseEvent = procedure(SessionParams: TJSONObject)
    of object;

{$SCOPEDENUMS ON}
  TOlfTDSSyncType = (LocalToServer, ServerToLocal, Mirroring);
  TOlfTDSSyncState = (Stopped, Started, Waiting);
  TOlfTDSSyncMode = (Manual, Auto);
  TOlfTDSServerProtocol = (HTTP, HTTPS);
  TOlfTDSExceptionType = (LocalKeyUnknown, ForeignKeyUnknown, TableUnknown,
    ForeignTableUnknown);
  TOlfTDSTableDeleteType = (Logical, Physical);

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TOlfTDSDatabase = class(TComponent)
  private
    FServerFolder: string;
    FServerProtocol: TOlfTDSServerProtocol;
    FDefaultNoSeqFieldName: string;
    FPrimaryKeyTableName: string;
    FServerPort: Cardinal;
    FDefaultChangedDateTimeFieldName: string;
    FServerIPOrDomain: string;
    FSyncMode: TOlfTDSSyncMode;
    FLocalConnectionDefName: string;
    FDeleteTableName: string;
    FDefaultChangedFieldName: string;
    FSyncState: TOlfTDSSyncState;
    FonSynchroStop: TNotifyEvent;
    FonSynchroStart: TNotifyEvent;
    FonProgress: TOlfTDSSyncProgressEvent;
    FDoneSteps, FMaxSteps: Cardinal;
    FonSessionOpen: TOlfTDSTableSessionOpenEvent;
    FonSessionClose: TOlfTDSTableSessionCloseEvent;
    function getServerURL: string;
    procedure SetDefaultChangedDateTimeFieldName(const Value: string);
    procedure SetDefaultChangedFieldName(const Value: string);
    procedure SetDefaultNoSeqFieldName(const Value: string);
    procedure SetDeleteTableName(const Value: string);
    procedure SetLocalConnectionDefName(const Value: string);
    procedure SetPrimaryKeyTableName(const Value: string);
    procedure SetServerFolder(const Value: string);
    procedure SetServerIPOrDomain(const Value: string);
    procedure SetServerPort(const Value: Cardinal);
    procedure SetServerProtocol(const Value: TOlfTDSServerProtocol);
    procedure SetSyncMode(const Value: TOlfTDSSyncMode);
    procedure DoTableAdd(const Table: TOlfTDSTable);
    procedure DoTableRemove(const Table: TOlfTDSTable);
    procedure SetonProgress(const Value: TOlfTDSSyncProgressEvent);
    procedure SetonSynchroStart(const Value: TNotifyEvent);
    procedure SetonSynchroStop(const Value: TNotifyEvent);
    procedure SetonSessionClose(const Value: TOlfTDSTableSessionCloseEvent);
    procedure SetonSessionOpen(const Value: TOlfTDSTableSessionOpenEvent);
  protected
    FTableList: TOlfTDSTableList;
    procedure TableAdd(const Table: TOlfTDSTable);
    procedure TableRemove(const Table: TOlfTDSTable);
    procedure ProgressAddDoneSteps(const Value: Cardinal);
    procedure ProgressRemoveDoneSteps(const Value: Cardinal);
    procedure ProgressAddMaxSteps(const Value: Cardinal);
    procedure ProgressRemoveMaxSteps(const Value: Cardinal);
    function SendRemoteRequest(const EndPoint: string;
      const Params: TJSONObject): TJSONObject;
  public

    property TableList: TOlfTDSTableList read FTableList;
    // **********
    // Propriétés liées au serveur de synchronisation
    // **********

    property ServerURL: string read getServerURL;

    // **********
    // Propriétés liées à la synchronisation
    // **********

    property SyncState: TOlfTDSSyncState read FSyncState;

    procedure DoSynchro;
    procedure Start;
    procedure Stop(Force: boolean = false);
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    // **********
    // Propriétés liées à la base locale
    // **********

    property LocalConnectionDefName: string read FLocalConnectionDefName
      write SetLocalConnectionDefName;

    // **********
    // Propriétés liées au serveur de synchronisation
    // **********

    property ServerProtocol: TOlfTDSServerProtocol read FServerProtocol
      write SetServerProtocol;
    property ServerIPOrDomain: string read FServerIPOrDomain
      write SetServerIPOrDomain;
    property ServerPort: Cardinal read FServerPort write SetServerPort;
    property ServerFolder: string read FServerFolder write SetServerFolder;

    // **********
    // Propriétés liées à la synchronisation
    // **********

    property SyncMode: TOlfTDSSyncMode read FSyncMode write SetSyncMode;

    // **********
    // Propriétés liées aux champs de synchronisation
    // **********

    property DefaultChangedFieldName: string read FDefaultChangedFieldName
      write SetDefaultChangedFieldName;
    property DefaultChangedDateTimeFieldName: string
      read FDefaultChangedDateTimeFieldName
      write SetDefaultChangedDateTimeFieldName;
    property DefaultNoSeqFieldName: string read FDefaultNoSeqFieldName
      write SetDefaultNoSeqFieldName;

    /// <summary>
    /// Table utilisée pour les suppressions physiques
    /// </summary>
    /// Utilisée uniquement pour les tables sur lesquelles la suppression
    /// logique n'est pas possible.
    property DeleteTableName: string read FDeleteTableName
      write SetDeleteTableName;

    /// <summary>
    /// Table utilisée pour les clés côté serveur
    /// </summary>
    /// Privilégier le stockage des clés serveur directement dans les tables
    /// existantes, mais ça permet de ne pas modifier la structure de la base
    property PrimaryKeyTableName: string read FPrimaryKeyTableName
      write SetPrimaryKeyTableName;

    /// <summary>
    /// Déclenché au démarrage d'une synchronisation, avant de traiter la liste des tables
    /// </summary>
    property onSynchroStart: TNotifyEvent read FonSynchroStart
      write SetonSynchroStart;

    /// <summary>
    /// Déclenché en fin de synchronisation, après avoir traité toutes les tables
    /// </summary>
    property onSynchroStop: TNotifyEvent read FonSynchroStop
      write SetonSynchroStop;

    /// <summary>
    /// Déclenché lors de l'ajout ou la suppression d'une étape en cours de synchronisation de la base de données (toutes tables confondues).
    /// Permet par exemple de gérer une barre de progression au niveau de l'interface utilisateur.
    /// </summary>
    property onProgress: TOlfTDSSyncProgressEvent read FonProgress
      write SetonProgress;

    /// <summary>
    /// Appelé avant le "login" de synchronisation de chaque table.
    /// Permet de paramétrer des informations de connexion comme user/password par ajout de paires clé/valeur au paramètre reçu.
    /// Utilisé uniquement si la table en cours de synchronisation n'a pas son propore événement onSessionOpen.
    /// </summary>
    property onSessionOpen: TOlfTDSTableSessionOpenEvent read FonSessionOpen
      write SetonSessionOpen;

    /// <summary>
    /// Appelé avant le "logout" en fin de synchronisation de chaque table.
    /// Utilisé uniquement si la table en cours de synchronisation n'a pas son propore événement onSessionClose.
    /// </summary>
    property onSessionClose: TOlfTDSTableSessionCloseEvent read FonSessionClose
      write SetonSessionClose;
  end;

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TOlfTDSTable = class(TComponent)
  private
    FChangedDateTimeFieldName: string;
    FTableName: string;
    FChangedFieldName: string;
    FSyncType: TOlfTDSSyncType;
    FNoSeqFieldName: string;
    FDatabase: TOlfTDSDatabase;
    FonSynchroStop: TNotifyEvent;
    FonSynchroStart: TNotifyEvent;
    FSessionID: string;
    FTableDeleteType: TOlfTDSTableDeleteType;
    FForceSynchroStop: boolean;
    FonSessionOpen: TOlfTDSTableSessionOpenEvent;
    FonSessionClose: TOlfTDSTableSessionCloseEvent;
    procedure SetChangedDateTimeFieldName(const Value: string);
    procedure SetChangedFieldName(const Value: string);
    procedure SetDatabase(const Value: TOlfTDSDatabase);
    procedure SetNoSeqFieldName(const Value: string);
    procedure SetSyncType(const Value: TOlfTDSSyncType);
    procedure SetTableName(const Value: string);
    procedure SetonSynchroStart(const Value: TNotifyEvent);
    procedure SetonSynchroStop(const Value: TNotifyEvent);
    procedure SetTableDeleteType(const Value: TOlfTDSTableDeleteType);
    procedure SetonSessionOpen(const Value: TOlfTDSTableSessionOpenEvent);
    procedure SetonSessionClose(const Value: TOlfTDSTableSessionCloseEvent);
    function isFieldInKeyList(FieldName: string): boolean;
    function isSyncFieldInKeyList(SyncFieldName: string): boolean;
    function isFieldInForeignKeyList(FieldName: string): boolean;
    function isSyncFieldInForeignKeyList(SyncFieldName: string): boolean;
    function getFieldFromSyncField(SyncFieldName: string): string;
    function getSyncFieldFromField(FieldName: string): string;
    function getForeignFieldFromForeignSyncField(ForeignSyncFieldName
      : string): string;
    function getForeignSyncFieldFromForeignField(FieldName: string): string;
    function isBase64Field(AField: TField): boolean;
    function getBase64FieldList: string;
  protected
    FKeyList: TOlfTDSFieldList;
    FForeignKeyList: TOlfTDSForeignKeyList;
    function getChangedDateTimeFieldName: string;
    function getChangedFieldName: string;
    function getNoSeqFieldName: string;
    procedure DoSynchro;
    procedure Step01OpenSession;
    procedure Step02RemoteToLocal;
    procedure Step03LocalToRemote;
    procedure Step04CloseSession;
    procedure StartSynchro;
    procedure StopSynchro;
  public
    function AddKey(AKeyField: TOlfTDSField): TOlfTDSTable; overload;
    function AddKey(AFieldName, ASyncFieldName: string): TOlfTDSTable; overload;
    function AddKey(AFieldName: string): TOlfTDSTable; overload;
    function AddForeignKey(AForeignKey: TOlfTDSForeignKey)
      : TOlfTDSTable; overload;
    function AddForeignKey(ALocalFieldName: string; AForeignTableName: string;
      AForeignFieldName: string): TOlfTDSTable; overload;
    function AddForeignKey(ALocalFieldName, ALocalSyncFieldName: string;
      AForeignTableName: string; AForeignFieldName, AForeignSyncFieldName
      : string): TOlfTDSTable; overload;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Database: TOlfTDSDatabase read FDatabase write SetDatabase;
    property TableName: string read FTableName write SetTableName;
    property SyncType: TOlfTDSSyncType read FSyncType write SetSyncType;
    property ChangedFieldName: string read FChangedFieldName
      write SetChangedFieldName;
    property ChangedDateTimeFieldName: string read FChangedDateTimeFieldName
      write SetChangedDateTimeFieldName;
    property TableDeleteType: TOlfTDSTableDeleteType read FTableDeleteType
      write SetTableDeleteType;
    property NoSeqFieldName: string read FNoSeqFieldName
      write SetNoSeqFieldName;

    /// <summary>
    /// Déclenché avant démarrage de la synchronisation de la table en cours
    /// </summary>
    property onSynchroStart: TNotifyEvent read FonSynchroStart
      write SetonSynchroStart;

    /// <summary>
    /// Déclenché après synchronisation de la table en cours
    /// </summary>
    property onSynchroStop: TNotifyEvent read FonSynchroStop
      write SetonSynchroStop;

    /// <summary>
    /// Déclenché avant la demande de connexion pour synchroniser la table en cours.
    /// Permet d'ajouter des éléments complémentaires à transmettre au serveur (user/password, infos de base de données, ...) sous forme de paires clé/valeur qui seront traités lors du "login".
    /// </summary>
    property onSessionOpen: TOlfTDSTableSessionOpenEvent read FonSessionOpen
      write SetonSessionOpen;

    /// <summary>
    /// Déclenché en fermeture de session, suite à une synchronisation de la table en cours.
    /// Permet de transmettre des éléments au serveur sous forme de clé/valeur qui seront traités lors du "logout"
    /// </summary>
    property onSessionClose: TOlfTDSTableSessionCloseEvent read FonSessionClose
      write SetonSessionClose;
  end;

  TOlfTDSField = class
  private
    FFieldName: string;
    FSyncFieldName: string;
  public
    constructor Create(AFieldName: string); overload;
    constructor Create(AFieldName, ASyncFieldName: string); overload;
  end;

  TOlfTDSForeignKey = class
  private
    FLocalKeyFieldName: string;
    FSyncLocalKeyFieldName: string;
    FForeignTableName: string;
    FForeignKeyFieldName: string;
    FSyncForeignKeyFieldName: string;
  public
    constructor Create(ALocalKeyField: TOlfTDSField; AForeignTableName: string;
      AForeignKeyField: TOlfTDSField); overload;
  end;

  TOlfTDSException = class(Exception)
  private
    FExceptionType: TOlfTDSExceptionType;
  public
    property ExceptionType: TOlfTDSExceptionType read FExceptionType;
    constructor Create(AExceptionType: TOlfTDSExceptionType;
      Msg: string); overload;
  end;

procedure Register;

implementation

// TODO : gérer suppressions logiques (à priori rien à faire de spécial dans la synchro elle-même)
// TODO : gérer les suppressions physiques
// TODO : remplacer Exception.Create() par TOlfTDSException.Create()
// TODO : lancer la synchronisation en background
// TODO : ajouter une info et un événement au niveau de la database pour traiter les conflits de version (mise à jour serveur faite après la locale) => prérenseignement tables
// TODO : ajouter une info et un événement au niveau des tables pour traiter les conflits de version (mise à jour serveur faite après la locale)
// TODO : ajouter un éditeur sur la liste des champs, clés, ... d'une table et les passer en persistents

uses
  System.net.HttpClient,
  System.net.Mime,
  System.NetEncoding;

procedure Register;
begin
  RegisterComponents('OlfSoftware', [TOlfTDSDatabase, TOlfTDSTable]);
end;

{ TOlfTDSDatabase }

constructor TOlfTDSDatabase.Create(AOwner: TComponent);
begin
  // Prérenseignement des propriétés publiées
  FSyncMode := TOlfTDSSyncMode.Auto;
  if ('https' = COlfTDSDefaultServerProtocol) then
    FServerProtocol := TOlfTDSServerProtocol.HTTPS
  else
    FServerProtocol := TOlfTDSServerProtocol.HTTP;
  FServerIPOrDomain := COlfTDSDefaultServerIPOrDomain;
  FServerPort := COlfTDSDefaultServerPort;
  FServerFolder := COlfTDSDefaultServerFolder;
  FDefaultChangedFieldName := COlfTDSDefaultChangedFieldName;
  FDefaultChangedDateTimeFieldName := COlfTDSDefaultChangedDateTimeFieldName;
  FDefaultNoSeqFieldName := COlfTDSDefaultNoSeqFieldName;

  inherited;

  FSyncState := TOlfTDSSyncState.Stopped;
  FMaxSteps := 0;
  FDoneSteps := 0;
end;

destructor TOlfTDSDatabase.Destroy;
begin
  if assigned(FTableList) then
    FTableList.free;
  inherited;
end;

procedure TOlfTDSDatabase.DoSynchro;
begin
  Start;
end;

procedure TOlfTDSDatabase.DoTableAdd(const Table: TOlfTDSTable);
begin
  if not assigned(FTableList) then
    FTableList := TOlfTDSTableList.Create;
  if (FTableList.IndexOf(Table) < 0) then
    FTableList.Add(Table);
end;

procedure TOlfTDSDatabase.DoTableRemove(const Table: TOlfTDSTable);
begin
  if assigned(FTableList) then
    FTableList.Extract(Table);
  // FTableList.Remove(Table);
end;

function TOlfTDSDatabase.getServerURL: string;
begin
  case ServerProtocol of
    TOlfTDSServerProtocol.HTTP:
      result := 'http://';
    TOlfTDSServerProtocol.HTTPS:
      result := 'https://';
  else
    raise Exception.Create('Protocole must be set on ' + Name + ' !');
  end;
  if (not ServerIPOrDomain.IsEmpty) then
    result := result + ServerIPOrDomain
  else
    raise Exception.Create('IP must be set on ' + Name + ' !');
  result := result + ':' + FServerPort.tostring + FServerFolder;
  if not result.EndsWith('/') then
    result := result + '/';
end;

procedure TOlfTDSDatabase.ProgressAddDoneSteps(const Value: Cardinal);
begin
  tmonitor.Enter(self);
  try
    FDoneSteps := FDoneSteps + Value;
    if assigned(onProgress) then
      tthread.synchronize(nil,
        procedure
        begin
          onProgress(FDoneSteps, FMaxSteps);
        end);
  finally
    tmonitor.Exit(self);
  end;
end;

procedure TOlfTDSDatabase.ProgressAddMaxSteps(const Value: Cardinal);
begin
  tmonitor.Enter(self);
  try
    FMaxSteps := FMaxSteps + Value;
    if assigned(onProgress) then
      tthread.synchronize(nil,
        procedure
        begin
          onProgress(FDoneSteps, FMaxSteps);
        end);
  finally
    tmonitor.Exit(self);
  end;
end;

procedure TOlfTDSDatabase.ProgressRemoveDoneSteps(const Value: Cardinal);
begin
  tmonitor.Enter(self);
  try
    if (Value > FDoneSteps) then
      FDoneSteps := FDoneSteps - Value
    else
      FDoneSteps := 0;
    if assigned(onProgress) then
      tthread.synchronize(nil,
        procedure
        begin
          onProgress(FDoneSteps, FMaxSteps);
        end);
  finally
    tmonitor.Exit(self);
  end;
end;

procedure TOlfTDSDatabase.ProgressRemoveMaxSteps(const Value: Cardinal);
begin
  tmonitor.Enter(self);
  try
    if (Value > FMaxSteps) then
      FMaxSteps := FMaxSteps - Value
    else
      FMaxSteps := 0;
    if assigned(onProgress) then
      tthread.synchronize(nil,
        procedure
        begin
          onProgress(FDoneSteps, FMaxSteps);
        end);
  finally
    tmonitor.Exit(self);
  end;
end;

function TOlfTDSDatabase.SendRemoteRequest(const EndPoint: string;
const Params: TJSONObject): TJSONObject;
var
  server: THttpClient;
  server_response: IHTTPResponse;
  PostParams: TMultipartFormData;
  i: integer;
begin
  result := nil;
  server := THttpClient.Create;
  try // TODO : ajouter un code de contrôle par rapport au TokenPrivate de la connexion
    PostParams := TMultipartFormData.Create;
    try
      // TODO : Ajouter un événement pour chiffrer les paramètres (json => stream)
      for i := 0 to Params.count - 1 do
        PostParams.AddField(Params.Pairs[i].JsonString.Value,
          Params.Pairs[i].JsonValue.Value);
      PostParams.AddField('TDSAPIVersion', COlfTDSAPIVersion.tostring);
{$IFDEF DEBUG}
      PostParams.AddField('TDSDebugMode', '1');
{$ELSE}
      PostParams.AddField('TDSDebugMode', '0');
{$ENDIF}
      server_response := server.Post(getServerURL + EndPoint, PostParams);
      if server_response.StatusCode = 200 then
        // TODO : Ajouter un événement pour déchiffrer la réponse (stream => json)
        result := (TJSONObject.ParseJSONValue(server_response.ContentAsString
          (TEncoding.UTF8)) as TJSONObject);
      if assigned(result) then
        result.AddPair('StatusCode',
          tjsonnumber.Create(server_response.StatusCode))
          .AddPair('StatusText', server_response.StatusText)
      else
        result := TJSONObject.Create.AddPair('StatusCode',
          tjsonnumber.Create(server_response.StatusCode))
          .AddPair('StatusText', server_response.StatusText);
    finally
      PostParams.free;
    end;
  finally
    server.free;
  end;
end;

procedure TOlfTDSDatabase.SetDefaultChangedDateTimeFieldName
  (const Value: string);
begin
  FDefaultChangedDateTimeFieldName := Value;
end;

procedure TOlfTDSDatabase.SetDefaultChangedFieldName(const Value: string);
begin
  FDefaultChangedFieldName := Value;
end;

procedure TOlfTDSDatabase.SetDefaultNoSeqFieldName(const Value: string);
begin
  FDefaultNoSeqFieldName := Value;
end;

procedure TOlfTDSDatabase.SetDeleteTableName(const Value: string);
begin
  FDeleteTableName := Value;
end;

procedure TOlfTDSDatabase.SetLocalConnectionDefName(const Value: string);
begin
  if not fdmanager.active then
    fdmanager.Open;
  if fdmanager.IsConnectionDef(Value) then
    FLocalConnectionDefName := Value
  else
    raise Exception.Create('Unknown connection definition name in FDManager.');
end;

procedure TOlfTDSDatabase.SetonProgress(const Value: TOlfTDSSyncProgressEvent);
begin
  FonProgress := Value;
end;

procedure TOlfTDSDatabase.SetonSessionClose(const Value
  : TOlfTDSTableSessionCloseEvent);
begin
  FonSessionClose := Value;
end;

procedure TOlfTDSDatabase.SetonSessionOpen(const Value
  : TOlfTDSTableSessionOpenEvent);
begin
  FonSessionOpen := Value;
end;

procedure TOlfTDSDatabase.SetonSynchroStart(const Value: TNotifyEvent);
begin
  FonSynchroStart := Value;
end;

procedure TOlfTDSDatabase.SetonSynchroStop(const Value: TNotifyEvent);
begin
  FonSynchroStop := Value;
end;

procedure TOlfTDSDatabase.SetPrimaryKeyTableName(const Value: string);
begin
  FPrimaryKeyTableName := Value;
end;

procedure TOlfTDSDatabase.SetServerFolder(const Value: string);
begin
  if not Value.StartsWith('/') then
    FServerFolder := '/' + Value
  else
    FServerFolder := Value;
end;

procedure TOlfTDSDatabase.SetServerIPOrDomain(const Value: string);
begin
  FServerIPOrDomain := Value;
end;

procedure TOlfTDSDatabase.SetServerPort(const Value: Cardinal);
begin
  FServerPort := Value;
end;

procedure TOlfTDSDatabase.SetServerProtocol(const Value: TOlfTDSServerProtocol);
begin
  FServerProtocol := Value;
end;

procedure TOlfTDSDatabase.SetSyncMode(const Value: TOlfTDSSyncMode);
begin
  FSyncMode := Value;
end;

procedure TOlfTDSDatabase.Start;
var
  Table: TOlfTDSTable;
  i: integer;
begin
  FSyncState := TOlfTDSSyncState.Started;
  if assigned(onSynchroStart) then
    tthread.synchronize(nil,
      procedure
      begin
        onSynchroStart(self);
      end);
  for i := FTableList.count - 1 downto 0 do
  begin
    Table := FTableList[i];
    try
      if not(FSyncState = TOlfTDSSyncState.Started) then
        break;
      if assigned(Table) then
        Table.StartSynchro;
    except
      FTableList.Extract(Table);
      // FTableList.Remove(Table);
    end;
  end;
  // TODO : donner la possibilité d'utiliser TParallel.For() sur option (désactivée par défaut)
  // TODO : tester TThread.CheckTerminated
  for i := FTableList.count - 1 downto 0 do
  begin
    Table := FTableList[i];
    try
      if not(FSyncState = TOlfTDSSyncState.Started) then
        break;
      if assigned(Table) then
        Table.DoSynchro
    except
      FTableList.Extract(Table);
      // FTableList.Remove(Table);
    end;
  end;
  Stop;
end;

procedure TOlfTDSDatabase.Stop(Force: boolean);
var
  Table: TOlfTDSTable;
  i: integer;
begin
  try
    if Force and (FSyncState = TOlfTDSSyncState.Started) then
      for i := FTableList.count - 1 downto 0 do
      begin
        Table := FTableList[i];
        try
          if assigned(Table) then
            Table.StopSynchro;
        except
          FTableList.Extract(Table);
          // FTableList.Remove(Table);
        end;
      end;
    FSyncState := TOlfTDSSyncState.Stopped;
    if assigned(onSynchroStop) then
      tthread.synchronize(nil,
        procedure
        begin
          onSynchroStop(self);
        end);
  finally

  end;
end;

procedure TOlfTDSDatabase.TableAdd(const Table: TOlfTDSTable);
begin
  if assigned(Table) then
    Table.Database := self;
end;

procedure TOlfTDSDatabase.TableRemove(const Table: TOlfTDSTable);
begin
  if assigned(Table) then
    Table.Database := nil;
end;

{ TOlfTDSField }

constructor TOlfTDSField.Create(AFieldName, ASyncFieldName: string);
begin
  inherited Create;
  FFieldName := AFieldName.trim;
  if FFieldName.IsEmpty then
    raise TOlfTDSException.Create(TOlfTDSExceptionType.LocalKeyUnknown,
      'AFieldName is empty');
  FSyncFieldName := ASyncFieldName.trim;
end;

constructor TOlfTDSField.Create(AFieldName: string);
begin
  Create(AFieldName, '');
end;

{ TOlfTDSTable }

function TOlfTDSTable.AddForeignKey(AForeignKey: TOlfTDSForeignKey)
  : TOlfTDSTable;
begin
  if assigned(AForeignKey) then
  begin
    if not assigned(FForeignKeyList) then
      FForeignKeyList := TOlfTDSForeignKeyList.Create;
    if FForeignKeyList.IndexOf(AForeignKey) < 0 then
      FForeignKeyList.Add(AForeignKey);
  end;
  result := self;
end;

function TOlfTDSTable.AddKey(AKeyField: TOlfTDSField): TOlfTDSTable;
begin
  if assigned(AKeyField) then
  begin
    if not assigned(FKeyList) then
      FKeyList := TOlfTDSFieldList.Create;
    if FKeyList.IndexOf(AKeyField) < 0 then
      FKeyList.Add(AKeyField);
  end;
  result := self;
end;

function TOlfTDSTable.AddKey(AFieldName, ASyncFieldName: string): TOlfTDSTable;
begin
  result := AddKey(TOlfTDSField.Create(AFieldName, ASyncFieldName));
end;

function TOlfTDSTable.AddForeignKey(ALocalFieldName, ALocalSyncFieldName,
  AForeignTableName, AForeignFieldName, AForeignSyncFieldName: string)
  : TOlfTDSTable;
begin
  result := AddForeignKey(TOlfTDSForeignKey.Create
    (TOlfTDSField.Create(ALocalFieldName, ALocalSyncFieldName),
    AForeignTableName, TOlfTDSField.Create(AForeignFieldName,
    AForeignSyncFieldName)));
end;

function TOlfTDSTable.AddForeignKey(ALocalFieldName, AForeignTableName,
  AForeignFieldName: string): TOlfTDSTable;
begin
  result := AddForeignKey(TOlfTDSForeignKey.Create
    (TOlfTDSField.Create(ALocalFieldName), AForeignTableName,
    TOlfTDSField.Create(AForeignFieldName)));
end;

function TOlfTDSTable.AddKey(AFieldName: string): TOlfTDSTable;
begin
  result := AddKey(TOlfTDSField.Create(AFieldName));
end;

constructor TOlfTDSTable.Create(AOwner: TComponent);
begin
  FKeyList := nil;
  FForeignKeyList := nil;
  inherited;
  //
end;

destructor TOlfTDSTable.Destroy;
begin
  Database := nil;
  if assigned(FKeyList) then
    FKeyList.free;
  if assigned(FForeignKeyList) then
    FForeignKeyList.free;
  inherited;
end;

procedure TOlfTDSTable.DoSynchro;
begin
  if not assigned(Database) then
    raise Exception.Create('Database needed on ' + Name);
  if (Database.SyncState <> TOlfTDSSyncState.Started) then
    Exit;
  if assigned(onSynchroStart) then
    tthread.synchronize(nil,
      procedure
      begin
        onSynchroStart(self);
      end);
  if FForceSynchroStop then
    Exit;
  Database.ProgressAddMaxSteps(1);
  Step01OpenSession;
  // TODO : tester avec des anomalies de login pour voir comment les traiter ici
  if not FSessionID.IsEmpty then
    try
      // On commence par rapatrier les données du serveur
      if (FSyncType in [TOlfTDSSyncType.ServerToLocal,
        TOlfTDSSyncType.Mirroring]) then
        Step02RemoteToLocal;
      // On envoi nos mises à jour et nouveautés
      if (FSyncType in [TOlfTDSSyncType.LocalToServer,
        TOlfTDSSyncType.Mirroring]) then
        Step03LocalToRemote;
    finally
      Step04CloseSession;
      Database.ProgressAddDoneSteps(1);
      if assigned(onSynchroStop) then
        tthread.synchronize(nil,
          procedure
          begin
            onSynchroStop(self);
          end);
    end;
end;

function TOlfTDSTable.getBase64FieldList: string;
var
  DB: TFDConnection;
  Table: TFDTable;
  i: integer;
begin
  result := '';
  DB := TFDConnection.Create(nil);
  try
    DB.Params.Clear;
    DB.ConnectionDefName := Database.LocalConnectionDefName;
    DB.Open;
    Table := TFDTable.Create(self);
    try
      Table.Connection := DB;
      Table.TableName := FTableName;
      Table.Open;
      for i := 0 to Table.fields.count - 1 do
        if isBase64Field(Table.fields[i]) then
          if result.IsEmpty then
            result := Table.fields[i].FieldName
          else
            result := result + ',' + Table.fields[i].FieldName;
      Table.Close;
    finally
      Table.free;
    end;
  finally
    DB.free;
  end;
end;

function TOlfTDSTable.getChangedDateTimeFieldName: string;
begin
  if FChangedDateTimeFieldName.Length > 0 then
    result := FChangedDateTimeFieldName
  else if assigned(Database) then
    result := Database.DefaultChangedDateTimeFieldName
  else
    result := '';
end;

function TOlfTDSTable.getChangedFieldName: string;
begin
  if FChangedFieldName.Length > 0 then
    result := FChangedFieldName
  else if assigned(Database) then
    result := Database.DefaultChangedFieldName
  else
    result := '';
end;

function TOlfTDSTable.getFieldFromSyncField(SyncFieldName: string): string;
var
  i: integer;
begin
  result := '';
  if assigned(FKeyList) and (FKeyList.count > 0) then
    for i := 0 to FKeyList.count - 1 do
      if (SyncFieldName = FKeyList[i].FSyncFieldName) then
      begin
        result := FKeyList[i].FFieldName;
        break;
      end;
end;

function TOlfTDSTable.getForeignFieldFromForeignSyncField(ForeignSyncFieldName
  : string): string;
var
  i: integer;
begin
  result := '';
  if assigned(FKeyList) and (FForeignKeyList.count > 0) then
    for i := 0 to FForeignKeyList.count - 1 do
      if (ForeignSyncFieldName = FForeignKeyList[i].FSyncLocalKeyFieldName) then
      begin
        result := FForeignKeyList[i].FLocalKeyFieldName;
        break;
      end;
end;

function TOlfTDSTable.getForeignSyncFieldFromForeignField
  (FieldName: string): string;
var
  i: integer;
begin
  result := '';
  if assigned(FKeyList) and (FForeignKeyList.count > 0) then
    for i := 0 to FForeignKeyList.count - 1 do
      if (FieldName = FForeignKeyList[i].FLocalKeyFieldName) then
      begin
        result := FForeignKeyList[i].FSyncLocalKeyFieldName;
        break;
      end;
end;

function TOlfTDSTable.getNoSeqFieldName: string;
begin
  if FNoSeqFieldName.Length > 0 then
    result := FNoSeqFieldName
  else if assigned(Database) then
    result := Database.DefaultNoSeqFieldName
  else
    result := '';
end;

function TOlfTDSTable.getSyncFieldFromField(FieldName: string): string;
var
  i: integer;
begin
  result := '';
  if assigned(FKeyList) and (FKeyList.count > 0) then
    for i := 0 to FKeyList.count - 1 do
      if (FieldName = FKeyList[i].FFieldName) then
      begin
        result := FKeyList[i].FSyncFieldName;
        break;
      end;
end;

function TOlfTDSTable.isBase64Field(AField: TField): boolean;
begin
  result := AField.DataType in [TFieldType.ftBCD, TFieldType.ftBytes,
    TFieldType.ftVarBytes, TFieldType.ftBlob, TFieldType.ftGraphic,
    TFieldType.ftTypedBinary, TFieldType.ftArray, TFieldType.ftGuid,
    TFieldType.ftFMTBcd];
end;

function TOlfTDSTable.isFieldInForeignKeyList(FieldName: string): boolean;
var
  i: integer;
begin
  result := assigned(FForeignKeyList) and (FForeignKeyList.count > 0);
  if result then
    for i := 0 to FForeignKeyList.count - 1 do
    begin
      result := FieldName = FForeignKeyList[i].FLocalKeyFieldName;
      if result then
        break;
    end;
end;

function TOlfTDSTable.isFieldInKeyList(FieldName: string): boolean;
var
  i: integer;
begin
  result := assigned(FKeyList) and (FKeyList.count > 0);
  if result then
    for i := 0 to FKeyList.count - 1 do
    begin
      result := FieldName = FKeyList[i].FFieldName;
      if result then
        break;
    end;
end;

function TOlfTDSTable.isSyncFieldInForeignKeyList(SyncFieldName
  : string): boolean;
var
  i: integer;
begin
  result := assigned(FForeignKeyList) and (FForeignKeyList.count > 0);
  if result then
    for i := 0 to FForeignKeyList.count - 1 do
    begin
      result := SyncFieldName = FForeignKeyList[i].FSyncLocalKeyFieldName;
      if result then
        break;
    end;
end;

function TOlfTDSTable.isSyncFieldInKeyList(SyncFieldName: string): boolean;
var
  i: integer;
begin
  result := assigned(FKeyList) and (FKeyList.count > 0);
  if result then
    for i := 0 to FKeyList.count - 1 do
    begin
      result := SyncFieldName = FKeyList[i].FSyncFieldName;
      if result then
        break;
    end;
end;

procedure TOlfTDSTable.SetChangedDateTimeFieldName(const Value: string);
begin
  FChangedDateTimeFieldName := Value;
end;

procedure TOlfTDSTable.SetChangedFieldName(const Value: string);
begin
  FChangedFieldName := Value;
end;

procedure TOlfTDSTable.SetDatabase(const Value: TOlfTDSDatabase);
begin
  if assigned(FDatabase) then
    FDatabase.DoTableRemove(self);
  FDatabase := Value;
  if assigned(FDatabase) then
    FDatabase.DoTableAdd(self);
end;

procedure TOlfTDSTable.SetNoSeqFieldName(const Value: string);
begin
  FNoSeqFieldName := Value;
end;

procedure TOlfTDSTable.SetonSessionClose(const Value
  : TOlfTDSTableSessionCloseEvent);
begin
  FonSessionClose := Value;
end;

procedure TOlfTDSTable.SetonSessionOpen(const Value
  : TOlfTDSTableSessionOpenEvent);
begin
  FonSessionOpen := Value;
end;

procedure TOlfTDSTable.SetonSynchroStart(const Value: TNotifyEvent);
begin
  FonSynchroStart := Value;
end;

procedure TOlfTDSTable.SetonSynchroStop(const Value: TNotifyEvent);
begin
  FonSynchroStop := Value;
end;

procedure TOlfTDSTable.SetSyncType(const Value: TOlfTDSSyncType);
begin
  FSyncType := Value;
end;

procedure TOlfTDSTable.SetTableDeleteType(const Value: TOlfTDSTableDeleteType);
begin
  FTableDeleteType := Value;
end;

procedure TOlfTDSTable.SetTableName(const Value: string);
begin
  FTableName := Value;
end;

procedure TOlfTDSTable.StartSynchro;
begin // TODO : peut-être protéger FForceSynchroStop avec un Mutex en écriture et lecture
  FForceSynchroStop := false;
end;

procedure TOlfTDSTable.Step01OpenSession;
var
  Request, response: TJSONObject;
begin
  if assigned(Database) then
  begin
    Database.ProgressAddMaxSteps(1);
    try
      Request := TJSONObject.Create;
      try
        Request.AddPair('TDSTableName', TableName);
        Request.AddPair('TDSB64Fields', getBase64FieldList);
        if assigned(onSessionOpen) then
          tthread.synchronize(nil,
            procedure
            begin
              onSessionOpen(Request);
            end)
        else if assigned(Database.onSessionOpen) then
          tthread.synchronize(nil,
            procedure
            begin
              Database.onSessionOpen(Request);
            end);
        try
          response := Database.SendRemoteRequest('login', Request);
        finally
          if assigned(response) then
            try
              if ((response.GetValue('StatusCode') as tjsonnumber).AsInt = 200)
              then
                FSessionID :=
                  (response.GetValue('TDSSessionID') as TJSONString).Value
              else
              begin
                FSessionID := '';
                raise Exception.Create('Synchro refused. Error HTTP ' +
                  (response.GetValue('StatusCode') as tjsonnumber).Value + ' - '
                  + (response.GetValue('StatusText') as TJSONString).Value);
              end;
            finally
              response.free;
            end
          else
            raise Exception.Create('Database refused login for table ' +
              TableName);
        end;
      finally
        Request.free;
      end;
    finally
      Database.ProgressAddDoneSteps(1);
    end;
  end
  else
    raise Exception.Create('Database needed on ' + Name);
end;

procedure TOlfTDSTable.Step03LocalToRemote;
var
  DB: TFDConnection;
  qry: tfdquery;
  Request: TJSONObject;
  item: TJSONObject;
  jsrec: TJSONObject;
  ChangedField, NoSeqField: string;
  i: integer;
  response: TJSONObject;
  UpdatedFields, WhereFields: string;
  tabUpdatedFields, tabWhereFields: array of variant;
  jsv: tjsonvalue;
  valkeys: string;
  valkeyi: integer;
  jsa: tjsonarray;
  NewNoSeq: integer;
  Base64Encoding: TBase64Encoding;
begin
  if FSessionID.IsEmpty then
    raise Exception.Create
      ('Open a session before trying to send local changes to remote database.');
  if FTableName.IsEmpty then
    raise Exception.Create
      ('Table name is empty. No synchronization available.');
  if not assigned(Database) then
    raise Exception.Create('Database needed for table "' + FTableName + '".');
  if Database.LocalConnectionDefName.IsEmpty then
    raise Exception.Create('No local connection available.');
  ChangedField := getChangedFieldName;
  if ChangedField.IsEmpty then
    raise Exception.Create
      ('Please indicate what is your "sync_changed" field name in table "' +
      FTableName + '".');
  NoSeqField := getNoSeqFieldName;
  if NoSeqField.IsEmpty then
    raise Exception.Create
      ('Please indicate what is your "sync_noseq" field name in table "' +
      FTableName + '".');
  Database.ProgressAddMaxSteps(1);
  try
    DB := TFDConnection.Create(nil);
    try
      // connexion au pool de connexions FireDAC
      DB.Params.Clear;
      DB.ConnectionDefName := Database.LocalConnectionDefName;
      DB.Open;
      qry := tfdquery.Create(nil);
      try
        qry.Connection := DB;
        // Parcourir les enregistrement ayant été modifiés depuis la synchro
        // précédente.
        qry.Open('select * from ' + FTableName + ' where (' +
          ChangedField + '=1)');
        Database.ProgressAddMaxSteps(qry.RecordCount);
        while not qry.Eof do
        begin
          // sortie de boucle si la fermeture du thread a été demandée
          // (par exemple en fermeture de programme ou si un mécanisme
          // d'annulation de synchro est mis en place)
          if FForceSynchroStop then
            Exit;
          try
            // si thread principal CheckTerminated déclenche une exception
            if tthread.CheckTerminated then
              Exit;
          except
          end;

          // Mise à jour des valeurs de Sync_* depuis les clés étrangères locales de la table
          if assigned(FForeignKeyList) then
          begin
            qry.Edit;
            for i := 0 to FForeignKeyList.count - 1 do
              case qry.FieldDefs.Find(FForeignKeyList[i].FLocalKeyFieldName)
                .DataType of
                TFieldType.ftSmallint, TFieldType.ftInteger, TFieldType.ftWord,
                  TFieldType.ftAutoInc, TFieldType.ftLargeint,
                  TFieldType.ftByte:
                  qry.fieldbyname(FForeignKeyList[i].FSyncLocalKeyFieldName)
                    .AsLargeInt :=
                    DB.ExecSQLScalar('select ' + FForeignKeyList[i]
                    .FSyncForeignKeyFieldName + ' from ' + FForeignKeyList[i]
                    .FForeignTableName + ' where ' + FForeignKeyList[i]
                    .FForeignKeyFieldName + '=:id',
                    [FForeignKeyList[i].FLocalKeyFieldName])
              else
                qry.fieldbyname(FForeignKeyList[i].FSyncLocalKeyFieldName)
                  .AsString :=
                  DB.ExecSQLScalar('select ' + FForeignKeyList[i]
                  .FSyncForeignKeyFieldName + ' from ' + FForeignKeyList[i]
                  .FForeignTableName + ' where ' + FForeignKeyList[i]
                  .FForeignKeyFieldName + '=:id',
                  [FForeignKeyList[i].FLocalKeyFieldName]);
                // TODO : bloquer éventuellement sur les types de champs non gérés en filtrant tous les types String
              end;
            qry.Post;
          end;

          // Stockage des infos de l'enregistrement en cours sous forme
          // d'objet JSON
          item := TJSONObject.Create;
          try
            for i := 0 to qry.FieldCount - 1 do
              // Field2JSON : code similaire côté serveur et client
              if qry.fields[i].IsNull then
                item.AddPair(qry.fields[i].FieldName, TJSONNull.Create)
              else if isBase64Field(qry.fields[i]) then
              begin // champ binaire, blob ou autre à encoder en base 64
                Base64Encoding := TBase64Encoding.Create;
                try
                  item.AddPair(qry.fields[i].FieldName,
                    Base64Encoding.encodebytestostring(qry.fields[i].AsBytes));
                  // if (qry.fields[i] is tblobfield) then
                  // jsrec.addpair(qry.fields[i].FieldName,
                  // Base64Encoding.encodebytestostring
                  // (tblobfield(qry.fields[i]).Value))
                  // else if (qry.fields[i] is tbinaryfield) then
                  // jsrec.addpair(qry.fields[i].FieldName,
                  // Base64Encoding.encodebytestostring
                  // (qry.fields[i].AsBytes))
                  // else
                  // raise exception.Create('Unknown blob field type');
                finally
                  Base64Encoding.free;
                end;
              end
              else
                case qry.fields[i].DataType of
                  // champs entiers signés ou pas
                  TFieldType.ftSmallint, TFieldType.ftInteger,
                    TFieldType.ftWord, TFieldType.ftAutoInc,
                    TFieldType.ftLargeint, TFieldType.ftByte:
                    item.AddPair(qry.fields[i].FieldName,
                      tjsonnumber.Create(qry.fields[i].asinteger));
                  // champs booléens
                  TFieldType.ftBoolean:
                    item.AddPair(qry.fields[i].FieldName,
                      TJSONBool.Create(qry.fields[i].AsBoolean));
                else // autres types de champs
                  item.AddPair(qry.fields[i].FieldName, qry.fields[i].AsString);
                end;
            Request := TJSONObject.Create;
            try
              Request.AddPair('TDSTableName', TableName);
              Request.AddPair('TDSSessionID', FSessionID);
              Request.AddPair('TDSData', item.tojson);
              Request.AddPair('TDSNoSeqField', NoSeqField);
              // On fournit les clés au serveur qui n'a aucune idée de la structure de la base de données
              jsa := tjsonarray.Create;
              try
                for i := 0 to FKeyList.count - 1 do
                  jsa.Add(TJSONObject.Create.AddPair('LocalFieldName',
                    FKeyList[i].FFieldName).AddPair('SyncFieldName',
                    FKeyList[i].FSyncFieldName));
                Request.AddPair('TDSKeys', jsa.tojson);
              finally
                jsa.free;
              end;
              response := Database.SendRemoteRequest('loc2srv', Request);
              if assigned(response) then
                try
                  if ((response.GetValue('StatusCode') as tjsonnumber)
                    .AsInt = 200) then
                  begin
                    // Nouveau numéro de séquence
                    UpdatedFields := ',' + NoSeqField + '=:nsf';
                    setlength(tabUpdatedFields, 1);
                    // Traitement de la réponse et application des clés distantes à modifier éventuellement
                    if response.TryGetValue<TJSONObject>('result', jsrec) and
                      jsrec.TryGetValue<integer>(NoSeqField, NewNoSeq) then
                    begin
                      tabUpdatedFields[0] := NewNoSeq;
                      // Nouvelles valeurs de champ "sync_xxx" pour la clé primaire + WHERE du UPDATE
                      WhereFields := '';
                      setlength(tabWhereFields, 0);
                      for i := 0 to FKeyList.count - 1 do
                      begin
                        jsv := jsrec.GetValue(FKeyList[i].FSyncFieldName);
                        if (jsv is tjsonnumber) then
                        begin
                          // champ clé numérique
                          valkeyi := (jsv as tjsonnumber).AsInt;
                          if (valkeyi <> qry.fieldbyname
                            (FKeyList[i].FSyncFieldName).asinteger) then
                          begin
                            UpdatedFields := UpdatedFields + ',' + FKeyList[i]
                              .FSyncFieldName + '=:key' + i.tostring;
                            setlength(tabUpdatedFields,
                              Length(tabUpdatedFields) + 1);
                            tabUpdatedFields[Length(tabUpdatedFields) - 1]
                              := valkeyi;
                          end;
                        end
                        else if (jsv is TJSONString) then
                        begin
                          // champ clé alpha
                          valkeys := (jsv as TJSONString).Value;
                          if (valkeys <> qry.fieldbyname
                            (FKeyList[i].FSyncFieldName).AsString) then
                          begin
                            UpdatedFields := UpdatedFields + ',' + FKeyList[i]
                              .FSyncFieldName + '=:key' + i.tostring;
                            setlength(tabUpdatedFields,
                              Length(tabUpdatedFields) + 1);
                            tabUpdatedFields[Length(tabUpdatedFields) - 1]
                              := valkeys;
                          end;
                        end
                        else
                          // champ clé de format inconnu ou non géré
                          raise Exception.Create
                            ('Key field type not recognized.');
                        // Mise à jour de la sélection pour le UPDATE
                        if not WhereFields.IsEmpty then
                          WhereFields := WhereFields + ' and ';
                        WhereFields := WhereFields + '(' + FKeyList[i]
                          .FFieldName + '=:w' + i.tostring + ')';
                        setlength(tabWhereFields, Length(tabWhereFields) + 1);
                        tabWhereFields[Length(tabWhereFields) - 1] :=
                          qry.fieldbyname(FKeyList[i].FFieldName).AsString;
                      end;
                      try
                        DB.ExecSQL('update ' + FTableName + ' set ' +
                          ChangedField + '=0' + UpdatedFields + ' where ' +
                          WhereFields, tabUpdatedFields + tabWhereFields)
                      except
                        // Il y a eu un couac côté serveur. Ce cas ne devrait
                        // jamais se produire puisqu'il sous entend que le
                        // serveur se mélange entre les différents appels
                        // qu'il reçoit.
                        raise Exception.Create('Loc2Srv sync for table "' +
                          FTableName + '" has crashed.');
                      end;
                      // TODO : impacter les champs sync_* des tables ayant les clés de celle-ci en foreign key
                    end;
                  end;
                finally
                  response.free;
                end;
            finally
              Request.free;
            end;
          finally
            item.free;
            Database.ProgressAddDoneSteps(1);
          end;
          qry.next;
        end;
      finally
        qry.free;
      end;
    finally
      DB.free;
    end;
  finally
    Database.ProgressAddDoneSteps(1);
  end;
end;

procedure TOlfTDSTable.Step02RemoteToLocal;
var
  ChangedField, NoSeqField: string;
  DB: TFDConnection;
  LastLocalNoSeq: integer;
  LastLocalNoSeqNbRec: Cardinal;
  Request: TJSONObject;
  response: TJSONObject;
  jsa: tjsonarray;
  jsv, jsv2: tjsonvalue;
  item: TJSONObject;
  i: integer;
  Table: TFDTable;
  KeyFields: string;
  KeyValues: array of variant;
  Base64Encoding: TBase64Encoding;
begin
  if FSessionID.IsEmpty then
    raise Exception.Create
      ('Open a session before trying to send local changes to remote database.');
  if FTableName.IsEmpty then
    raise Exception.Create
      ('Table name is empty. No synchronization available.');
  if not assigned(Database) then
    raise Exception.Create('Database needed for table "' + FTableName + '".');
  if Database.LocalConnectionDefName.IsEmpty then
    raise Exception.Create('No local connection available.');
  ChangedField := getChangedFieldName;
  if ChangedField.IsEmpty then
    raise Exception.Create
      ('Please indicate what is your "sync_changed" field name in table "' +
      FTableName + '".');
  NoSeqField := getNoSeqFieldName;
  if NoSeqField.IsEmpty then
    raise Exception.Create
      ('Please indicate what is your "sync_noseq" field name in table "' +
      FTableName + '".');
  Database.ProgressAddMaxSteps(1);
  try
    DB := TFDConnection.Create(nil);
    try
      DB.Params.Clear;
      DB.ConnectionDefName := Database.LocalConnectionDefName;
      DB.Open;
      try
        LastLocalNoSeq := DB.ExecSQLScalar('select ' + NoSeqField + ' from ' +
          FTableName + ' order by ' + NoSeqField + ' desc limit 0,1');
      except
        LastLocalNoSeq := 0;
      end;
      try
        LastLocalNoSeqNbRec := DB.ExecSQLScalar('select count(*) from ' +
          FTableName + ' where ' + NoSeqField + '=' + LastLocalNoSeq.tostring);
      except
        LastLocalNoSeqNbRec := 0;
      end;
      Request := TJSONObject.Create;
      try
        Request.AddPair('TDSTableName', TableName);
        Request.AddPair('TDSSessionID', FSessionID);
        Request.AddPair('TDSChangedField', ChangedField);
        Request.AddPair('TDSNoSeqField', NoSeqField);
        Request.AddPair('TDSLastNoSeq', tjsonnumber.Create(LastLocalNoSeq));
        Request.AddPair('TDSLastNoSeqNbRec',
          tjsonnumber.Create(LastLocalNoSeqNbRec));
        response := Database.SendRemoteRequest('srv2loc', Request);
        if assigned(response) then
          try
            if ((response.GetValue('StatusCode') as tjsonnumber).AsInt = 200)
              and response.TryGetValue('items', jsa) and assigned(jsa) and
              (jsa.count > 0) then
            begin
              Table := TFDTable.Create(self);
              Table.Connection := DB;
              Table.TableName := FTableName;
              Table.Open;
              try
                Database.ProgressAddMaxSteps(jsa.count);
                for jsv in jsa do
                begin
                  // sortie de boucle si la fermeture du thread a été demandée
                  // (par exemple en fermeture de programme ou si un mécanisme
                  // d'annulation de synchro est mis en place)
                  if FForceSynchroStop then
                    Exit;
                  try
                    // si thread principal CheckTerminated déclenche une exception
                    if tthread.CheckTerminated then
                      Exit;
                  except
                  end;

                  // récupération de l'enregistrement en cours de la liste
                  if (jsv is TJSONObject) then
                    item := TJSONObject(jsv)
                  else
                    raise Exception.Create('Format JSON incohérent.');
                  // remplissage des clés pour recherche de l'enregistrement
                  KeyFields := '';
                  setlength(KeyValues, 0);
                  for i := 0 to FKeyList.count - 1 do
                  begin
                    if not KeyFields.IsEmpty then
                      KeyFields := KeyFields + ';';
                    KeyFields := KeyFields + FKeyList[i].FSyncFieldName;
                    // champ synchro local
                    setlength(KeyValues, Length(KeyValues) + 1);
                    jsv2 := item.GetValue(FKeyList[i].FFieldName);
                    // valeur sur le serveur
                    if jsv2 is tjsonnumber then
                      KeyValues[Length(KeyValues) - 1] :=
                        (jsv2 as tjsonnumber).AsInt
                    else if jsv2 is TJSONString then
                      KeyValues[Length(KeyValues) - 1] :=
                        (jsv2 as TJSONString).Value
                    else
                      raise Exception.Create('Unknown key field type ! (' +
                        FTableName + '.' + Table.fields[i].FieldName + ')');
                  end;

                  // opération en fonction de l'existence de l'élément trouvé à partir des clés du serveur
                  if (Table.Locate(KeyFields, KeyValues)) then
                    Table.Edit
                  else
                    Table.insert;

                  // Remplissage des champs de la table à partir des données de l'objet reçu
                  for i := 0 to Table.fields.count - 1 do
                  begin
                    if isFieldInKeyList(Table.fields[i].FieldName) or
                      isFieldInForeignKeyList(Table.fields[i].FieldName) then
                      // clé locale : à ne pas toucher, devra être écrasé uniquement si clé étrangère à partir de la récupération de la valeur en cloud
                      jsv2 := nil
                    else if isSyncFieldInKeyList(Table.fields[i].FieldName) then
                      // clé primaire provenant du serveur, on écrase la valeur "sync" par la clé locale côté serveur
                      jsv2 := item.GetValue
                        (getFieldFromSyncField(Table.fields[i].FieldName))
                    else if isSyncFieldInForeignKeyList
                      (Table.fields[i].FieldName) then
                      // clé étrangère provenant du serveur, on écrase la valeur "sync" par la clé locale côté serveur
                      jsv2 := item.GetValue
                        (getForeignFieldFromForeignSyncField(Table.fields[i]
                        .FieldName))
                    else
                      jsv2 := item.GetValue(Table.fields[i].FieldName);
                    // Stockage de la valeur s'il y en a une à stocker
                    if assigned(jsv2) then
                      if (jsv2 is tjsonnumber) then
                        Table.fields[i].AsLargeInt :=
                          (jsv2 as tjsonnumber).AsInt64
                      else if (jsv2 is TJSONBool) then
                        Table.fields[i].AsBoolean := (jsv2 as TJSONBool)
                          .AsBoolean
                      else if (jsv2 is TJSONNull) then
                        Table.fields[i].Clear
                      else if isBase64Field(Table.fields[i]) then
                      begin
                        Base64Encoding := TBase64Encoding.Create;
                        try
                          Table.fields[i].AsBytes :=
                            Base64Encoding.DecodeStringToBytes
                            ((jsv2 as TJSONString).Value);
                        finally
                          Base64Encoding.free;
                        end;
                      end
                      else if (jsv2 is TJSONString) then
                        Table.fields[i].AsString := (jsv2 as TJSONString).Value
                      else
                        raise Exception.Create('Unknown field type ! (' +
                          FTableName + '.' + Table.fields[i].FieldName + ')');
                  end;

                  // Mise à jour des champs "clés étrangères" locales à partir des clés étrangères Sync_*
                  if assigned(FForeignKeyList) then
                    for i := 0 to FForeignKeyList.count - 1 do
                      case Table.FieldDefs.Find
                        (FForeignKeyList[i].FLocalKeyFieldName).DataType of
                        TFieldType.ftSmallint, TFieldType.ftInteger,
                          TFieldType.ftWord, TFieldType.ftAutoInc,
                          TFieldType.ftLargeint, TFieldType.ftByte:
                          Table.fieldbyname
                            (FForeignKeyList[i].FLocalKeyFieldName).AsLargeInt
                            := DB.ExecSQLScalar
                            ('select ' + FForeignKeyList[i].FForeignKeyFieldName
                            + ' from ' + FForeignKeyList[i].FForeignTableName +
                            ' where ' + FForeignKeyList[i]
                            .FSyncForeignKeyFieldName + '=:id',
                            [FForeignKeyList[i].FSyncLocalKeyFieldName])
                      else
                        Table.fieldbyname(FForeignKeyList[i].FLocalKeyFieldName)
                          .AsString :=
                          DB.ExecSQLScalar('select ' + FForeignKeyList[i]
                          .FForeignKeyFieldName + ' from ' + FForeignKeyList[i]
                          .FForeignTableName + ' where ' + FForeignKeyList[i]
                          .FSyncForeignKeyFieldName + '=:id',
                          [FForeignKeyList[i].FSyncLocalKeyFieldName]);
                        // TODO : bloquer éventuellement sur les types de champs non gérés en filtrant tous les types String
                      end;

                  // Mise à jour de l'enregistrement
                  Table.Post;
                  Database.ProgressAddDoneSteps(1);
                end;
              finally
                Table.free;
              end;
            end;
          finally
            response.free;
          end;
      finally
        Request.free;
      end;
    finally
      DB.free;
    end;
  finally
    Database.ProgressAddDoneSteps(1);
  end;
end;

procedure TOlfTDSTable.Step04CloseSession;
var
  Request, response: TJSONObject;
begin
  if assigned(Database) then
  begin
    Database.ProgressAddMaxSteps(1);
    try
      Request := TJSONObject.Create;
      try
        Request.AddPair('TDSTableName', TableName);
        Request.AddPair('TDSSessionID', FSessionID);
        if assigned(onSessionClose) then
          tthread.synchronize(nil,
            procedure
            begin
              onSessionClose(Request);
            end)
        else if assigned(Database.onSessionClose) then
          tthread.synchronize(nil,
            procedure
            begin
              Database.onSessionClose(Request);
            end);
        try
          response := Database.SendRemoteRequest('logout', Request);
        finally
          if assigned(response) then
            try
              if not((response.GetValue('StatusCode') as tjsonnumber)
                .AsInt = 200) then
              begin
                FSessionID := '';
                raise Exception.Create('Synchro refused. Error HTTP ' +
                  (response.GetValue('StatusCode') as tjsonnumber).Value + ' - '
                  + (response.GetValue('StatusText') as TJSONString).Value);
              end;
            finally
              response.free;
            end
          else
            raise Exception.Create('Database refused login for table ' +
              TableName);
        end;
      finally
        Request.free;
      end;
    finally
      Database.ProgressAddDoneSteps(1);
    end;
  end
  else
    raise Exception.Create('Database needed on ' + Name);
end;

procedure TOlfTDSTable.StopSynchro;
begin
  // TODO : peut-être protéger FForceSynchroStop avec un Mutex en écriture et lecture
  FForceSynchroStop := true;
end;

{ TOlfTDSForeignKey }

constructor TOlfTDSForeignKey.Create(ALocalKeyField: TOlfTDSField;
AForeignTableName: string; AForeignKeyField: TOlfTDSField);
begin
  inherited Create;

  if assigned(ALocalKeyField) then
  begin
    FLocalKeyFieldName := ALocalKeyField.FFieldName;
    FSyncLocalKeyFieldName := ALocalKeyField.FSyncFieldName;
    ALocalKeyField.free;
  end
  else
    raise TOlfTDSException.Create(TOlfTDSExceptionType.LocalKeyUnknown,
      'ALocalKeyField is nil');

  FForeignTableName := AForeignTableName.trim;
  if FForeignTableName.IsEmpty then
    raise TOlfTDSException.Create(TOlfTDSExceptionType.ForeignTableUnknown,
      'AForeignTableName is empty');

  if assigned(AForeignKeyField) then
  begin
    FForeignKeyFieldName := AForeignKeyField.FFieldName;
    FSyncForeignKeyFieldName := AForeignKeyField.FSyncFieldName;
    AForeignKeyField.free;
  end
  else
    raise TOlfTDSException.Create(TOlfTDSExceptionType.ForeignKeyUnknown,
      'AForeignKeyField is nil');
end;

{ TOlfTDSException }

constructor TOlfTDSException.Create(AExceptionType: TOlfTDSExceptionType;
Msg: string);
begin
  inherited Create(Msg);
  FExceptionType := AExceptionType;
end;

end.
