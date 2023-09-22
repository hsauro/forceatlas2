unit uForceAtlas2_Layout;

{
 This Object Pascal code is licensed under the Common
 Development and Distribution License("CDDL")
 Dated September, 2023

 The Object Pascal version was derived from the Java
 code by Mathieu Jacomy and Python code
 derived by Bhargav Chippada.

 This is the original Java license text:

 Copyright 2008-2011 Gephi
 Authors : Mathieu Jacomy <mathieu.jacomy@gmail.com>
 Website : http://www.gephi.org

 This file [The Java Code] is part of Gephi.

 DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.

 Copyright 2011 Gephi Consortium. All rights reserved.

 The contents of this file are subject to the terms of either the GNU
 General Public License Version 3 only ("GPL") or the Common
 Development and Distribution License("CDDL") (collectively, the
 "License"). You may not use this file except in compliance with the
 License. You can obtain a copy of the License at
 http://gephi.org/about/legal/license-notice/
 or /cddl-1.0.txt and /gpl-3.0.txt. See the License for the
 specific language governing permissions and limitations under the
 License.  When distributing the software, include this License Header
 Notice in each file and include the License files at
 /cddl-1.0.txt and /gpl-3.0.txt. If applicable, add the following below the
 License Header, with the fields enclosed by brackets [] replaced by
 your own identifying information:

 Herbert M Sauro elects to include this software in this distribution
 under the CDDL license.

 If you wish your version of this file to be governed by only the CDDL
 or only the GPL Version 3, indicate your decision by adding
 "[Contributor] elects to include this software in this distribution
 under the [CDDL or GPL Version 3] license." If you do not indicate a
 single choice of license, a recipient has the option to distribute
 your version of this file under either the CDDL, the GPL Version 3 or
 to extend the choice of license to its licensees as provided above.
 However, if you add GPL Version 3 code and therefore, elected the GPL
 Version 3 license, then the option applies only if the new code is
 made subject to such option by the copyright holder.

 Contributor(s):

 Herbert M Sauro

 The Object Pascal version was derived from the original Java version
 and the Python version created by:

 Java: Mathieu Jacomy <mathieu.jacomy@gmail.com>

 Python: Bhargav Chippada bhargavchippada19@gmail.com.
 https://github.com/bhargavchippada/forceatlas2

 Portions [unspecified] Copyrighted 2011 Gephi Consortium.

 The above text may not be changed.
 }

interface

Uses Classes, SysUtils, System.Generics.Collections, uGraph;

type
  TIntRows = array of integer;

  TForceAtlas2 = class (TObject)
     private
       function    getNumNonZeros (x : TIntRows) : integer;
       procedure   initialize (network : TGraph);
     public
      // Behavior alternatives
      outboundAttractionDistribution : boolean;  // Dissuade hubs
      outboundAttCompensation : double;
      linLogMode : boolean;  // NOT IMPLEMENTED
      adjustSizes : boolean;  // Prevent overlap (NOT IMPLEMENTED)
      edgeWeightInfluence : double;

      // Performance
      jitterTolerance : double;  // Tolerance
      barnesHutOptimize : boolean;
      barnesHutTheta : double;

      // Tuning
      scalingRatio : double;
      strongGravityMode : boolean;
      gravity : double;

      speed : double;
      speedEfficiency : double;

      constructor Create;

      procedure   setupCompute (network : TGraph);
      procedure   doOneIteration (network : TGraph);
  end;


implementation

Uses Math;

constructor TForceAtlas2.Create;
begin
   speed := 1;
   speedEfficiency := 1;

   // Behavior alternatives
   outboundAttractionDistribution := False;  // Dissuade hubs
   linLogMode := False;  // NOT IMPLEMENTED
   adjustSizes := False;  // Prevent overlap (NOT IMPLEMENTED)
   edgeWeightInfluence := 1.0;

   // Performance
   jitterTolerance := 10.0;  // Tolerance
   barnesHutOptimize := False;
   barnesHutTheta := 1.2;

   // Tuning
   scalingRatio := 200;     // Change this to change distance between nodes
   strongGravityMode := False;
   gravity := 0
end;



function TForceAtlas2.getNumNonZeros (x : TIntRows) : integer;
var i : integer;
begin
  result := 0;
  // First count the number of non-zeros
  for i := 0 to length (x) - 1 do
      begin
      if x[i] <> 0 then
         result := result + 1
      end;
end;



// ------------------------------------------------------------------------------


// Gravity repulsion function.  For some reason, gravity was included
// within the linRepulsion function in the original gephi java code,
// which doesn't make any sense (considering a. gravity is unrelated to
// nodes repelling each other, and b. gravity is actually an
// attraction)
procedure linGravity(n : TNode; g : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n.x;
    yDist := n.y;
    distance := sqrt(xDist * xDist + yDist * yDist);

    if distance > 0 then
       begin
       factor := n.mass * g / distance;
       n.dx := n.dx - xDist * factor;
       n.dy := n.dy - yDist * factor;
       end;
end;


// Repulsion function.  `n1` and `n2` should be nodes.  This will
// adjust the dx and dy values of `n1`  `n2`
procedure linRepulsion(n1, n2 : TNode; coefficient : double);
var xDist, yDist : double; factor, distance : double;
begin
    xDist := n1.x - n2.x;
    yDist := n1.y - n2.y;
    distance := xDist * xDist + yDist * yDist;  // Distance squared

    if distance > 0 then
       begin
       factor := coefficient * n1.mass * n2.mass / distance;
       n1.dx := n1.dx + xDist * factor;
       n1.dy := n1.dy + yDist * factor;
       n2.dx := n2.dx - xDist * factor;
       n2.dy := n2.dy - yDist * factor;
       end;
end;



// Attraction function.  `n1` and `n2` should be nodes.  This will
// adjust the dx and dy values of `n1` and `n2`.  It does
// not return anything.
procedure linAttraction(n1, n2 : TNode; weight : double; distributedAttraction : boolean; coefficient : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n1.x - n2.x;
    yDist := n1.y - n2.y;
    if not distributedAttraction then
        factor := -coefficient * weight
    else
        factor := -coefficient * weight / n1.mass;

    n1.dx := n1.dx + xDist * factor;
    n1.dy := n1.dy + yDist * factor;
    n2.dx := n2.dx - xDist * factor;
    n2.dy := n2.dy - yDist * factor;
end;


procedure apply_attraction(nodes : TNodes; edges : TEdges; distributedAttraction : boolean; coefficient, edgeWeightInfluence : double);
var edge : TEdge;
begin
  // Optimization, since usually edgeWeightInfluence is 0 or 1, and pow is slow
  if edgeWeightInfluence = 0 then
        begin
        for edge in edges do
            linAttraction(edge.src, edge.dest, 1, distributedAttraction, coefficient)
        end
    else if edgeWeightInfluence = 1 then
            begin
            for edge in edges do
                linAttraction(edge.src, edge.dest, edge.weight, distributedAttraction, coefficient)
            end
    else
        for edge in edges do
            linAttraction(edge.src, edge.dest, math.power(edge.weight, edgeWeightInfluence),
                          distributedAttraction, coefficient)
end;


// Strong gravity force function. `n` should be a node, and `g`
// should be a constant by which to apply the force.
procedure strongGravity(n : TNode; g, coefficient : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n.x;
    yDist := n.y;

    if (xDist <> 0) and (yDist <> 0) then
        begin
        factor := coefficient * n.mass * g;
        n.dx := n.dx - xDist * factor;
        n.dy := n.dy - yDist * factor;
        end;
end;


procedure apply_gravity(nodes : TNodes; gravity, scalingRatio : double; useStrongGravity : boolean);
var n : TNode;
begin
    if not useStrongGravity then
        for n in nodes do
            linGravity(n, gravity)
    else
        for n in nodes do
            strongGravity(n, gravity, scalingRatio)
end;


// The following functions iterate through the nodes or edges and apply
// the forces directly to the node objects.  These iterations are here
// instead of the main file because Python is slow with loops.
procedure apply_repulsion(nodes : TNodes; coefficient : double);
var i, j : integer; node1, node2 : TNode;
begin
  i := 0;
  for node1 in nodes do
      begin
      j := i;
      for node2 in nodes do
          begin
          if j = 0 then
             break;
          linRepulsion(node1, node2, coefficient);
          j := j - 1;
          end;
      i := i + 1;
      end;
end;



// Adjust speed and apply forces step
function adjustSpeedAndApplyForces(nodes : TNodes; speed, speedEfficiency, jitterTolerance : double; adjustSizes : boolean) : double;
var totalSwinging, totalEffectiveTraction : double;
    estimatedOptimalJitterTolerance, jt : double;
    n : TNode;
    minJT, maxJT : double;
    swinging, factor : double;
    targetSpeed, minSpeedEfficiency : double;
    maxRise : double;
    df : double;
begin
    // Auto adjust speed.
    totalSwinging := 0.0;  // How much irregular movement
    totalEffectiveTraction := 1.0;  // How much useful movement
    for n in nodes do
        begin
        swinging := sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
        totalSwinging := totalSwinging + n.mass * swinging;
        totalEffectiveTraction := totalEffectiveTraction + 0.5 * n.mass * sqrt(
            (n.old_dx + n.dx) * (n.old_dx + n.dx) + (n.old_dy + n.dy) * (n.old_dy + n.dy));
        end;

    // We want that swingingMovement < tolerance * convergenceMovement
    // Optimize jitter tolerance.  The 'right' jitter tolerance for
    // this network. Bigger networks need more tolerance. Denser
    // networks need less tolerance. Totally empiric.
    estimatedOptimalJitterTolerance := 0.05 * sqrt(nodes.count);
    minJT := sqrt(estimatedOptimalJitterTolerance);
    maxJT := 10;
    jt := jitterTolerance * max(minJT, min(maxJT, estimatedOptimalJitterTolerance * totalEffectiveTraction
                                  /(nodes.count * nodes.count)));

    minSpeedEfficiency := 0.05;

    // Protective against erratic behavior
    if (totalSwinging / totalEffectiveTraction) > 2.0 then
        begin
        if speedEfficiency > minSpeedEfficiency then
            speedEfficiency := speedEfficiency*0.5;
        jt := max(jt, jitterTolerance);
        end;

    targetSpeed := jt * speedEfficiency * totalEffectiveTraction / totalSwinging;

    if totalSwinging > jt * totalEffectiveTraction then
       begin
       if speedEfficiency > minSpeedEfficiency then
          speedEfficiency := speedEfficiency * 0.7
       end
    else if speed < 1000 then
        speedEfficiency := speedEfficiency * 1.3;

    // But the speed shoudn't rise too much too quickly, since it would
    // make the convergence drop dramatically.
    maxRise := 0.5;
    speed := speed + min(targetSpeed - speed, maxRise * speed);

    // Apply forces.
    if adjustSizes then
        begin
        for n in nodes do
          begin
          swinging := n.mass * sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
          factor := 0.1 * speed / (1.0 + sqrt(speed * swinging));

          df := sqrt(Math.power(n.dx, 2) + Math.power(n.dy, 2));
          factor := Math.min(factor * df, 10.0) / df;

          n.x := n.x + (n.dx * factor);
          n.y := n.y + (n.dy * factor);
          end;
        end
      else
        begin
        for n in nodes do
          begin
          swinging := n.mass * sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
          factor := speed / (1.0 + sqrt(speed * swinging));

          n.x := n.x + (n.dx * factor);
          n.y := n.y + (n.dy * factor);
          end;
        end;
end;


// -------------------------------------------------------------------------------

procedure TForceAtlas2.initialize (network : TGraph);  // a graph in 2D numpy ndarray format (or) scipy sparse matrix format
var i, j : integer;
    n1, n2 : TNode;
    adj1, adj2 : integer;
    G : array of TIntRows;
begin
  // Constuct the adjacency matrix
  setLength(G, network.nodes.Count, network.nodes.Count);
  for i := 0 to network.edges.Count - 1  do
      begin
      n1 := network.edges[i].src;
      n2 := network.edges[i].dest;
      for j := 0 to network.nodes.Count - 1 do
          if n1 = network.nodes[j] then
             begin
             adj1 := j;
             break;
             end;
      for j := 0 to network.nodes.Count - 1 do
          if n2 = network.nodes[j] then
             begin
             adj2 := j;
             break;
             end;
      G[adj1][adj2] := 1;
      G[adj2][adj1] := 1;
      end;

  // Put nodes into a data structure we can understand
  for i := 0 to network.nodes.Count - 1 do
      begin
      network.nodes[i].old_dx := 0;
      network.nodes[i].old_dy := 0;
      network.nodes[i].dx := 0;
      network.nodes[i].dy := 0;
      network.nodes[i].x := network.nodes[i].x;
      network.nodes[i].y := network.nodes[i].y;
      network.nodes[i].mass := 1 + getNumNonZeros (G[i]);
      end;
end;


// Call this first
procedure TForceAtlas2.setupCompute (network : TGraph);
var sum : double;
begin
  speed := 1.0;
  speedEfficiency := 1.0;
  initialize (network);
  outboundAttCompensation := 1.0;

  if outboundAttractionDistribution then
     begin
     sum := 0;
     for var i : integer := 0 to network.nodes.Count - 1 do
         sum := sum + network.nodes[i].mass;
     outboundAttCompensation := sum/network.nodes.Count; //numpy.mean([n.mass for n in nodes])
     end;
end;


// Given an adjacency matrix, this function computes the node positions
// according to the ForceAtlas2 layout algorithm.  It takes the same
// arguments that one would give to the ForceAtlas2 algorithm in Gephi.
// Not all of them are implemented.  See below for a description of
// each parameter and whether or not it has been implemented.
//
// This function will return a list of X-Y coordinate tuples, ordered
// in the same way as the rows/columns in the input matrix.
//
// The only reason you would want to run this directly is if you don't
// use networkx.  In this case, you'll likely need to convert the
// output to a more usable format.  If you do use networkx, use the
// "forceatlas2_networkx_layout" function below.
//
// Currently, only undirected graphs are supported so the adjacency matrix
// should be symmetric.
procedure TForceAtlas2.doOneIteration (network : TGraph);
begin
  for var i : integer := 0 to network.nodes.Count - 1 do
         begin
         network.nodes[i].old_dx := network.nodes[i].dx;
         network.nodes[i].old_dy := network.nodes[i].dy;
         network.nodes[i].dx := 0;
         network.nodes[i].dy := 0;
         end;

     // Charge repulsion forces
     apply_repulsion(network.nodes, scalingRatio);

     // Gravitational forces
     apply_gravity(network.nodes, gravity, scalingRatio, strongGravityMode);

     // If other forms of attraction were implemented they would be selected here.
     apply_attraction(network.nodes, network.edges, outboundAttractionDistribution,
                  outboundAttCompensation, edgeWeightInfluence);

     // Adjust speeds and apply forces
     adjustSpeedAndApplyForces(network.nodes, speed, speedEfficiency, jitterTolerance, adjustSizes);
end;


end.
