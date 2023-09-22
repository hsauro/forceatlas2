unit uGraph;

interface

Uses Classes, SysUtils, Generics.Collections, System.Types;


const
   DEFAULT_WIDTH = 32;
   DEFAULT_HEIGHT = 32;

type
  TEdge = class;

  TNode = class
     name : string;
     id : integer;   // The id is unique to a node
     x, y : double;
     w, h : double;
     dx, dy : double;
     locked : boolean;
     mass : double;
     old_dx : double;
     old_dy : double;
     hover : boolean;
     edgeList : TObjectList<TEdge>;

     function isInNode (px, py : single) : boolean;
     constructor Create;
     destructor Destroy; override;
  end;

  TNodes = class (TObjectList<TNode>)
      procedure hoverOff;
  end;

  TEdge = class
     name : string;
     id: integer;  // The id is unique to a edge
     src, dest : TNode;
     weight : double;

     constructor Create;
     destructor Destroy; override;
  end;

  TEdges = TObjectList<TEdge>;


  TGraph = class
    nodes : TNodes;
    edges : TEdges;

    procedure clear;
    function  addNode (x, y : single) : integer; overload;
    function  addNode (name : string; x, y : single) : integer;  overload;
    procedure addNode (x, y : single; locked : boolean); overload;
    procedure addEdge (v, u : TNode);  overload;
    procedure addEdge (name : string; v, u : TNode);  overload;
    function  findNode (name : string) : TNode;
    procedure center (w, h : single);
    function  ptInNode (px, py : single; var index : integer) : boolean;

    constructor Create;
  end;

implementation

constructor TGraph.Create;
begin
  nodes := TNodes.Create;
  edges := TEdges.Create;
end;


procedure TGraph.clear;
begin
  edges.Clear;
  nodes.Clear;
end;

// -------------------------------------------------------------------------


constructor TEdge.Create;
begin
   weight := 1;
end;


destructor TEdge.Destroy;
begin
  inherited;
end;



// ------------------------------------------------------------------------


procedure TNodes.hoverOff;
var i : integer;
begin
  for i := 0 to Count - 1 do
      Items[i].hover := False;
end;


// ------------------------------------------------------------------------


constructor TNode.Create;
begin
  mass := 1.0;
  old_dx := 0.0;
  old_dy := 0.0;
  dx := 0.0;
  dy := 0.0;
  x := 0.0;
  y := 0.0;
  hover := false;
  edgeList := TObjectList<TEdge>.Create;

  locked := False;
end;


destructor TNode.Destroy;
begin
  inherited;
end;


function TNode.isInNode (px, py : single) : boolean;
begin
  if TPoint.PointInCircle(Point(trunc (px), trunc (py)), Point (trunc (x + w/2), trunc (y + h/2)), DEFAULT_WIDTH) then
     exit (True)
  else
     exit (False);
end;


function TGraph.addNode (x, y : single) : integer;
var index : integer;
begin
  index :=  nodes.Add (TNode.Create);
  nodes[index].id := index;
  nodes[index].x := x;
  nodes[index].y := y;
  nodes[index].w := DEFAULT_WIDTH;
  nodes[index].h := DEFAULT_HEIGHT;
  nodes[index].name := 'N' + inttostr (index);
  result := index;
end;


function TGraph.addNode (name : string; x, y : single) : integer;
var index : integer;
begin
  index :=  nodes.Add (TNode.Create);
  nodes[index].id := index;
  nodes[index].x := x;
  nodes[index].y := y;
  nodes[index].w := DEFAULT_WIDTH;
  nodes[index].h := DEFAULT_HEIGHT;
  nodes[index].name := name;
  result := index;
end;


procedure TGraph.addNode (x, y : single; locked : boolean);
var index : integer;
begin
  index := addNode (x, y);
  nodes[index].locked := locked;
end;


procedure TGraph.addEdge (v, u : TNode);
var edge : TEdge;
    index : integer;
begin
  if (v = nil) or (u = nil) then
     raise Exception.Create('Node cannot be nil in addEdge');

  edge := TEdge.Create;
  edge.src := v;
  edge.dest := u;
  index := edges.Add (edge);
  edge.id := index; // Give it a uniqe id
  edge.name := 'E' + inttostr (index);
  v.edgeList.Add (edge);
  u.edgeList.Add (edge);
end;


procedure TGraph.addEdge (name : string; v, u : TNode);
var edge : TEdge;
    index : integer;
begin
  if (v = nil) or (u = nil) then
     raise Exception.Create('Node cannot be nil in addEdge');

  edge := TEdge.Create;
  edge.src := v;
  edge.dest := u;
  index := edges.Add (edge);
  edge.id := index; // Give it a uniqe id
  edge.name := name;
  v.edgeList.Add (edge);
  u.edgeList.Add (edge);
end;


procedure TGraph.center (w, h : single);
var i : integer;
    sumx, sumy, cx, cy, dx, dy : double;
begin
  // Find the centroid of the graph
  sumx := 0; sumy := 0;
  for i := 0 to nodes.Count - 1 do
      begin
      sumx := sumx + nodes[i].x;
      sumy := sumy + nodes[i].y;
      end;
  cx := sumx/nodes.Count;
  cy := sumy/nodes.Count;

 // Fnd how much we havw to translate each node so that
 // the centroid is in the middle of the screen.
 dx := cx - w/2;
 dy := cy - h/2;

 for i := 0 to nodes.Count - 1 do
     begin
     if not nodes[i].locked then
       begin
       nodes[i].x := nodes[i].x - dx;
       nodes[i].y := nodes[i].y - dy;
       end;
     end;
end;


function TGraph.findNode (name : string) : TNode;
var i : integer;
begin
  for i := 0 to nodes.Count - 1 do
      if nodes[i].name = name then
         exit (nodes[i]);
  exit (nil);
end;


function TGraph.ptInNode (px, py : single; var index : integer) : boolean;
var i : integer;
begin
  for i := 0 to nodes.Count - 1 do
      if nodes[i].isInNode(px, py) then
         begin
         index := i;
         exit (True);
         end;
  exit (False);
end;


end.

