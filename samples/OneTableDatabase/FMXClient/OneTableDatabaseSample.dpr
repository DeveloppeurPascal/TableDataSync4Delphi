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
/// File last update : 2025-02-08T18:21:08.000+01:00
/// Signature : 179ab2b1ea25125f1d328fb87cb08d8c2c4600fc
/// ***************************************************************************
/// </summary>

program OneTableDatabaseSample;

uses
  System.StartUpCopy,
  FMX.Forms,
  fMain in 'fMain.pas' {frmMain},
  Olf.TableDataSync in '..\..\..\src\Client\Olf.TableDataSync.pas',
  Olf.RTL.GenRandomID in '..\..\..\lib-externes\librairies\src\Olf.RTL.GenRandomID.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
