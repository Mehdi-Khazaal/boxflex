--  Points, sizes, rectangles, and the geometric facts the layout
--  algorithm relies on.
--
--  This package is the "proven geometry" of the project. Every
--  function is an expression function or has a body simple enough to
--  prove. The preconditions exist to rule out fixed-point overflow;
--  the postconditions state the geometric fact each operation
--  guarantees.

package Boxflex.Geometry with SPARK_Mode, Preelaborate is

   type Point is record
      X, Y : Coord := 0.0;
   end record;

   type Size is record
      Width, Height : Length := 0.0;
   end record;

   type Rect is record
      Origin : Point;
      Extent : Size;
   end record;

   Zero_Point : constant Point := (X => 0.0, Y => 0.0);
   Zero_Size  : constant Size  := (Width => 0.0, Height => 0.0);
   Zero_Rect  : constant Rect  :=
     (Origin => (X => 0.0, Y => 0.0), Extent => (Width => 0.0, Height => 0.0));

   ---------------------------------------------------------------------
   --  Overflow guards
   ---------------------------------------------------------------------

   function Edges_In_Range (R : Rect) return Boolean is
     (R.Origin.X <= Coord'Last - R.Extent.Width
      and then R.Origin.Y <= Coord'Last - R.Extent.Height);
   --  True when Right (R) and Bottom (R) can be computed without
   --  overflowing Coord. Every rect produced by the layout engine
   --  satisfies this; it is a precondition on anything that reads
   --  the far edges.

   function Placed (R : Rect) return Boolean is
     (R.Origin.X <= Max_Pos and then R.Origin.Y <= Max_Pos);
   --  Stronger than Edges_In_Range and independent of the extent: the
   --  layout engine keeps every origin at or below Max_Pos, so any
   --  extent can be attached later. Placed implies Edges_In_Range.

   function Advance (X : Coord; D : Length) return Coord is
     (if X > Max_Pos - D then Max_Pos else X + D)
     with Pre  => X <= Max_Pos,
          Post => Advance'Result <= Max_Pos
                  and then Advance'Result >= X;
   --  X + D, saturating at Max_Pos.

   function Place (X : Coord; Offset : Coord) return Coord is
     (if Offset >= 0.0
      then (if X > Max_Pos - Offset then Max_Pos else X + Offset)
      else (if X < Coord'First - Offset then Coord'First else X + Offset))
     with Pre  => X <= Max_Pos and then Offset <= Max_Pos,
          Post => Place'Result <= Max_Pos;
   --  X + Offset, saturating at both ends of the safe range.

   ---------------------------------------------------------------------
   --  Edges
   ---------------------------------------------------------------------

   function Right (R : Rect) return Coord is
     (R.Origin.X + R.Extent.Width)
     with Pre => Edges_In_Range (R);

   function Bottom (R : Rect) return Coord is
     (R.Origin.Y + R.Extent.Height)
     with Pre => Edges_In_Range (R);

   ---------------------------------------------------------------------
   --  Relations
   ---------------------------------------------------------------------

   function Contains (Outer, Inner : Rect) return Boolean is
     (Outer.Origin.X <= Inner.Origin.X
      and then Outer.Origin.Y <= Inner.Origin.Y
      and then Right (Inner) <= Right (Outer)
      and then Bottom (Inner) <= Bottom (Outer))
     with Pre => Edges_In_Range (Outer) and then Edges_In_Range (Inner);
   --  Inner lies entirely within Outer (edges may touch).

   function Overlaps (A, B : Rect) return Boolean is
     (A.Origin.X < Right (B)
      and then B.Origin.X < Right (A)
      and then A.Origin.Y < Bottom (B)
      and then B.Origin.Y < Bottom (A))
     with Pre => Edges_In_Range (A) and then Edges_In_Range (B);
   --  A and B share a region of positive area. Touching edges do not
   --  count as overlap.

   function Is_Empty (R : Rect) return Boolean is
     (R.Extent.Width = 0.0 or else R.Extent.Height = 0.0);

   ---------------------------------------------------------------------
   --  Construction
   ---------------------------------------------------------------------

   function Make (X, Y : Coord; Width, Height : Length) return Rect is
     (Origin => (X => X, Y => Y), Extent => (Width => Width, Height => Height));

   function Inset
     (R                        : Rect;
      Left, Top, Right, Bottom : Length) return Rect
     with
       Pre  => Edges_In_Range (R)
               and then R.Origin.X <= Coord'Last - Left
               and then R.Origin.Y <= Coord'Last - Top,
       Post => Edges_In_Range (Inset'Result)
               and then Inset'Result.Extent.Width  <= R.Extent.Width
               and then Inset'Result.Extent.Height <= R.Extent.Height
               and then Inset'Result.Origin.X = R.Origin.X + Left
               and then Inset'Result.Origin.Y = R.Origin.Y + Top;
   --  Shrinks R by the four insets (padding, border, margin). If the
   --  insets exceed the extent, the resulting extent is clamped to
   --  zero rather than going negative. Used to compute a node's
   --  content box from its border box.

   function Translate (R : Rect; DX, DY : Coord) return Rect
     with
       Pre  => (if DX >= 0.0 then R.Origin.X <= Coord'Last - DX
                else R.Origin.X >= Coord'First - DX)
               and then
               (if DY >= 0.0 then R.Origin.Y <= Coord'Last - DY
                else R.Origin.Y >= Coord'First - DY),
       Post => Translate'Result.Extent = R.Extent
               and then Translate'Result.Origin.X = R.Origin.X + DX
               and then Translate'Result.Origin.Y = R.Origin.Y + DY;
   --  Moves R by (DX, DY). Extent is unchanged.

   ---------------------------------------------------------------------
   --  Axis helpers
   ---------------------------------------------------------------------
   --  Flexbox reasons about a "main" axis and a "cross" axis rather
   --  than X and Y. These helpers let the algorithm be written once.

   type Axis is (Horizontal, Vertical);

   function Main_Extent (S : Size; A : Axis) return Length is
     (case A is when Horizontal => S.Width, when Vertical => S.Height);

   function Cross_Extent (S : Size; A : Axis) return Length is
     (case A is when Horizontal => S.Height, when Vertical => S.Width);

   function Make_Size (Main, Cross : Length; A : Axis) return Size is
     (case A is
        when Horizontal => (Width => Main,  Height => Cross),
        when Vertical   => (Width => Cross, Height => Main));

end Boxflex.Geometry;
