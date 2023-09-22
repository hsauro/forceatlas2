unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, uGraph,
  FMX.Objects, FMX.Layouts, uForceAtlas2_Layout, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.TextLayout, FMX.Edit, FMX.EditBox, FMX.NumberBox;

type
  TAction = (atSelect);

  TfrmMain = class(TForm)
    Layout1: TLayout;
    PaintBox: TPaintBox;
    btnRandom: TButton;
    Timer1: TTimer;
    btnLayout: TButton;
    btnCenter: TButton;
    btnClear: TButton;
    nbNumNodes: TNumberBox;
    Label1: TLabel;
    Label2: TLabel;
    nbNumEdges: TNumberBox;
    procedure FormDestroy(Sender: TObject);
    procedure btnCenterClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnLayoutClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnRandomClick(Sender: TObject);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift:
        TShiftState; X, Y: Single);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift:
        TShiftState; X, Y: Single);
    procedure PaintBoxPaint(Sender: TObject; Canvas: TCanvas);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    procedure writeTextId (ACanvas : TCanvas; x, y, w, h : single; atext : string);
    procedure draw (Canvas : TCanvas; Brush : TStrokeBrush);
  public
    { Public declarations }
    graph: TGraph;
    selected : boolean;
    currentNode : integer;
    action: TAction;
    sx, sy : single;
    srcPt, destPt : integer;
    pausingTimer : boolean;

    atlas : TForceAtlas2;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses Math, StrUtils;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  atlas.free;
  graph.free;
end;


procedure TfrmMain.btnCenterClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  graph.center(PaintBox.Width, PaintBox.Height);
  PaintBox.Repaint;
end;


procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  graph.clear;
  PaintBox.Repaint;
end;


procedure TfrmMain.btnLayoutClick(Sender: TObject);
begin
  atlas.setupCompute (graph);
  Timer1.Enabled := True;
end;


procedure TfrmMain.FormCreate(Sender: TObject);
begin
   selected := False;
   graph := TGraph.Create;
   srcPt := -1; destPt := -1;
   pausingTimer := False;
   atlas := TForceAtlas2.Create;
   nbNumNodes.Value := 25;
   nbNumEdges.Value := 30;
end;


procedure TfrmMain.btnRandomClick(Sender: TObject);
var i, j : integer;
    nNodes, nEdges: integer;
    src, dest : integer;
begin
  Timer1.Enabled := False;
  graph.clear;

  nNodes := trunc (nbNumNodes.value);
  nEdges := trunc (nbNumEdges.value);
  for i := 0 to nNodes - 1 do
      graph.addNode (RandomRange(50, 350), RandomRange (50, 450));

  for i := 0 to nEdges - 1 do
      begin
      src := Random(nNodes);
      dest := Random (nNodes);
      if src <> dest then
         graph.addEdge (graph.nodes[src], graph.nodes[dest]);
      end;

  // check for unconnectd nodes
  for i := graph.nodes.Count - 1 downto 0 do
      if graph.nodes[i].edgeList.Count = 0 then
         graph.nodes.Delete(i);

  graph.center(PaintBox.Width, PaintBox.Height);
  paintbox.Repaint;
end;



procedure TfrmMain.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Single);
var i, index : integer;
begin
  sx := x; sy := y;

  // This is to pause the layout algorithm if its running, so we can move nodes.
  if timer1.Enabled then
     begin
     pausingTimer := True;
     timer1.Enabled  := False;
     end;

  case action of

   atSelect:
      begin
     selected := False;
     if graph.ptInNode (x, y, index) then
        begin
        currentNode := index;
        selected := True;
        exit;
        end;
      end;
  end;
  PaintBox.Repaint;
end;


procedure TfrmMain.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y:
    Single);
var dx, dy : single;
    index: integer;
begin
  dx := x - sx;
  dy := y - sy;
  case action of
     atSelect :
        begin
        if selected then
           begin
           graph.nodes[currentNode].x := graph.nodes[currentNode].x + dx;
           graph.nodes[currentNode].y := graph.nodes[currentNode].y + dy;
           PaintBox.repaint;
           end;
        end;
  end;
  sx := x; sy := y;
  PaintBox.repaint;
end;


procedure TfrmMain.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Single);
begin
  selected := False;

  // This is to restart of the layout alg is was previously running
  if pausingTimer then
     begin
     pausingTimer := False;
     Timer1.Enabled := True;
     end;
end;


procedure TfrmMain.writeTextId (ACanvas : TCanvas; x, y, w, h : single; atext : string);
var tx, ty : single;
    tw, th : single;
begin
  Canvas.Font.Size := 12;
  Canvas.Font.Family := 'Arial';
  Canvas.Fill.Color := TAlphaColors.Black;

  tw := Canvas.TextWidth(atext);
  th := Canvas.TextHeight(atext);

  tx := (x + w/2) - tw/2;
  ty := (y + h/2) - th/2;

  Canvas.FillText(TRectF.Create(tx, ty, tx + tw, ty + th), atext, False, 1, [], TTextAlign.Center, TTextAlign.Center);
end;


procedure TfrmMain.draw (Canvas : TCanvas; Brush : TStrokeBrush);
var srcx, srcy, destx, desty : integer;
    cx, cy : single;
    tx, ty : single;
    i : integer;
    astr : string;
begin
   if graph = nil then
     exit;

  Brush.Color := TAlphaColors.Blue;
  Brush.Thickness := 1;
  for i := 0 to graph.edges.count - 1 do
      begin
      srcx := trunc (graph.edges[i].src.x + graph.edges[i].src.w / 2);
      srcy := trunc (graph.edges[i].src.y + graph.edges[i].src.h / 2);

      destx := trunc (graph.edges[i].dest.x + graph.edges[i].src.w / 2);
      desty := trunc (graph.edges[i].dest.y + graph.edges[i].src.h / 2);

      Canvas.DrawLine(TPointF.Create (srcx,  srcy), TPointF.Create(destx, desty), 1.0, Brush);
      end;

 Brush.Thickness := 2;
 for i := 0 to graph.nodes.Count - 1 do
      begin
      cx := graph.nodes[i].x + graph.nodes[i].w / 2;
      cy := graph.nodes[i].y + graph.nodes[i].h / 2;

      Brush.Color := TAlphaColors.Lightblue;
      Canvas.FillEllipse(TRectF.Create(graph.nodes[i].x, graph.nodes[i].y, graph.nodes[i].x + graph.nodes[i].w, graph.nodes[i].y + graph.nodes[i].h), 1, Brush);

      Brush.Color := TAlphaColors.Darkblue;
      Canvas.DrawEllipse(TRectF.Create(graph.nodes[i].x, graph.nodes[i].y, graph.nodes[i].x + graph.nodes[i].w, graph.nodes[i].y + graph.nodes[i].h), 1, Brush);

      astr := inttostr (graph.nodes[i].id);
      writeTextId(Canvas, graph.nodes[i].x, graph.nodes[i].y, graph.nodes[i].w, graph.nodes[i].h, astr);
      end;
end;


procedure TfrmMain.PaintBoxPaint(Sender: TObject; Canvas: TCanvas);
var brush : TStrokeBrush;
    ADest : TRectF;
    LSave : TCanvasSaveState;
begin
  ADest := TRectF.Create(0, 0, PaintBox.Width, PaintBox.Height);
  // Must save state otherwise clipping won't work
  LSave := Canvas.SaveState;
  try
    Canvas.BeginScene;
    try
      Brush := TStrokeBrush.Create(TBrushKind.Solid, TAlphaColors.Black);
      Brush.Thickness := 2;

      // Clip and clear the screen
      Canvas.IntersectClipRect(ADest);
      Canvas.ClearRect(ADest, TAlphaColors.White);

      draw (Canvas, Brush);
    finally
      Canvas.EndScene;
    end;
  finally
        Canvas.RestoreState (LSave);
  end;
end;


procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  atlas.doOneIteration (graph);
  PaintBox.Repaint;
end;


end.
