(* C2PP
  ***************************************************************************

  Table Data Sync for Delphi

  Copyright 2017-2025 Patrick PREMARTIN under AGPL 3.0 license.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.

  ***************************************************************************

  A Delphi client/server library to synchronize table records over the
  rainbows.

  ***************************************************************************

  Author(s) :
  Patrick PREMARTIN

  Site :
  https://tabledatasync.developpeur-pascal.fr/

  Project site :
  https://github.com/DeveloppeurPascal/TableDataSync4Delphi

  ***************************************************************************
  File last update : 2025-02-09T11:04:10.263+01:00
  Signature : 9c6edbb4111e0d3af35de3ce974f167218243ac9
  ***************************************************************************
*)

unit ServerConst1;

interface

resourcestring
  sPortInUse = '- Erreur : Le port %s est déjà utilisé';
  sPortSet = '- Port défini sur %s';
  sServerRunning = '- Le serveur est déjà exécuté';
  sStartingServer = '- Démarrage du serveur HTTP sur le port %d';
  sStoppingServer = '- Arrêt du serveur';
  sServerStopped = '- Serveur arrêté';
  sServerNotRunning = '- Le serveur n'#39'est pas exécuté';
  sInvalidCommand = '- Erreur : Commande non valide';
  sIndyVersion = '- Version Indy : ';
  sActive = '- Actif : ';
  sPort = '- Port : ';
  sSessionID = '- Nom de cookie de l'#39'ID de session : ';
  sCommands = 'Entrez une commande : '#13#10'   - "start" pour démarrer le serveur'#13#10'   - "stop" pour arrêter le serveur'#13#10'   - "set port" pour changer le port par défaut'#13#10'   - "status" pour obtenir l'#39'état du serveur'#13#10'   - "help" pour afficher les commandes'#13#10'   - "exit" pour fe'+
'rmer l'#39'application';

const
  cArrow = '->';
  cCommandStart = 'start';
  cCommandStop = 'stop';
  cCommandStatus = 'status';
  cCommandHelp = 'help';
  cCommandSetPort = 'set port';
  cCommandExit = 'exit';

implementation

end.
