program Project_FMX_BallStick;

uses
  System.StartUpCopy,
  FMX.Forms,
  ufMain in 'ufMain.pas' {frmMain},
  uForceAtlas2_Layout in 'uForceAtlas2_Layout.pas',
  uGraph in 'uGraph.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
