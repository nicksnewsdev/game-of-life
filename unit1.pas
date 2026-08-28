unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Math;

type
  TCellState = (cellStateDead, cellStateAlive); // State of each cell, whether it is alive or not

  TCellGrid = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FCells: array of array of TCellState; // 2Darray storing the state of each cell in the grid

    function CountActiveNeighbours(AX, AY: Integer): Integer;

  public
    constructor Create(AWidth, AHeight: Integer); // Create the cell grid with fixed parameters

    procedure SetCellState(AX, AY: Integer; ACellState: TCellState);
    function GetCellState(AX, AY: Integer): TCellState;

    procedure Tick; // Tick the simulation
    procedure Clear;

    property CellGridWidth: Integer read FWidth;
    property CellGridHeight: Integer read FHeight;
  end;

  TViewport = class
  private
    FViewportX: Double;
    FViewportY: Double;
    FViewportZoom: Double;

  public
    constructor Create; // Create the viewport camera for a cell grid

    // Conversion functions to keep viewport and cell grid space separate
    function GridToViewportX(AGridX: Integer): Integer;
    function GridToViewportY(AGridY: Integer): Integer;

    function ViewportToGridX(AViewportX: Integer): Integer;
    function ViewportToGridY(AViewportY: Integer): Integer;

    procedure Pan(ADeltaX, ADeltaY: Double); // Pan the camera on X and Y
    procedure Zoom(AZoomFactor: Double);
    procedure ZoomAt(AZoomFactor: Double; AViewportX, AViewportY: Integer);

    property ViewportX: Double read FViewportX;
    property ViewportY: Double read FViewportY;
    property ViewportZoom: Double read FViewportZoom;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    Label1: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);

    // Mouse events for clicking and dragging the viewport
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Panel1Click(Sender: TObject);
    procedure Panel3Click(Sender: TObject);
    procedure Panel5Click(Sender: TObject);
    procedure Panel6Click(Sender: TObject);

  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;

  private
    FCellGrid: TCellGrid;
    FViewport: TViewport;

    // Dragging states
    FIsDragging: Boolean;
    FLastMouseX: Integer;
    FLastMouseY: Integer;

    // Clicking states
    FMouseDownX: Integer;
    FMouseDownY: Integer;

    FDidDrag: Boolean;

    // Simulation states
    FSimulationTimer: TTimer;
    FIsPlaying: Boolean;
    FSimulationSpeed: Integer;

    procedure RenderCellGrid(ACanvas: TCanvas);
    procedure ToggleCellAtViewportPosition(AX, AY: Integer);
    procedure UpdateViewportLabel;
    procedure UpdateViewportControls;
    procedure SimulationTimer(Sender: TObject);
    procedure SetSimulationSpeed(ASimulationSpeed: Integer);

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Randomize;

  FCellGrid := TCellGrid.Create(200, 200); // Create the cell grid at 200p simulation resolution
  FViewport := TViewport.Create;

  FIsPlaying := False;
  FSimulationSpeed := 5;

  // Create a timer internally for the simulation
  FSimulationTimer := TTimer.Create(Self);
  FSimulationTimer.Enabled := False;
  FSimulationTimer.Interval := 1000 div FSimulationSpeed;
  FSimulationTimer.OnTimer := @SimulationTimer;

  Label1.Parent := Self;
  Label1.BringToFront; // Bring the viewport label foward above the paintbox
  UpdateViewportLabel;

  Panel1.Parent := Self;
  Panel1.OnClick := @Panel1Click;
  Panel1.BringToFront;

  // The @ is referencing the elements method to call a different one instead
  Panel3.OnClick := @Panel3Click;
  Panel5.OnClick := @Panel5Click;
  Panel6.OnClick := @Panel6Click;

  // Bring all panels foward
  Panel3.BringToFront;
  Panel4.BringToFront;
  Panel5.BringToFront;
  Panel6.BringToFront;

  // The @ is referencing the elements method to call a different one instead
  PaintBox1.OnMouseDown := @PaintBox1MouseDown;
  PaintBox1.OnMouseMove := @PaintBox1MouseMove;
  PaintBox1.OnMouseUp := @PaintBox1MouseUp;

  UpdateViewportControls;
end;

procedure TForm1.Panel1Click(Sender: TObject);
begin
  FIsPlaying := not FIsPlaying;
  FSimulationTimer.Enabled := FIsPlaying;

  UpdateViewportControls;
end;

procedure TForm1.Panel3Click(Sender: TObject);
begin
  FIsPlaying := False;
  FSimulationTimer.Enabled := False;

  FCellGrid.Clear;

  UpdateViewportControls;
  PaintBox1.Invalidate;
end;

procedure TForm1.Panel5Click(Sender: TObject);
begin
  // Added: lower speed means a larger timer interval, so the simulation slows down
  SetSimulationSpeed(FSimulationSpeed - 1);
end;

procedure TForm1.Panel6Click(Sender: TObject);
begin
  // Added: higher speed means a smaller timer interval, so the simulation speeds up
  SetSimulationSpeed(FSimulationSpeed + 1);
end;

procedure TForm1.SimulationTimer(Sender: TObject);
begin
  FCellGrid.Tick;
  PaintBox1.Invalidate;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Destroy both the cell grid and viewport once the form is closed
  FCellGrid.Free;
  FViewport.Free;
end;

// Viewport visuals
procedure TForm1.UpdateViewportLabel;
begin
  Label1.Caption :=  // Style and space the viewport info labels
    'ViewportX: ' + FloatToStrF(FViewport.ViewportX, ffFixed, 8, 1) +
    '                        ViewportY: ' + FloatToStrF(FViewport.ViewportY, ffFixed, 8, 1) +
    '                        ViewportZoom: ' + FloatToStrF(FViewport.ViewportZoom, ffFixed, 8, 1) + 'x';
end;

procedure TForm1.UpdateViewportControls;
begin
  // Switch between pause and play state
  if FIsPlaying then
    Panel1.Caption := '❚❚'
  else
    Panel1.Caption := '▶';

  // Added: keep speed display synced with current simulation speed
  Panel4.Caption := 'Speed: ' + IntToStr(FSimulationSpeed) + 'x';

  Panel1.BringToFront; // Bring the viewport controls foward above the paintbox

  // Added: keep reset and speed controls above the paintbox
  Panel3.BringToFront;
  Panel4.BringToFront;
  Panel5.BringToFront;
  Panel6.BringToFront;
end;

// Added: convert user-facing speed into timer milliseconds
procedure TForm1.SetSimulationSpeed(ASimulationSpeed: Integer);
begin
  FSimulationSpeed := EnsureRange(ASimulationSpeed, 1, 20);
  FSimulationTimer.Interval := 1000 div FSimulationSpeed;

  UpdateViewportControls;
end;

// Render the cell grid within the canvas of the PaintBox
procedure TForm1.PaintBox1Paint(Sender: TObject);
begin
  RenderCellGrid(PaintBox1.Canvas);
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FIsDragging := True;
    FDidDrag := False;

    FLastMouseX := X;
    FLastMouseY := Y;

    FMouseDownX := X;
    FMouseDownY := Y;
  end;
end;

procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DeltaX, DeltaY: Integer;
begin
  if FIsDragging then
  begin
    DeltaX := X - FLastMouseX;
    DeltaY := Y - FLastMouseY;

    FViewport.Pan(
      -DeltaX / FViewport.ViewportZoom,
      -DeltaY / FViewport.ViewportZoom
    );

    FLastMouseX := X;
    FLastMouseY := Y;

    if (Abs(X - FMouseDownX) > 2) or (Abs(Y - FMouseDownY) > 2) then
      FDidDrag := True;

    UpdateViewportLabel;
    PaintBox1.Invalidate;
  end;
end;

procedure TForm1.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FIsDragging := False;

    if not FDidDrag then
      ToggleCellAtViewportPosition(X, Y);
  end;
end;

function TForm1.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  PaintBoxMousePos: TPoint;
begin
  Result := False;

  PaintBoxMousePos := PaintBox1.ScreenToClient(Mouse.CursorPos);

  // Only zoom if the mouse is over the paintbox
  if (PaintBoxMousePos.X >= 0) and
     (PaintBoxMousePos.X < PaintBox1.Width) and
     (PaintBoxMousePos.Y >= 0) and
     (PaintBoxMousePos.Y < PaintBox1.Height) then
  begin
    if WheelDelta > 0 then
       // Zoom in is done at factor 1.2x
      FViewport.ZoomAt(1.2, PaintBoxMousePos.X, PaintBoxMousePos.Y)
    else
      // Zoom out is done at 0.8x
      FViewport.ZoomAt(0.8, PaintBoxMousePos.X, PaintBoxMousePos.Y);

    UpdateViewportLabel;
    PaintBox1.Invalidate;
    Result := True;
  end
  else
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TForm1.ToggleCellAtViewportPosition(AX, AY: Integer);
var
  CellGridX, CellGridY: Integer;
begin
  CellGridX := FViewport.ViewportToGridX(AX);
  CellGridY := FViewport.ViewportToGridY(AY);

  if FCellGrid.GetCellState(CellGridX, CellGridY) = cellStateAlive then
    FCellGrid.SetCellState(CellGridX, CellGridY, cellStateDead)
  else
    FCellGrid.SetCellState(CellGridX, CellGridY, cellStateAlive);

  PaintBox1.Invalidate;
end;

// Renderer of the simulation
// Only needs to be called once on form creation
procedure TForm1.RenderCellGrid(ACanvas: TCanvas);
var
  X, Y: Integer;
  ViewportX, ViewportY: Integer;
  CellSize: Integer;
begin
  // Clear the viewport before rendering the cell grid
  ACanvas.Brush.Color := RGBToColor(18, 19, 20);
  ACanvas.FillRect(PaintBox1.ClientRect);

  CellSize := Max(1, Round(FViewport.ViewportZoom));

  // Draw cell grid lines around each grid square
  // These are drawn at a lower oppacity
  ACanvas.Pen.Color := RGBToColor(32, 36, 40);
  ACanvas.Pen.Width := 1;

  for X := 0 to FCellGrid.CellGridWidth do
  begin
    ViewportX := FViewport.GridToViewportX(X);

    // Draw rows
    if (ViewportX >= 0) and (ViewportX <= PaintBox1.Width) then
      ACanvas.Line(
        ViewportX,
        Max(0, FViewport.GridToViewportY(0)),
        ViewportX,
        Min(PaintBox1.Height, FViewport.GridToViewportY(FCellGrid.CellGridHeight))
      );
  end;

  for Y := 0 to FCellGrid.CellGridHeight do
  begin
    ViewportY := FViewport.GridToViewportY(Y);

    // Draw columns
    if (ViewportY >= 0) and (ViewportY <= PaintBox1.Height) then
      ACanvas.Line(
        Max(0, FViewport.GridToViewportX(0)),
        ViewportY,
        Min(PaintBox1.Width, FViewport.GridToViewportX(FCellGrid.CellGridWidth)),
        ViewportY
      );
  end;

  for X := 0 to FCellGrid.CellGridWidth - 1 do
  begin
    for Y := 0 to FCellGrid.CellGridHeight - 1 do
    begin
      if FCellGrid.GetCellState(X, Y) = cellStateAlive then
      begin
        // Convert cell grid position to local viewport position
        ViewportX := FViewport.GridToViewportX(X);
        ViewportY := FViewport.GridToViewportY(Y);

        // Draw all alive cells within the cell grid
        ACanvas.Brush.Color := RGBToColor(65, 144, 209);
        ACanvas.FillRect(
          ViewportX,
          ViewportY,
          ViewportX + CellSize,
          ViewportY + CellSize
        );
      end;
    end;
  end;

  // Draw outline around the full cell grid
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := RGBToColor(145, 155, 165);
  ACanvas.Pen.Width := 1;

  ACanvas.Rectangle(
    FViewport.GridToViewportX(0),
    FViewport.GridToViewportY(0),
    FViewport.GridToViewportX(FCellGrid.CellGridWidth),
    FViewport.GridToViewportY(FCellGrid.CellGridHeight)
  );

  ACanvas.Brush.Style := bsSolid;
end;

{ TViewport }

constructor TViewport.Create;
begin
  FViewportX := 0;
  FViewportY := 0;
  FViewportZoom := 20;
end;

function TViewport.GridToViewportX(AGridX: Integer): Integer;
begin
  Result := Round((AGridX - FViewportX) * FViewportZoom);
end;

function TViewport.GridToViewportY(AGridY: Integer): Integer;
begin
  Result := Round((AGridY - FViewportY) * FViewportZoom);
end;

function TViewport.ViewportToGridX(AViewportX: Integer): Integer;
begin
  Result := Floor(AViewportX / FViewportZoom + FViewportX);
end;

function TViewport.ViewportToGridY(AViewportY: Integer): Integer;
begin
  Result := Floor(AViewportY / FViewportZoom + FViewportY);
end;

procedure TViewport.Pan(ADeltaX, ADeltaY: Double);
begin
  // Apply motion to the camera based on the X and Y delta
  FViewportX := FViewportX + ADeltaX;
  FViewportY := FViewportY + ADeltaY;
end;

procedure TViewport.Zoom(AZoomFactor: Double);
begin
  FViewportZoom := FViewportZoom * AZoomFactor;

  // Prevent zooming out below 1x or above 100x
  if FViewportZoom < 1 then
    FViewportZoom := 1;

  if FViewportZoom > 100 then
    FViewportZoom := 100;
end;

procedure TViewport.ZoomAt(AZoomFactor: Double; AViewportX, AViewportY: Integer);
var
  CellGridXBeforeZoom, CellGridYBeforeZoom: Double;
begin
  CellGridXBeforeZoom := AViewportX / FViewportZoom + FViewportX;
  CellGridYBeforeZoom := AViewportY / FViewportZoom + FViewportY;

  Zoom(AZoomFactor);

  FViewportX := CellGridXBeforeZoom - AViewportX / FViewportZoom;
  FViewportY := CellGridYBeforeZoom - AViewportY / FViewportZoom;
end;

{ TCellGrid }

constructor TCellGrid.Create(AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;

  // Set the length of the 2Darray to match the cell grid dimensions
  SetLength(FCells, FWidth, FHeight);
end;

procedure TCellGrid.Clear;
var
  X, Y: Integer;
begin
  for X := 0 to FWidth - 1 do
  begin
    for Y := 0 to FHeight - 1 do
    begin
      FCells[X, Y] := cellStateDead;
    end;
  end;
end;

function TCellGrid.CountActiveNeighbours(AX, AY: Integer): Integer;
var
  OffsetX, OffsetY: Integer;
begin
  Result := 0;

  for OffsetX := -1 to 1 do
  begin
    for OffsetY := -1 to 1 do
    begin
      // Skip the cell itself, as it is not its own neighbour
      if (OffsetX = 0) and (OffsetY = 0) then
        Continue;

      // If the neighbouring cell is alive, add it to the result
      if GetCellState(AX + OffsetX, AY + OffsetY) = cellStateAlive then
        Inc(Result);
    end;
  end;
end;

procedure TCellGrid.SetCellState(
  AX, AY: Integer;
  ACellState: TCellState
);
begin
  // Check that the given coordinates are within the cell grid
  if (AX >= 0) and (AX < FWidth) and
     (AY >= 0) and (AY < FHeight) then
    FCells[AX, AY] := ACellState;
end;

function TCellGrid.GetCellState(AX, AY: Integer): TCellState;
begin
  // Check that the given coordinates are within the cell grid
  if (AX >= 0) and (AX < FWidth) and
     (AY >= 0) and (AY < FHeight) then
    Result := FCells[AX, AY]
  else
    // Cells outside the grid are treated as dead
    Result := cellStateDead;
end;

// Tick must be called every time the simulation takes one step
// It contains the cell logic of the simulation
procedure TCellGrid.Tick;
var
  X, Y: Integer;
  CellTick: array of array of TCellState;
  ActiveNeighbours: Integer;
begin
  CellTick := nil; // Set cells to empty using nil, required by type
  SetLength(CellTick, FWidth, FHeight);

  for X := 0 to FWidth - 1 do
  begin
    for Y := 0 to FHeight - 1 do
    begin
      ActiveNeighbours := CountActiveNeighbours(X, Y);

      if FCells[X, Y] = cellStateAlive then
      begin
        // A live cell survives only with 2 or 3 live neighbours
        if (ActiveNeighbours = 2) or (ActiveNeighbours = 3) then
          CellTick[X, Y] := cellStateAlive
        else
          CellTick[X, Y] := cellStateDead;
      end
      else
      begin
        // A dead cell becomes alive if it has exactly 3 live neighbours
        if ActiveNeighbours = 3 then
          CellTick[X, Y] := cellStateAlive
        else
          CellTick[X, Y] := cellStateDead;
      end;
    end;
  end;

  FCells := CellTick;
end;

end.
