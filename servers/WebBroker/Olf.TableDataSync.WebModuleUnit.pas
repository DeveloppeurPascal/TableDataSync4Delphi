unit Olf.TableDataSync.WebModuleUnit;

interface

uses
  System.SysUtils,
  System.Classes,
  Web.HTTPApp,
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
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  Data.DB,
  FireDAC.Comp.DataSet;

const
  // Version de l'API gérée par ce fichier
  COlfTDSAPIVersion = 20211111;

type
  TOlfTDSWebModule = class(TWebModule)
    procedure APISrv2Loc(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: boolean);
    procedure APILoc2Srv(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: boolean);
    procedure APILogin(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: boolean);
    procedure APILogout(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: boolean);
    procedure OlfTDSWebModule_404PageNotFoundAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: boolean);
  private
    function isAPIVersionOk(AAPIVersion: integer): boolean;
  protected
    /// <summary>
    /// Retourne la valeur d'un paramètre reçu en POST sous forme de chaîne
    /// </summary>
    function getPostValueAsString(Request: TWebRequest;
      FieldName: string): string;

    /// <summary>
    /// Retourne la valeur d'un paramètre reçu en POST sous forme d'entier signé
    /// </summary>
    function getPostValueAsInteger(Request: TWebRequest;
      FieldName: string): integer;

    /// <summary>
    /// Retourne la valeur d'un paramètre reçu en POST sous forme d'entier non signé
    /// </summary>
    function getPostValueAsCardinal(Request: TWebRequest; FieldName: string)
      : cardinal;
  public
    /// <summary>
    /// Déclenché lors de la connexion d'un client pour une synchronisation de base de données.
    /// Permet de refuser la connexion et donc l'opération de synchronisation.
    /// </summary>
    /// Default : False
    function LoginCheck(Request: TWebRequest): boolean; virtual;

    /// <summary>
    /// Retourne la chaîne de connexion à la base de données à utiliser selon les infos d'ouverture de session transmises par le client
    /// Appelée une fois l'autorisation de connexion validée par LoginCheck() (avec les mêmes paramètres)
    /// </summary>
    /// Default : empty string
    function GetConnectionDefName(Request: TWebRequest): string; virtual;

    /// <summary>
    /// Check if the table can be synchronized from the Server to the Client
    /// </summary>
    /// Default : True
    function isTableSrv2LocOk(ATableName: string): boolean; virtual;

    /// <summary>
    /// Check if the table can be synchronized from the Client to the Server
    /// </summary>
    /// Default : True
    function isTableLoc2SrvOk(ATableName: string): boolean; virtual;

    /// <summary>
    /// Déclenché lors de la fermeture d'une session de synchronisation pour une table.
    /// </summary>
    /// Default : does nothing
    procedure Logout(Request: TWebRequest); virtual;
  end;

  // var
  // WebModuleClass: TComponentClass = TOlfTDSWebModule;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}
{$R *.dfm}

uses
  System.json,
  Web.ReqMulti,
  System.Generics.Collections,
  System.SyncObjs,
  System.NetEncoding;

type
  TOlfTDSSessionID = string;

  TOlfTDSSession = class
  private
    MUTEX: TMutex;
    FID: string;
    FConnectionDefName: string;
    FTableName: string;
    FDB: TFDConnection;
    FB64Fields: string;
    FServeurNoSeq: integer;
    procedure SetID(const Value: string);
    procedure SetConnectionDefName(const Value: string);
    function GetConnectionDefName: string;
    function GetID: string;
    procedure SetTableName(const Value: string);
    function GetTableName: string;
    procedure SetB64Fields(const Value: string);
    function GetB64Fields: string;
    procedure SetServeurNoSeq(const Value: integer);
    function GetServeurNoSeq: integer;
  public
    property ID: string read GetID write SetID;
    property ConnectionDefName: string read GetConnectionDefName
      write SetConnectionDefName;
    property TableName: string read GetTableName write SetTableName;
    property B64Fields: string read GetB64Fields write SetB64Fields;
    property ServeurNoSeq: integer read GetServeurNoSeq write SetServeurNoSeq;
    function GetDBConnection: TFDConnection;
    function isB64Field(AFieldName: string): boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TOlfTDSSessionList = class(TObjectDictionary<TOlfTDSSessionID,
    TOlfTDSSession>)
  private
    MUTEX: TMutex;
  protected
    function GenerateUniqID(Nb: word = 16): string;
  public
    function CreateAndAddSession: TOlfTDSSession;
    function AddSession(ASession: TOlfTDSSession): boolean;
    function GetSession(ASessionID: TOlfTDSSessionID): TOlfTDSSession;
    procedure RemoveSession(ASessionID: TOlfTDSSessionID); overload;
    procedure RemoveSession(ASession: TOlfTDSSession); overload;
    constructor Create;
    destructor Destroy; override;
  end;

var
  SessionList: TOlfTDSSessionList;

function TOlfTDSWebModule.getPostValueAsCardinal(Request: TWebRequest;
  FieldName: string): cardinal;
var
  idx: integer;
begin
  idx := Request.ContentFields.IndexOfName(FieldName);
  if (idx >= 0) then
    result := cardinal.Parse(Request.ContentFields.ValueFromIndex[idx])
  else
    raise exception.Create('No ' + FieldName + ' in the request.');
end;

function TOlfTDSWebModule.getPostValueAsInteger(Request: TWebRequest;
  FieldName: string): integer;
var
  idx: integer;
begin
  idx := Request.ContentFields.IndexOfName(FieldName);
  if (idx >= 0) then
    result := Request.ContentFields.ValueFromIndex[idx].ToInteger
  else
    raise exception.Create('No ' + FieldName + ' in the request.');
end;

function TOlfTDSWebModule.getPostValueAsString(Request: TWebRequest;
  FieldName: string): string;
var
  idx: integer;
begin
  idx := Request.ContentFields.IndexOfName(FieldName);
  if (idx >= 0) then
    result := Request.ContentFields.ValueFromIndex[idx].Trim
  else
    raise exception.Create('No ' + FieldName + ' in the request.');
end;

function TOlfTDSWebModule.isAPIVersionOk(AAPIVersion: integer): boolean;
begin
  result := (COlfTDSAPIVersion = AAPIVersion);
end;

function TOlfTDSWebModule.isTableLoc2SrvOk(ATableName: string): boolean;
begin
  result := not ATableName.IsEmpty;
end;

function TOlfTDSWebModule.isTableSrv2LocOk(ATableName: string): boolean;
begin
  result := not ATableName.IsEmpty;
end;

function TOlfTDSWebModule.LoginCheck(Request: TWebRequest): boolean;
begin
  result := false;
end;

procedure TOlfTDSWebModule.Logout(Request: TWebRequest);
begin
  // nothing to do there
end;

procedure TOlfTDSWebModule.OlfTDSWebModule_404PageNotFoundAction
  (Sender: TObject; Request: TWebRequest; Response: TWebResponse;
  var Handled: boolean);
begin
{$IFDEF DEBUG}
  writeln('**********');
  writeln('* réponse par défaut : 404 File Not found');
  writeln('**********');
{$ENDIF}
  Handled := true;
  Response.StatusCode := 404;
end;

function TOlfTDSWebModule.GetConnectionDefName(Request: TWebRequest): string;
begin
  result := '';
end;

procedure TOlfTDSWebModule.APILogout(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: boolean);
var
  jso: tjsonobject;
  MultiReq: tmultipartcontentparser;
  InDebugMode: boolean;
  InTableName: string;
  InParamOk: boolean;
  Session: TOlfTDSSession;
begin
  Handled := false;
{$IFDEF DEBUG}
  writeln('**********');
  writeln('* logout');
  writeln('**********');
{$ENDIF}
  // Décodage du POST
  if (tmultipartcontentparser.CanParse(Request)) then
    try
      MultiReq := tmultipartcontentparser.Create(Request);
    finally
      freeandnil(MultiReq);
    end;
  // Récupération des champs attendus
  InParamOk := true;
  try
{$IFDEF DEBUG}
    writeln('Client TDSAPIVersion=' + getPostValueAsInteger(Request,
      'TDSAPIVersion').ToString);
    writeln('Server TDSAPIVersion=' + COlfTDSAPIVersion.ToString);
{$ENDIF}
    // Si la version de ce fichier n'est pas la même que celle de la librairie cliente, on refuse la connexion
    if not isAPIVersionOk(getPostValueAsInteger(Request, 'TDSAPIVersion')) then
      raise exception.Create('Wrong TDS API Version');
  except
    InParamOk := false;
  end;
  try
    InDebugMode := (1 = getPostValueAsInteger(Request, 'TDSDebugMode'));
{$IFDEF DEBUG}
    writeln('TDSDebugMode=' + InDebugMode.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
{$IFDEF DEBUG}
    writeln('TDSSessionID=' + getPostValueAsString(Request, 'TDSSessionID'));
{$ENDIF}
    Session := SessionList.GetSession(getPostValueAsString(Request,
      'TDSSessionID'));
    if not assigned(Session) then
      raise exception.Create('Invalid session');
  except
    InParamOk := false;
  end;
  try
    InTableName := getPostValueAsString(Request, 'TDSTableName');
{$IFDEF DEBUG}
    writeln('TDSTableName=' + InTableName);
{$ENDIF}
    // TODO : s'assurer que la table existe dans la base de données
  except
    InParamOk := false;
  end;
  // Traitement des paramètres et retour de la réponse
  jso := tjsonobject.Create;
  try
    if InParamOk then
    begin
      try
        // Appel de la méthode surchargeable pour clôturer la session utilisateur
        Logout(Request);
        // Suppression de la session en cours
        SessionList.RemoveSession(Session.ID);
        // Confirmation de traitement sans erreur
        jso.addpair('error', '0');
      except
        Response.StatusCode := 500;
        jso.addpair('error', '1');
      end;
    end
    else
    begin
      Response.StatusCode := 500;
      jso.addpair('error', '2');
    end;
  finally
    // On retourne le résultat généré au client.
    Handled := true;
    Response.ContentType := 'application/json';
    Response.ContentEncoding := 'UTF-8';
    Response.CustomHeaders.Add('Access-Control-Allow-Origin=*');
    Response.ContentStream := tstringstream.Create(jso.tojson, tencoding.UTF8);
{$IFDEF DEBUG}
    writeln(jso.tojson);
{$ENDIF}
    freeandnil(jso);
  end;
end;

procedure TOlfTDSWebModule.APILoc2Srv(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: boolean);

  function isInKeyFields(AFieldName, AKeyFields: string): boolean;
  begin
    result := AKeyFields.Contains(',' + AFieldName + ',');
  end;

var
  jso, jsrec: tjsonobject;
  jsa: TJSONArray;
  jsv, jsv2: TJSONValue;
  i: integer;
  qry: tfdquery;
  MultiReq: tmultipartcontentparser;
  InDebugMode: boolean;
  InTableName: string;
  InNoSeqField: string;
  InParamOk: boolean;
  DB: TFDConnection;
  inData: tjsonobject;
  inKeys: TJSONArray;
  Session: TOlfTDSSession;
  ServeurNoSeq: integer;
  Table: TFDTable;
  KeyFields: string;
  KeyValues: array of variant;
  Base64Encoding: TBase64Encoding;
  Field: TField;
begin
  Handled := false;
{$IFDEF DEBUG}
  writeln('**********');
  writeln('* send modifs Loc2Srv');
  writeln('**********');
{$ENDIF}
{$IFDEF DEBUG}
  writeln(Request.Content);
{$ENDIF}
  // * TDSTableName : nom de la table concernée
  // * TDSSessionID : ID de la session récupéré lors du login
  // * TDSData : un objet JSON contenant l'enregistrement à traiter (en ajout ou modification)
  // * TDSNoSeqField : nom du champ stockant les numéros de séquence
  // * TDSKeys : tableau JSON des clés primaires (chaque élément étant un objet avec clé locale "LocalFieldName", clé serveur "SyncFieldName")

  // Décodage du POST
  if (tmultipartcontentparser.CanParse(Request)) then
    try
      MultiReq := tmultipartcontentparser.Create(Request);
    finally
      freeandnil(MultiReq);
    end;

  // Récupération des champs attendus
  InParamOk := true;
  try
{$IFDEF DEBUG}
    writeln('Client TDSAPIVersion=' + getPostValueAsInteger(Request,
      'TDSAPIVersion').ToString);
    writeln('Server TDSAPIVersion=' + COlfTDSAPIVersion.ToString);
{$ENDIF}
    // Si la version de ce fichier n'est pas la même que celle de la librairie cliente, on refuse la connexion
    if not isAPIVersionOk(getPostValueAsInteger(Request, 'TDSAPIVersion')) then
      raise exception.Create('Wrong TDS API Version');
  except
    InParamOk := false;
  end;
  try
    InDebugMode := (1 = getPostValueAsInteger(Request, 'TDSDebugMode'));
{$IFDEF DEBUG}
    writeln('TDSDebugMode=' + InDebugMode.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
{$IFDEF DEBUG}
    writeln('TDSSessionID=' + getPostValueAsString(Request, 'TDSSessionID'));
{$ENDIF}
    Session := SessionList.GetSession(getPostValueAsString(Request,
      'TDSSessionID'));
    if not assigned(Session) then
      raise exception.Create('Invalid session');
  except
    InParamOk := false;
  end;
  try
    InTableName := getPostValueAsString(Request, 'TDSTableName');
{$IFDEF DEBUG}
    writeln('TDSTableName=' + InTableName);
{$ENDIF}
    // TODO : s'assurer que la table existe dans la base de données

    // S'assurer que la table est bien celle qui a été passée lors de l'ouverture de session
    if (Session.TableName <> InTableName) then
      raise exception.Create
        ('Wrong table for this session. Open a new session to synchronize this one !');

    // S'assurer que la table est autorisée dans le sens Loc2Srv
    if not isTableLoc2SrvOk(InTableName) then
      raise exception.Create('Synchro table ' + InTableName +
        ' not authorized from client to server.');
  except
    InParamOk := false;
  end;
  try
    InNoSeqField := getPostValueAsString(Request, 'TDSNoSeqField');
{$IFDEF DEBUG}
    writeln('TDSNoSeqField=' + InNoSeqField);
{$ENDIF}
    if InNoSeqField.IsEmpty then
      raise exception.Create('Empty no seq field.');
    // TODO : s'assurer que le champ est dans la table
  except
    InParamOk := false;
  end;
  try
    try
      inData := tjsonobject.ParseJSONValue(getPostValueAsString(Request,
        'TDSData')) as tjsonobject;
    except
      inData := nil;
    end;
    if not assigned(inData) then
      raise exception.Create('Missing TDSData parameter');
{$IFDEF DEBUG}
    writeln('TDSData=' + inData.tojson);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
    try
      inKeys := tjsonobject.ParseJSONValue(getPostValueAsString(Request,
        'TDSKeys')) as TJSONArray;
    except
      inKeys := nil;
    end;
    if not assigned(inKeys) then
      raise exception.Create('Missing TDSKeys parameter');
{$IFDEF DEBUG}
    writeln('TDSKeys=' + inKeys.tojson);
{$ENDIF}
  except
    InParamOk := false;
  end;

  // Traitement des paramètres et retour de la réponse
  jso := tjsonobject.Create;
  try
    if InParamOk then
      try
        DB := Session.GetDBConnection;
        try
          if not assigned(DB) then
            raise exception.Create('DB not initialized.');
          if not DB.Connected then
            DB.Open;
          Table := TFDTable.Create(nil);
          try
            Table.Connection := DB;
            Table.TableName := Session.TableName;
            Table.Open;

            // Récupération du numéro de séquence actuel
            if (Session.ServeurNoSeq < 1) then
            begin
              try
                ServeurNoSeq := DB.ExecSQLScalar('select ' + InNoSeqField +
                  ' from ' + InTableName + ' order by ' + InNoSeqField +
                  ' desc limit 0,1');
              except // si la table est vide
                ServeurNoSeq := 0;
              end;
              // On passe sur la séquence suivante (à noter que ce programme peut avoir
              // des anomalies dans le cas de synchro de plusieurs clients en
              // simultané : le numéro de séquence peut être le même comme on peut en
              // louper un et il est donc nécessaire de s'assurer que la numérotation
              // se fait correctement et surtout que le nombre d'enregistrements par
              // séquence est le même sur chaque client et le serveur lors des synchros
              // descendantes (serveur vers local)).
              inc(ServeurNoSeq);
              Session.ServeurNoSeq := ServeurNoSeq;
            end
            else // La session a déjà un numéro de séquence attribué, on s'en sert
              ServeurNoSeq := Session.ServeurNoSeq;

            // remplissage des clés pour recherche de l'enregistrement
            KeyFields := ''; // champs clé
            setlength(KeyValues, 0);
            // valeurs des champs sync_* correspondant à la clé locale côté serveur
            for i := 0 to inKeys.count - 1 do
            begin
              // Champ clé local
              if not KeyFields.IsEmpty then
                KeyFields := KeyFields + ';';
              KeyFields := KeyFields +
                ((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                as tjsonstring).Value;
              // Valeur de la clé côté serveur (=> contenu des champs sync_*)
              setlength(KeyValues, Length(KeyValues) + 1);
              jsv2 := inData.GetValue
                (((inKeys[i] as tjsonobject).GetValue('SyncFieldName')
                as tjsonstring).Value);
              if jsv2 is tjsonnumber then
                KeyValues[Length(KeyValues) - 1] := (jsv2 as tjsonnumber).AsInt
              else if jsv2 is tjsonstring then
                KeyValues[Length(KeyValues) - 1] := (jsv2 as tjsonstring).Value
              else
                raise exception.Create('Unknown key field type ! (' +
                  InTableName + '.' + Table.fields[i].FieldName + ')');
            end;

            // opération en fonction de l'existence de l'élément trouvé à partir des clés du serveur
            if (Table.Locate(KeyFields, KeyValues)) then
              Table.edit
            else
              Table.insert;

            // En insertion on alimente les clés locales à partir des champs Sync_* s'ils sont renseignés
            if (Table.State = TDataSetState.dsInsert) then
              for i := 0 to inKeys.count - 1 do
              begin
                // Lecture de la valeur attachée au champ Sync_* de cette clé
                jsv2 := inData.GetValue
                  (((inKeys[i] as tjsonobject).GetValue('SyncFieldName')
                  as tjsonstring).Value);
                if (jsv2 is tjsonnumber) then
                  // C'est une valeur numérique on écrase la clé locale avec la clé serveur prérenseignée côté client
                  Table.fieldbyname
                    (((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                    as tjsonstring).Value).AsLargeInt :=
                    (jsv2 as tjsonnumber).AsInt64
                else if (jsv2 is tjsonstring) and
                  (not(jsv2 as tjsonstring).Value.Trim.IsEmpty) then
                  // C'est une valeur alpha on écrase la clé locale avec la clé serveur prérenseignée côté client
                  // (si elle est remplie)
                  Table.fieldbyname
                    (((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                    as tjsonstring).Value).AsString :=
                    (jsv2 as tjsonstring).Value
                else
                begin
                  // Dans les autres cas, on tente de prendre la même clé que sur le client
                  // (uniquement si la clé est en alpha)
                  jsv2 := inData.GetValue
                    (((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                    as tjsonstring).Value);
                  if (jsv2 is tjsonstring) then
                    // C'est une valeur alpha on écrase la clé locale avec la clé serveur prérenseignée côté client
                    Table.fieldbyname
                      (((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                      as tjsonstring).Value).AsString :=
                      (jsv2 as tjsonstring).Value;
                end;
              end;

            // pour simplifier les recherches dans la liste des clés (locales)
            KeyFields := ',' + KeyFields + ',';

            // Remplissage des champs de la table à partir des données de l'objet reçu
            for i := 0 to Table.fields.count - 1 do
              if (InNoSeqField = Table.fields[i].FieldName) then
                // Initialisation du numéro de séquence en cours
                Table.fields[i].AsLargeInt := ServeurNoSeq
              else if not isInKeyFields(Table.fields[i].FieldName, KeyFields)
              then
              begin // On ne s'occupe pas des clés
                jsv2 := inData.GetValue(Table.fields[i].FieldName);

                // Stockage de la valeur s'il y en a une à stocker
                if assigned(jsv2) then
                  if (jsv2 is tjsonnumber) then
                    Table.fields[i].AsLargeInt := (jsv2 as tjsonnumber).AsInt64
                  else if (jsv2 is TJSONBool) then
                    Table.fields[i].AsBoolean := (jsv2 as TJSONBool).AsBoolean
                  else if (jsv2 is TJSONNull) then
                    Table.fields[i].Clear
                  else if Session.isB64Field(Table.fields[i].FieldName) then
                  begin
                    Base64Encoding := TBase64Encoding.Create;
                    try
                      Table.fields[i].AsBytes :=
                        Base64Encoding.DecodeStringToBytes
                        ((jsv2 as tjsonstring).Value);
                    finally
                      Base64Encoding.free;
                    end;
                  end
                  else if (jsv2 is tjsonstring) then
                    Table.fields[i].AsString := (jsv2 as tjsonstring).Value
                  else
                    raise exception.Create('Unknown field type ! (' +
                      InTableName + '.' + Table.fields[i].FieldName + ')');
              end;

            // Mise à jour de l'enregistrement
            Table.Post;

            // Remplissage de la réponse à partir des informations enregistrées
            jsrec := tjsonobject.Create;
            jsrec.addpair(InNoSeqField, tjsonnumber.Create(ServeurNoSeq));
            for i := 0 to inKeys.count - 1 do
            begin
              Field := Table.fieldbyname
                (((inKeys[i] as tjsonobject).GetValue('LocalFieldName')
                as tjsonstring).Value);
              case Field.DataType of
                // champs entiers signés ou pas
                TFieldType.ftSmallint, TFieldType.ftInteger, TFieldType.ftWord,
                  TFieldType.ftAutoInc, TFieldType.ftLargeint,
                  TFieldType.ftByte:
                  jsrec.addpair
                    (((inKeys[i] as tjsonobject).GetValue('SyncFieldName')
                    as tjsonstring).Value, tjsonnumber.Create(Field.asinteger));
              else // autres types de champs
                jsrec.addpair
                  (((inKeys[i] as tjsonobject).GetValue('SyncFieldName')
                  as tjsonstring).Value, Field.AsString);
              end;
            end;
            jso.addpair('result', jsrec);
            jso.addpair('error', '0');
          finally
            Table.free;
          end;
          DB.Close;
        finally
          // DB.free; // connexion associée à la session, ne pas la supprimer en route !
        end;
      except
        Response.StatusCode := 500;
        jso.addpair('error', '1');
      end
    else
    begin
      Response.StatusCode := 500;
      jso.addpair('error', '2');
    end;
  finally
    // On retourne le résultat généré au client.
    Handled := true;
    Response.ContentType := 'application/json';
    Response.ContentEncoding := 'UTF-8';
    Response.CustomHeaders.Add('Access-Control-Allow-Origin=*');
    Response.ContentStream := tstringstream.Create(jso.tojson, tencoding.UTF8);
{$IFDEF DEBUG}
    writeln(jso.tojson);
{$ENDIF}
    freeandnil(jso);
  end;
end;

procedure TOlfTDSWebModule.APISrv2Loc(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: boolean);
var
  jso, jsrec: tjsonobject;
  jsa: TJSONArray;
  i: integer;
  qry: tfdquery;
  MultiReq: tmultipartcontentparser;
  InDebugMode: boolean;
  InTableName: string;
  InChangedField: string;
  InNoSeqField: string;
  InLastNoSeq: integer;
  InLastNoSeqNbRec: cardinal;
  InParamOk: boolean;
  NewNoSeq: integer;
  NbRec: cardinal;
  DB: TFDConnection;
  Session: TOlfTDSSession;
  Base64Encoding: TBase64Encoding;
begin
  Handled := false;
{$IFDEF DEBUG}
  writeln('**********');
  writeln('* get modifs Srv2Loc');
  writeln('**********');
{$ENDIF}
  // * TDSTableName : nom de la table concernée
  // * TDSSessionID : ID de la session récupéré lors du login
  // * TDSChangedField : nom du champ servant à savoir si un enregistrement a été modifié ou pas côté client
  // * TDSNoSeqField : nom du champ stockant les numéros de séquence
  // * TDSLastNoSeq : Valeur de la dernière séquence locale sur la table en cours
  // * TDSLastNoSeqNbRec : nombre d'enregistrements au dernier niveau de synchro (pour comparer avec le serveur et ne pas les rapatrier s'ils sont tous là)

  // Décodage du POST
  if (tmultipartcontentparser.CanParse(Request)) then
    try
      MultiReq := tmultipartcontentparser.Create(Request);
    finally
      freeandnil(MultiReq);
    end;
  // Récupération des champs attendus
  InParamOk := true;
  try
{$IFDEF DEBUG}
    writeln('Client TDSAPIVersion=' + getPostValueAsInteger(Request,
      'TDSAPIVersion').ToString);
    writeln('Server TDSAPIVersion=' + COlfTDSAPIVersion.ToString);
{$ENDIF}
    // Si la version de ce fichier n'est pas la même que celle de la librairie cliente, on refuse la connexion
    if not isAPIVersionOk(getPostValueAsInteger(Request, 'TDSAPIVersion')) then
      raise exception.Create('Wrong TDS API Version');
  except
    InParamOk := false;
  end;
  try
    InDebugMode := (1 = getPostValueAsInteger(Request, 'TDSDebugMode'));
{$IFDEF DEBUG}
    writeln('TDSDebugMode=' + InDebugMode.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
{$IFDEF DEBUG}
    writeln('TDSSessionID=' + getPostValueAsString(Request, 'TDSSessionID'));
{$ENDIF}
    Session := SessionList.GetSession(getPostValueAsString(Request,
      'TDSSessionID'));
    if not assigned(Session) then
      raise exception.Create('Invalid session');
  except
    InParamOk := false;
  end;
  try
    InTableName := getPostValueAsString(Request, 'TDSTableName');
{$IFDEF DEBUG}
    writeln('TDSTableName=' + InTableName);
{$ENDIF}
    // TODO : s'assurer que la table existe dans la base de données

    // S'assurer que la table est bien celle qui a été passée lors de l'ouverture de session
    if (Session.TableName <> InTableName) then
      raise exception.Create
        ('Wrong table for this session. Open a new session to synchronize this one !');

    // S'assurer que la table est autorisée dans le sens Srv2Loc
    if not isTableSrv2LocOk(InTableName) then
      raise exception.Create('Synchro table ' + InTableName +
        ' not authorized from server to client.');
  except
    InParamOk := false;
  end;
  try
    InChangedField := getPostValueAsString(Request, 'TDSChangedField');
{$IFDEF DEBUG}
    writeln('TDSChangedField=' + InChangedField);
{$ENDIF}
    if InChangedField.IsEmpty then
      raise exception.Create('Empty changed field.');
    // TODO : s'assurer que le champ est dans la table
  except
    InParamOk := false;
  end;
  try
    InNoSeqField := getPostValueAsString(Request, 'TDSNoSeqField');
{$IFDEF DEBUG}
    writeln('TDSNoSeqField=' + InNoSeqField);
{$ENDIF}
    if InNoSeqField.IsEmpty then
      raise exception.Create('Empty no seq field.');
    // TODO : s'assurer que le champ est dans la table
  except
    InParamOk := false;
  end;
  try
    InLastNoSeq := getPostValueAsInteger(Request, 'TDSLastNoSeq');
{$IFDEF DEBUG}
    writeln('TDSLastNoSeq=' + InLastNoSeq.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
    InLastNoSeqNbRec := getPostValueAsCardinal(Request, 'TDSLastNoSeqNbRec');
{$IFDEF DEBUG}
    writeln('TDSLastNoSeqNbRec=' + InLastNoSeqNbRec.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  // Traitement des paramètres et retour de la réponse
  jso := tjsonobject.Create;
  try
    if InParamOk then
    begin
      try
        DB := Session.GetDBConnection;
        try
          if not assigned(DB) then
            raise exception.Create('DB not initialized.');
          if not DB.Connected then
            DB.Open;

          // Forçage du numéro de séquence s'il n'est pas renseigné sur cette table
          // (cas de modifications faites directement au niveau du serveur)
          try
            NewNoSeq := DB.ExecSQLScalar('select max(' + InNoSeqField +
              ') from ' + InTableName);
          except // déclenché si la table est vide
            NewNoSeq := 0;
          end;
          inc(NewNoSeq);
          DB.ExecSQL('update ' + InTableName + ' set ' + InNoSeqField +
            '=:noseq, ' + InChangedField + '=0 where ' + InNoSeqField + '=0',
            [NewNoSeq]);

          // On compare le nombre d'enregistrements au même NoSeq que le maxi
          // côté client pour le pas les retransférer à chaque fois
          try
            NbRec := DB.ExecSQLScalar('select count(*) from ' + InTableName +
              ' where ' + InNoSeqField + '=' + InLastNoSeq.ToString);
          except // déclenché si la table est vide
            NbRec := 0;
          end;
          // s'il y en a autant, on s'occupe des modifications suivantes, sinon on les refait tous pour ne pas en louper
          if (NbRec = InLastNoSeqNbRec) then
            inc(InLastNoSeq);

          // Traitement des enregistrements modifiés depuis le dernier import depuis le client connecté
          qry := tfdquery.Create(Self);
          try
            qry.Connection := DB;
            // On sélectionne les enregistrements de ce numéro de séquence et des
            // suivants.
            // En fait on retourne systématiquement les enregistrements du dernier
            // numéro de séquence au cas où il y aurait eu un couac sur la dernière
            // synchro si le comptage côté client et serveur diffère.
            // TODO : à optimiser ou lancer une vérification automatisée régulière
            qry.Open('select * from ' + InTableName + ' where (' + InNoSeqField
              + '>=:seq) order by ' + InNoSeqField, [InLastNoSeq]);
            // On retourne un objet contenant un tableau des
            // enregistrements.
            jsa := TJSONArray.Create;
            try
              while not qry.Eof do
              begin
                // On crée l'objet correspondant à l'enregistrement en cours et on
                // lui passe les champs utiles dans le bon format (nombre, chaine,
                // booléen).
                jsrec := tjsonobject.Create;
                // Création des paires correspondant à chaque champ de l'enregistrement en cours
                for i := 0 to qry.fields.count - 1 do
                  // Field2JSON : code similaire côté serveur et client
                  if (InChangedField = qry.fields[i].FieldName) then
                    jsrec.addpair(qry.fields[i].FieldName,
                      TJSONBool.Create(false))
                  else if qry.fields[i].IsNull then
                    jsrec.addpair(qry.fields[i].FieldName, TJSONNull.Create)
                  else if Session.isB64Field(qry.fields[i].FieldName) then
                  begin // champ binaire, blob ou autre à encoder en base 64
                    Base64Encoding := TBase64Encoding.Create;
                    try
                      jsrec.addpair(qry.fields[i].FieldName,
                        Base64Encoding.encodebytestostring
                        (qry.fields[i].AsBytes));
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
                        jsrec.addpair(qry.fields[i].FieldName,
                          tjsonnumber.Create(qry.fields[i].asinteger));
                      // champs booléens
                      TFieldType.ftBoolean:
                        jsrec.addpair(qry.fields[i].FieldName,
                          TJSONBool.Create(qry.fields[i].AsBoolean));
                    else // autres types de champs
                      jsrec.addpair(qry.fields[i].FieldName,
                        qry.fields[i].AsString);
                    end;
                // On ajoute cet objet au tableau.
                jsa.Add(jsrec);
                qry.next;
              end;
            finally
              // On ajoute le tableau à l'objet complet.
              jso.addpair('items', jsa);
            end;
            // On ajoute un code d'erreur neutre, au cas où le client le lirait
            // avant de faire quoi que ce soit.
            jso.addpair('error', '0');
          finally
            qry.free;
          end;
          DB.Close;
        finally
          // DB.free; // connexion associée à la session, ne pas la supprimer en route !
        end;
      except
        Response.StatusCode := 500;
        jso.addpair('error', '1');
      end;
    end
    else
    begin
      Response.StatusCode := 500;
      jso.addpair('error', '2');
    end;
  finally
    // On retourne le résultat généré au client.
    Handled := true;
    Response.ContentType := 'application/json';
    Response.ContentEncoding := 'UTF-8';
    Response.CustomHeaders.Add('Access-Control-Allow-Origin=*');
    Response.ContentStream := tstringstream.Create(jso.tojson, tencoding.UTF8);
{$IFDEF DEBUG}
    writeln(jso.tojson);
{$ENDIF}
    freeandnil(jso);
  end;
end;

procedure TOlfTDSWebModule.APILogin(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: boolean);
var
  jso: tjsonobject;
  MultiReq: tmultipartcontentparser;
  InDebugMode: boolean;
  InTableName: string;
  InB64Fields: string;
  InParamOk: boolean;
  Session: TOlfTDSSession;
begin
  Handled := false;
{$IFDEF DEBUG}
  writeln('**********');
  writeln('* login');
  writeln('**********');
{$ENDIF}
  // Décodage du POST
  if (tmultipartcontentparser.CanParse(Request)) then
    try
      MultiReq := tmultipartcontentparser.Create(Request);
    finally
      freeandnil(MultiReq);
    end;
  // Récupération des champs attendus
  InParamOk := true;
  try
{$IFDEF DEBUG}
    writeln('Client TDSAPIVersion=' + getPostValueAsInteger(Request,
      'TDSAPIVersion').ToString);
    writeln('Server TDSAPIVersion=' + COlfTDSAPIVersion.ToString);
{$ENDIF}
    // Si la version de ce fichier n'est pas la même que celle de la librairie cliente, on refuse la connexion
    if not isAPIVersionOk(getPostValueAsInteger(Request, 'TDSAPIVersion')) then
      raise exception.Create('Wrong TDS API Version');
  except
    InParamOk := false;
  end;
  try
    InDebugMode := (1 = getPostValueAsInteger(Request, 'TDSDebugMode'));
{$IFDEF DEBUG}
    writeln('TDSDebugMode=' + InDebugMode.ToString);
{$ENDIF}
  except
    InParamOk := false;
  end;
  try
    InTableName := getPostValueAsString(Request, 'TDSTableName');
{$IFDEF DEBUG}
    writeln('TDSTableName=' + InTableName);
{$ENDIF}
    // TODO : s'assurer que la table existe dans la base de données
  except
    InParamOk := false;
  end;
  try
    InB64Fields := getPostValueAsString(Request, 'TDSB64Fields');
{$IFDEF DEBUG}
    writeln('TDSB64Fields=' + InB64Fields);
{$ENDIF}
  except
    InParamOk := false;
  end;
  // Traitement des paramètres et retour de la réponse
  jso := tjsonobject.Create;
  try
    if InParamOk then
    begin
      try
        // Contrôle des paramètres d'accès ajoutés par l'utilisateur
        if LoginCheck(Request) then
        begin
          Session := SessionList.CreateAndAddSession;
          Session.ConnectionDefName := GetConnectionDefName(Request);
          Session.TableName := InTableName;
          Session.B64Fields := InB64Fields;
          jso.addpair('TDSSessionID', Session.ID);
          jso.addpair('error', '0');
        end
        else // accès refusé par LoginCheck
        begin
          Response.StatusCode := 401;
          jso.addpair('error', '1');
        end;
      except
        Response.StatusCode := 500;
        jso.addpair('error', '1');
      end;
    end
    else
    begin
      Response.StatusCode := 500;
      jso.addpair('error', '2');
    end;
  finally
    // On retourne le résultat généré au client.
    Handled := true;
    Response.ContentType := 'application/json';
    Response.ContentEncoding := 'UTF-8';
    Response.CustomHeaders.Add('Access-Control-Allow-Origin=*');
    Response.ContentStream := tstringstream.Create(jso.tojson, tencoding.UTF8);
{$IFDEF DEBUG}
    writeln(jso.tojson);
{$ENDIF}
    freeandnil(jso);
  end;
end;

{ TOlfTDSSessionList }

function TOlfTDSSessionList.AddSession(ASession: TOlfTDSSession): boolean;
begin
  result := false;
  MUTEX.Acquire;
  try
    if (count < 1) or (not ContainsKey(ASession.ID)) then
    begin
      Add(ASession.ID, ASession);
      result := true;
    end;
  finally
    MUTEX.Release;
  end;
end;

constructor TOlfTDSSessionList.Create;
begin
  inherited Create; // apelle le Create du TObjectDictionary
  MUTEX := TMutex.Create;
end;

function TOlfTDSSessionList.CreateAndAddSession: TOlfTDSSession;
begin
  result := TOlfTDSSession.Create;
  result.ID := GenerateUniqID;
  AddSession(result);
end;

destructor TOlfTDSSessionList.Destroy;
begin
  MUTEX.Acquire;
  // on verrouille pour être certain que c'est utilisé nulle part ailleurs (voir si c'est susceptible de générer des anomalies ou si ça passe)
  MUTEX.free;
  inherited;
end;

function TOlfTDSSessionList.GenerateUniqID(Nb: word): string;
var
  i: integer;
  Value: byte;
begin
  if (Nb < 5) then
    raise exception.Create('Nb is to low !');
  MUTEX.Acquire;
  try
    result := '';
    for i := 1 to Nb do
    begin
      Value := random(10 + 26 + 26);
      case Value of
        0 .. 9:
          result := result + chr(ord('0') + Value);
        (9 + 1) .. (9 + 26): result := result + chr(ord('a') + Value - 9 - 1);
        (9 + 26 + 1) .. (9 + 26 + 26): result := result +
          chr(ord('A') + Value - 9 - 26 - 1);
      end;
    end;
    if (count > 0) and ContainsKey(result) then
      result := GenerateUniqID(Nb + 1);
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSessionList.GetSession(ASessionID: TOlfTDSSessionID)
  : TOlfTDSSession;
begin
  MUTEX.Acquire;
  try
    if ASessionID.IsEmpty or (not trygetvalue(ASessionID, result)) then
      result := nil;
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSessionList.RemoveSession(ASessionID: TOlfTDSSessionID);
begin
  MUTEX.Acquire;
  try
    if (count > 0) and ContainsKey(ASessionID) then
      Remove(ASessionID);
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSessionList.RemoveSession(ASession: TOlfTDSSession);
begin
  MUTEX.Acquire;
  try
    if assigned(ASession) then
      RemoveSession(ASession.ID);
  finally
    MUTEX.Release;
  end;
end;

{ TOlfTDSSession }

constructor TOlfTDSSession.Create;
begin
  MUTEX := TMutex.Create;
  FDB := nil;
  FConnectionDefName := '';
  FTableName := '';
  FDB := nil;
  FServeurNoSeq := -1;
end;

destructor TOlfTDSSession.Destroy;
begin
  MUTEX.Acquire;
  // on verrouille pour être certain que c'est utilisé nulle part ailleurs (voir si c'est susceptible de générer des anomalies ou si ça passe)
  MUTEX.free;
  FDB.free;
  inherited;
end;

function TOlfTDSSession.GetB64Fields: string;
begin
  MUTEX.Acquire;
  try
    result := FB64Fields;
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.GetConnectionDefName: string;
begin
  MUTEX.Acquire;
  try
    result := FConnectionDefName;
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.GetDBConnection: TFDConnection;
begin
  result := nil;
  MUTEX.Acquire;
  try
    if assigned(FDB) then
      result := FDB
    else if (not FConnectionDefName.IsEmpty) and
      FDManager.IsConnectionDef(FConnectionDefName) then
    begin
      FDB := TFDConnection.Create(nil);
      FDB.Params.Clear;
      FDB.ConnectionDefName := FConnectionDefName;
      result := FDB;
    end
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.GetID: string;
begin
  MUTEX.Acquire;
  try
    result := FID;
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.GetServeurNoSeq: integer;
begin
  MUTEX.Acquire;
  try
    result := FServeurNoSeq;
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.GetTableName: string;
begin
  MUTEX.Acquire;
  try
    result := FTableName;
  finally
    MUTEX.Release;
  end;
end;

function TOlfTDSSession.isB64Field(AFieldName: string): boolean;
begin
  MUTEX.Acquire;
  try
    result := FB64Fields.Contains(',' + AFieldName + ',');
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSession.SetB64Fields(const Value: string);
begin
  MUTEX.Acquire;
  try
    FB64Fields := ',' + Value + ',';
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSession.SetConnectionDefName(const Value: string);
begin
  MUTEX.Acquire;
  try
    FConnectionDefName := Value;
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSession.SetID(const Value: string);
begin
  MUTEX.Acquire;
  try
    FID := Value;
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSession.SetServeurNoSeq(const Value: integer);
begin
  MUTEX.Acquire;
  try
    FServeurNoSeq := Value;
  finally
    MUTEX.Release;
  end;
end;

procedure TOlfTDSSession.SetTableName(const Value: string);
begin
  MUTEX.Acquire;
  try
    FTableName := Value;
  finally
    MUTEX.Release;
  end;
end;

initialization

SessionList := TOlfTDSSessionList.Create;

{$IFDEF DEBUG}
ReportMemoryLeaksOnShutdown := true;
{$ENDIF}
randomize;

finalization

SessionList.free;

end.

// TODO : gérer le décodage des paramètres d'entrée s'ils ont été chiffrés dans le client
// TODO : gérer l'encodage des paramètres de sortie s'ils ont été chiffrés dans le client
